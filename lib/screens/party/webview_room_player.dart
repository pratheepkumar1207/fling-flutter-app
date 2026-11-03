import '../../theme/insync_icons.dart';
import 'dart:async';
import 'dart:convert';

import '../../widgets/fit_video_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/drm_support.dart';
import '../../core/mobile_webview_settings.dart';
import '../../theme/app_colors.dart';
import 'ott_sync_engine.dart';
import 'ott_sync_panel.dart';
import '../../core/ott_remote.dart';

/// Netflix/Prime "browse together" sibling of sync_video_player.dart /
/// drive_video_player.dart. Unlike those two there is still no *real* sync
/// contract — DRM (Widevine) blocks any script, including this WebView's
/// own JS, from reading or controlling the actual video element inside a
/// cross-origin, DRM-protected page. That's a hard platform boundary, not
/// a missing feature — see https://rave.io (a real, popular watch-party
/// app) confirming the exact same constraint: "Every single person has to
/// sign into their own Netflix account... No screen sharing at all."
///
/// What this DOES provide, reusing the same playback:play/pause/state
/// socket channel the YouTube/Drive players already use (see
/// room_socket_controller.dart's play/pause/playback, unchanged on the
/// backend — this just treats `position` as an approximate elapsed-time
/// clock instead of a real, seekable video position):
///  - An elapsed-time estimate ("Room is ~10:30 in") so someone joining
///    late knows roughly where to manually scrub to in their own player.
///  - Host-only Play/Pause buttons that broadcast a "please press play/
///    pause too" nudge banner to everyone else — a coordination aid, not
///    remote control. Each participant still has to tap their own video.
///  - A simple heuristic ("does the current URL look like a login page?")
///    to nudge someone who hasn't signed into this platform yet.
class WebviewRoomPlayer extends StatefulWidget {
  final String? videoUrl;
  final String? title;
  final bool compact;
  // When true, fills whatever box the parent gives it (party_screen.dart's
  // immersive OTT layout hands this an Expanded slot) instead of boxing
  // itself into a 16:9/21:9 crop. Unlike YouTube/Drive, this player is a
  // whole embedded website, not a single video element — letting it use the
  // full available space (not just full width) is a truer "full view" for
  // it than an artificial aspect-ratio crop would be.
  final bool fillHeight;
  final bool isHost;
  final Map<String, dynamic>? playback;
  final void Function(double position) onPlay;
  final void Function(double position) onPause;
  // Host-only drag on the elapsed-time bar below — see _buildProgressBar's
  // doc comment for exactly what this does and doesn't do.
  final void Function(double position)? onSeek;
  final VoidCallback onRequestState;
  // Same skip contract as sync_video_player.dart/drive_video_player.dart —
  // "skip" here just means "move to the next queued item" (a real,
  // well-defined queue operation) rather than anything about the current
  // item's playback position, which OTT never had control over anyway.
  // isHost gets onSkip (always immediate); everyone else gets onVoteSkip,
  // same "one consistent player control" treatment across every source.
  final VoidCallback? onSkip;
  final VoidCallback? onVoteSkip;
  final int skipVoteCount;
  final int skipVoteRequired;
  // Netflix/Prime sync (see ott_sync_panel.dart): each member's reported
  // status, and how this phone reports its own.
  final Map<String, Map<String, dynamic>> ottStatuses;
  final void Function(String status, double offsetSec)? onOttStatus;
  // The room's like for what's playing (same as the YouTube player).
  final bool liked;
  final VoidCallback? onToggleLike;
  // Host only: they moved to another title or episode on the site; the
  // room switches everyone to it.
  final void Function(String videoUrl, String? title)? onHostNavigate;
  // Room setting: hold everyone while anyone's player shows an ad.
  final bool waitForAds;

  const WebviewRoomPlayer({
    super.key,
    required this.videoUrl,
    this.title,
    this.compact = false,
    this.fillHeight = false,
    required this.isHost,
    required this.playback,
    required this.onPlay,
    required this.onPause,
    this.onSeek,
    required this.onRequestState,
    this.onSkip,
    this.onVoteSkip,
    this.skipVoteCount = 0,
    this.skipVoteRequired = 1,
    this.ottStatuses = const {},
    this.onOttStatus,
    this.liked = false,
    this.onToggleLike,
    this.onHostNavigate,
    this.waitForAds = true,
  });

  @override
  State<WebviewRoomPlayer> createState() => _WebviewRoomPlayerState();
}

class _WebviewRoomPlayerState extends State<WebviewRoomPlayer> {
  InAppWebViewController? _controller;
  // Keeps the page (and what's playing) alive when the player moves, as it
  // does when the phone is turned to full screen.
  final _keepAlive = InAppWebViewKeepAlive();
  Timer? _tickTimer;
  Timer? _nudgeDismissTimer;
  String? _nudgeBanner;
  bool _onLoginPage = false;
  // Non-null only while the host has a finger on the elapsed-time slider —
  // shows the drag position immediately instead of visibly snapping back
  // to the old value until the emit round-trips. See _buildProgressBar.
  double? _dragPosition;
  // Set when this phone has no Widevine (emulators, some cheap/rooted
  // phones): Netflix/Prime/Hotstar can't play in any WebView there, so the
  // player says so and offers the platform's own app instead of sitting
  // on a blank or error page.
  bool _noWidevine = false;
  bool _drmChecked = false;

  // Netflix/Prime: like Rave, the title plays right here in the room and
  // the room drives that web player (see _WebPlayerTarget). Switches to
  // the platform's own app (ott_sync_panel.dart) when the web player shows
  // an error — as Netflix does on emulators — or the person asks to.
  bool _useApp = false;
  OttSyncEngine? _webSync;
  Timer? _webSyncTimer;
  bool _webBusy = false;
  String _webStatus = 'not_playing';
  String? _lastSentStatus;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Netflix/Prime get a real try in the room first; only if the video doesn't
  // play here does the room move to the platform's app. Waiting at a sign-in
  // page doesn't count against the try.
  static const _noPlayerLimit = Duration(seconds: 25);
  static const _noProgressLimit = Duration(seconds: 60);
  DateTime _tryStarted = DateTime.now();
  bool _webPlayed = false;
  double? _firstWebPos;
  bool _triedFallbackUrl = false;

  // Set when the video won't play in the room's own view. The room stays
  // here (no jumping off to the platform's app); a note offers the app.
  String? _webTrouble;

  void _moveToApp(String why) {
    debugPrint('OTT: video not playing in the room: $why');
    if (mounted && _webTrouble == null && !_useApp) {
      setState(() => _webTrouble = why);
    }
  }

  @override
  void initState() {
    super.initState();
    // Same as the YouTube/Drive players — ask the room for the current
    // state on join so a late joiner's elapsed-time estimate starts
    // correct instead of at zero.
    if (!widget.isHost) widget.onRequestState();
    // Every platform, Netflix included, gets a real try in the room's own
    // view first. If it won't play here, a note offers the app instead of
    // sending people there.
    _checkWidevine();
    if (_isOtt) {
      _webSyncTimer = Timer.periodic(
          const Duration(milliseconds: 1500), (_) => _webSyncTick());
    }
    // Forces the elapsed-time display to keep advancing even when no new
    // playback:state has arrived — purely cosmetic, doesn't affect
    // anything sent to the backend.
    _tickTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant WebviewRoomPlayer old) {
    super.didUpdateWidget(old);
    final wasPlaying = old.playback?['isPlaying'] as bool?;
    final isPlaying = widget.playback?['isPlaying'] as bool?;
    // No "press play too" when the room already does it for them.
    final autoSynced = _isOtt && (_useApp || _webSync?.local != null);
    if (!widget.isHost &&
        !autoSynced &&
        isPlaying != null &&
        isPlaying != wasPlaying) {
      _showNudge(isPlaying
          ? 'Host pressed play — press play in your app too'
          : 'Host paused — pause yours too');
    }
  }

  void _showNudge(String text) {
    _nudgeDismissTimer?.cancel();
    setState(() => _nudgeBanner = text);
    _nudgeDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _nudgeBanner = null);
    });
  }

  // Not a real video position — position + elapsed wall-clock time since
  // the host's last play/pause, same correction pattern
  // sync_video_player.dart/drive_video_player.dart use for the real thing.
  // Purely a display estimate; nothing here can seek anyone's actual video.
  // The host's own last play/pause/seek. The backend only sends those to
  // everyone else, so without this the host's own clock (and Netflix
  // sync, which compares against it) would stay on the old state.
  Map<String, dynamic>? _hostLocal;
  final _ottPanel = GlobalKey<OttSyncPanelState>();

  Map<String, dynamic>? get _playback {
    final local = _hostLocal;
    final remote = widget.playback;
    if (local == null) return remote;
    if (remote == null) return local;
    return ((remote['updatedAt'] as num?) ?? 0) > (local['updatedAt'] as num)
        ? remote
        : local;
  }

  void _record(double position, bool playing) => _hostLocal = {
        'position': position,
        'isPlaying': playing,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

  void _emitPlay(double position) {
    _record(position, true);
    widget.onPlay(position);
  }

  void _emitPause(double position) {
    _record(position, false);
    widget.onPause(position);
  }

  void _emitSeek(double position) {
    _record(position, true);
    widget.onSeek?.call(position);
  }

  double get _elapsedSeconds {
    final p = _playback;
    if (p == null) return 0;
    var position = (p['position'] as num?)?.toDouble() ?? 0;
    final updatedAt = p['updatedAt'] == null ? null : (p['updatedAt'] as num);
    if (p['isPlaying'] == true && updatedAt != null) {
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - updatedAt) / 1000;
      if (elapsed > 0) position += elapsed;
    }
    return position;
  }

  bool get _isPlaying => _playback?['isPlaying'] == true;

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.round());
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:$m:$s';
    }
    return '${d.inMinutes}:$s';
  }

  void _hostTogglePlay() {
    final playing = !_isPlaying;
    playing ? _emitPlay(_elapsedSeconds) : _emitPause(_elapsedSeconds);
    _hostCommand(playing: playing);
  }

  // There's no real duration to size this against — Netflix/Prime never
  // expose the actual video's length to an embedded page, DRM or not — so
  // this is just a generous, round upper bound for the drag range (most
  // movies/episodes fit well inside it), not a real "time remaining"
  // figure. Grows if elapsed ever exceeds it instead of clamping, so a
  // longer title doesn't cap the bar at its own current position.
  double get _maxDragSeconds {
    const defaultMax = 4 * 3600.0;
    return _elapsedSeconds > defaultMax ? _elapsedSeconds + 600 : defaultMax;
  }

  void _handleSeekChanged(double value) =>
      setState(() => _dragPosition = value);

  // Total length when the player reports it (Netflix's page or app).
  double? get _durationSec =>
      _webSync?.local?.durationSec ?? _ottPanel.currentState?.durationSec;

  // Host: move the room (and their own player) to [position], keeping it
  // playing or paused as it was.
  void _hostSeekTo(double position) {
    final target = position < 0 ? 0.0 : position;
    final playing = _isPlaying;
    playing ? _emitSeek(target) : _emitPause(target);
    _hostCommand(playing: playing, seekTo: target);
  }

  void _handleSeekEnd(double value) {
    setState(() => _dragPosition = null);
    _hostSeekTo(value);
  }

  // Everyone watches with their own account. Set when this person's page is
  // asking them to log in (a login page, or a login wall over the title).
  bool _needsLogin = false;
  Timer? _loginCheck;

  static const _loginWallScript = r'''
    (function() {
      var v = Array.from(document.querySelectorAll('video'))
          .some(function(x) { return x.duration > 0 || x.currentTime > 0; });
      if (v) return false;
      var re = /^\s*(log\s*in|sign\s*in|login|signin|subscribe|subscribe now|watch with (a )?subscription)\s*$/i;
      var els = document.querySelectorAll('a, button, [role="button"]');
      for (var i = 0; i < els.length; i++) {
        var e = els[i], r = e.getBoundingClientRect();
        if (r.width > 0 && r.height > 0 && re.test(e.innerText || '')) return true;
      }
      return false;
    })();
  ''';

  void _watchForLoginWall() {
    _loginCheck?.cancel();
    if (!_isOtt) return;
    var checks = 0;
    _loginCheck = Timer.periodic(const Duration(seconds: 3), (timer) async {
      checks++;
      if (!mounted || _appOnly || _webPlayed || checks > 20) {
        timer.cancel();
        return;
      }
      // A few seconds for the player to appear before asking anyone.
      if (checks < 3) return;
      try {
        final wall =
            await _controller?.evaluateJavascript(source: _loginWallScript);
        if (mounted && (wall == true) != _needsLogin && !_onLoginPage) {
          setState(() => _needsLogin = wall == true);
        }
      } catch (_) {}
    });
  }

  // Opens the site's own Log in button; if there isn't one, its home page,
  // where the login is.
  Future<void> _openLogin() async {
    final c = _controller;
    if (c == null) return;
    setState(() => _needsLogin = false);
    final clicked = await c.evaluateJavascript(source: r'''
      (function() {
        var re = /^\s*(log\s*in|sign\s*in|login|signin)\s*$/i;
        var els = document.querySelectorAll('a, button, [role="button"]');
        for (var i = 0; i < els.length; i++) {
          var e = els[i], r = e.getBoundingClientRect();
          if (r.width > 0 && r.height > 0 && re.test(e.innerText || '')) { e.click(); return true; }
        }
        return false;
      })();
    ''').catchError((_) => false);
    if (clicked != true) {
      final home = Uri.tryParse(widget.videoUrl ?? '');
      if (home != null && home.hasScheme) {
        await c.loadUrl(
            urlRequest:
                URLRequest(url: WebUri('${home.scheme}://${home.host}/')));
      }
    }
  }

  // Logged in: back to the room's title, which then catches up with the room.
  Future<void> _backToShow() async {
    final url = widget.videoUrl;
    if (url == null) return;
    setState(() {
      _needsLogin = false;
      _onLoginPage = false;
    });
    _tryStarted = DateTime.now();
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    _watchForLoginWall();
  }

  // Best-effort only — platforms don't expose a stable "you're logged out"
  // signal, so this just looks for the obvious login/signin URL patterns
  // most of them share.
  void _checkLoginUrl(Uri? url) {
    final path = url?.toString().toLowerCase() ?? '';
    final looksLikeLogin = path.contains('login') ||
        path.contains('signin') ||
        path.contains('sign-in');
    if (looksLikeLogin != _onLoginPage) {
      _tryStarted = DateTime.now();
      setState(() => _onLoginPage = looksLikeLogin);
    }
  }

  // Pins the page's own <video> element edge-to-edge over everything else,
  // via plain CSS rather than the Fullscreen API above — confirmed live:
  // on non-DRM sites (Aha, and similar), the page stays in its normal
  // in-page layout (header, related-videos, description text) around a
  // centered player instead of filling the screen, leaving visible "extra
  // space" around the actual video. CSS positioning doesn't need a genuine
  // user gesture the way requestFullscreen does, so it applies
  // automatically on load instead of waiting for a tap. Content-only
  // styling — doesn't read or control playback state, so it's a no-op on
  // DRM pages (Netflix/Prime) whose player isn't a plain <video> tag in
  // the same way; harmless to run there regardless.
  //
  // Picks the real content <video> (playing, or failing that the largest)
  // rather than blindly matching every <video> tag — some pages carry extra
  // empty/placeholder ones alongside the real element.
  //
  // Sets the sizing directly on the element's own inline style via
  // style.setProperty(prop, value, 'important') rather than an injected
  // <style> rule. Confirmed live on Aha: an injected `video { ... !important
  // }` stylesheet rule correctly won width (100vw took effect — the video's
  // own offsetWidth matched the viewport exactly), but height stayed at the
  // video's native aspect ratio instead of 100vh. That's a genuine CSS
  // specificity loss, not a wrong-element problem: the page's own
  // `!important` rule on this exact video (matched by a class selector, more
  // specific than this bare-tag one) still wins a tag-selector's
  // `!important` per the cascade's specificity tie-break. An element's own
  // inline style is higher-priority than any external stylesheet rule
  // regardless of that rule's specificity, so setting it directly here is
  // what actually guarantees the win. Retried a few times after load since
  // the real player's <video> element is frequently attached
  // asynchronously, after this page's load event.
  static const _settingsRead = r'''
    (function() {
      var vs = Array.from(document.querySelectorAll('video'));
      vs.sort(function(a,b){ return (b.offsetWidth*b.offsetHeight) - (a.offsetWidth*a.offsetHeight); });
      var v = vs[0];
      if (!v) return null;
      var audio = [], text = [];
      try {
        var at = v.audioTracks;
        if (at) for (var i = 0; i < at.length; i++)
          audio.push({i: i, label: at[i].label || at[i].language || ('Track ' + (i + 1)), on: at[i].enabled});
      } catch (e) {}
      try {
        var tt = v.textTracks;
        if (tt) for (var j = 0; j < tt.length; j++)
          if (tt[j].kind === 'subtitles' || tt[j].kind === 'captions')
            text.push({i: j, label: tt[j].label || tt[j].language || ('Subtitles ' + (j + 1)), on: tt[j].mode === 'showing'});
      } catch (e) {}
      return JSON.stringify({rate: v.playbackRate || 1, audio: audio, text: text});
    })();
  ''';

  Future<void> _settingsCall(String body) async {
    try {
      await _controller?.evaluateJavascript(source: '''
        (function() {
          var vs = Array.from(document.querySelectorAll('video'));
          vs.sort(function(a,b){ return (b.offsetWidth*b.offsetHeight) - (a.offsetWidth*a.offsetHeight); });
          var v = vs[0];
          if (!v) return;
          $body
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _openSettingsSheet() async {
    Map<String, dynamic> info = const {};
    try {
      final raw = await _controller?.evaluateJavascript(source: _settingsRead);
      if (raw is String) info = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {}
    if (!mounted) return;
    final label = _drmPlatform ?? 'this site';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => _OttSettingsSheet(
        label: label,
        rate: (info['rate'] as num?)?.toDouble() ?? 1,
        audio: ((info['audio'] as List?) ?? const []).cast<Map>(),
        text: ((info['text'] as List?) ?? const []).cast<Map>(),
        onRate: (r) => _settingsCall('v.playbackRate = $r;'),
        onAudio: (i) => _settingsCall(
            'for (var k = 0; k < v.audioTracks.length; k++) v.audioTracks[k].enabled = (k === $i);'),
        onText: (i) => _settingsCall(
            'for (var k = 0; k < v.textTracks.length; k++) v.textTracks[k].mode = (k === $i) ? "showing" : "disabled";'),
        onMore: () {
          Navigator.of(ctx).pop();
          if (!_showSiteControls) _toggleSiteControls();
        },
        fill: _fill,
        onFill: (v) {
          setState(() => _fill = v);
          _injectFullBleedVideoCss();
        },
      ),
    );
  }

  // Language, subtitles and quality are in the site's own control bar,
  // which the stretched video covers. This uncovers the page so each
  // person can change their own, and covers it again after.
  bool _showSiteControls = false;

  Future<void> _toggleSiteControls() async {
    final show = !_showSiteControls;
    setState(() => _showSiteControls = show);
    if (!show) {
      _injectFullBleedVideoCss();
      return;
    }
    try {
      await _controller?.evaluateJavascript(source: '''
        (function() {
          document.querySelectorAll('video[data-insync-full]').forEach(function(v) {
            ['position','top','left','width','height','object-fit','background','z-index']
              .forEach(function(k) { v.style.removeProperty(k); });
            v.removeAttribute('data-insync-full');
          });
          var s = document.getElementById('__insync_fullbleed_body__');
          if (s) s.remove();
        })();
      ''');
    } catch (_) {}
  }

  void _injectFullBleedVideoCss() {
    const script = '''
      (function() {
        var videos = Array.from(document.querySelectorAll('video'));
        if (videos.length === 0) return false;
        var playing = videos.filter(function(v) {
          return !v.paused && v.readyState >= 2;
        });
        var candidates = playing.length ? playing : videos;
        candidates.sort(function(a, b) {
          return (b.offsetWidth * b.offsetHeight) - (a.offsetWidth * a.offsetHeight);
        });
        var main = candidates[0];
        if (!main || (!main.offsetWidth && !main.videoWidth)) return false;
        var fit = window.__insyncFit || 'cover';
        if (main.getAttribute('data-insync-full') === fit) return true;
        videos.forEach(function(v) {
          if (v !== main && v.hasAttribute('data-insync-full')) {
            ['position','top','left','width','height','object-fit','background','z-index']
              .forEach(function(k) { v.style.removeProperty(k); });
            v.removeAttribute('data-insync-full');
          }
        });
        var props = {
          position: 'fixed', top: '0', left: '0',
          width: '100vw', height: '100vh',
          'object-fit': fit, background: '#000',
          'z-index': '2147483647',
        };
        Object.keys(props).forEach(function(k) {
          main.style.setProperty(k, props[k], 'important');
        });
        main.setAttribute('data-insync-full', fit);
        if (!document.getElementById('__insync_fullbleed_body__')) {
          var style = document.createElement('style');
          style.id = '__insync_fullbleed_body__';
          style.innerHTML = `html, body { overflow: hidden !important; margin: 0 !important; padding: 0 !important; }`;
          document.head.appendChild(style);
        }
        return true;
      })();
    ''';
    _stretchTimer?.cancel();
    _stretchTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted || _appOnly) {
        timer.cancel();
        return;
      }
      if (_showSiteControls) return;
      try {
        await _controller?.evaluateJavascript(
            source:
                "window.__insyncFit = '${_fill ? 'cover' : 'contain'}';\n$script");
      } catch (_) {}
    });
  }

  Timer? _stretchTimer;
  // Fill zooms the picture to the whole box (no black bands, edges
  // trimmed); Fit shows all of it. Each person's own choice.
  bool _fill = false;

  // Hosts whose video needs Widevine — the only ones worth checking.
  static const _drmHosts = {
    'netflix.com': 'Netflix',
    'primevideo.com': 'Prime Video',
    'amazon.': 'Prime Video',
    'hotstar.com': 'Hotstar',
    'sonyliv.com': 'SonyLIV',
    'sunnxt.com': 'SunNXT',
    'aha.video': 'Aha',
    'airtelxstream.in': 'Airtel Xstream',
  };

  String? get _drmPlatform {
    final host = Uri.tryParse(widget.videoUrl ?? '')?.host.toLowerCase() ?? '';
    for (final e in _drmHosts.entries) {
      if (host.contains(e.key)) return e.value;
    }
    return null;
  }

  bool get _isOtt => _drmPlatform != null;

  // Only the host touches the video; others only to log in or while the
  // site's own settings are open.
  bool get _blockTouch =>
      _isOtt && !_needsLogin && !_onLoginPage && !_showSiteControls;

  // Netflix and Prime also have an app the room can drive instead.
  bool get _hasApp =>
      _drmPlatform == 'Netflix' || _drmPlatform == 'Prime Video';

  // In app mode the page isn't shown; the platform's own app plays instead.
  bool get _appOnly => _hasApp && _useApp;

  // The address the host's page settled on, seen twice in a row before it
  // counts, so a redirect on the way doesn't switch the room.
  String? _hostSeenUrl;
  String? _hostSentUrl;

  // Host only: while anyone in the room (the host included) is in an ad,
  // and the room's "Wait for ads" is on, the room pauses; it carries on
  // when every ad is over.
  bool _heldForAds = false;

  void _holdForAds(OttPlayerState? local) {
    final adNow = (local?.inAd ?? false) ||
        widget.ottStatuses.values.any((s) => s['status'] == 'ad');
    if (widget.waitForAds && adNow && !_heldForAds && _isPlaying) {
      _heldForAds = true;
      _emitPause(_elapsedSeconds);
      if (!(local?.inAd ?? false)) _hostCommand(playing: false);
      if (mounted) setState(() {});
    } else if (_heldForAds && (!adNow || !widget.waitForAds)) {
      _heldForAds = false;
      _emitPlay(_elapsedSeconds);
      _hostCommand(playing: true);
      if (mounted) setState(() {});
    }
  }

  int get _screensInAds =>
      widget.ottStatuses.values.where((s) => s['status'] == 'ad').length;

  Future<void> _followHostTitle(OttPlayerState? local) async {
    final onNav = widget.onHostNavigate;
    final c = _controller;
    if (onNav == null || c == null || local == null || !local.playing) return;
    final url = (await c.getUrl())?.toString();
    if (url == null) return;
    String key(String? u) {
      final p = Uri.tryParse(u ?? '');
      return p == null ? '' : '${p.host}${p.path}';
    }

    if (key(url) == key(widget.videoUrl) || key(url) == key(_hostSentUrl)) {
      _hostSeenUrl = null;
      return;
    }
    if (_hostSeenUrl != url) {
      _hostSeenUrl = url;
      return;
    }
    _hostSentUrl = url;
    _hostSeenUrl = null;
    final title = (await c.getTitle())?.trim();
    onNav(url, (title == null || title.isEmpty) ? null : title);
  }

  Future<void> _webSyncTick() async {
    final sync = _webSync;
    if (_useApp || sync == null || _onLoginPage || _webBusy || !mounted) return;
    _webBusy = true;
    try {
      final status = await sync.tick();
      if (!mounted) return;
      if ((sync.target as _WebPlayerTarget).error) {
        // The web player refused (an error page) — use the app instead.
        _moveToApp('the web player showed an error page: '
            '${(sync.target as _WebPlayerTarget).errorCode}');
        return;
      }
      if (widget.isHost) await _followHostTitle(sync.local);
      if (widget.isHost) _holdForAds(sync.local);
      if (_webTrouble == null) _judgeWebTry(sync.local);
      if (_useApp) return;
      if (_webTrouble != null && sync.local?.playing == true) {
        setState(() {
          _webTrouble = null;
          _webPlayed = true;
        });
      }
      if (status != _webStatus) setState(() => _webStatus = status);
      _reportStatus(status, sync.offset);
    } finally {
      _webBusy = false;
    }
  }

  void _judgeWebTry(OttPlayerState? local) {
    if (_webPlayed) return;
    if (local != null && local.playing) {
      final first = _firstWebPos ??= local.positionSec;
      if (local.positionSec - first > 1) {
        debugPrint('OTT: the video is playing in the room');
        setState(() => _webPlayed = true);
        return;
      }
    }
    final limit = local == null ? _noPlayerLimit : _noProgressLimit;
    if (DateTime.now().difference(_tryStarted) > limit) {
      _moveToApp('no video played in ${limit.inSeconds}s');
    }
  }

  // Netflix answering with its app link: use the web address it offers
  // alongside, if any, before giving up on playing here.
  void _onAppLink(InAppWebViewController controller, Uri? link) {
    final fallback = RegExp(r'S\.browser_fallback_url=([^;]+)')
        .firstMatch(link?.toString() ?? '')
        ?.group(1);
    if (fallback != null && !_triedFallbackUrl) {
      _triedFallbackUrl = true;
      debugPrint('OTT: page offered a web address, trying it');
      controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(Uri.decodeComponent(fallback))));
      return;
    }
    _moveToApp('the page handed off to ${link?.scheme}');
  }

  void _reportStatus(String status, double offset) {
    final now = DateTime.now();
    if (status != _lastSentStatus ||
        now.difference(_lastSentAt) > const Duration(seconds: 5)) {
      _lastSentStatus = status;
      _lastSentAt = now;
      widget.onOttStatus?.call(status, offset);
    }
  }

  // The host used the room's own controls: move their player too.
  void _hostCommand({required bool playing, double? seekTo}) {
    if (_appOnly) {
      _ottPanel.currentState?.hostCommand(playing: playing, seekTo: seekTo);
    } else {
      _webSync?.hostCommand(playing: playing, seekTo: seekTo);
    }
  }

  // Asks Android whether this device has Widevine at all.
  Future<void> _checkWidevine() async {
    if (_drmChecked || _drmPlatform == null) return;
    _drmChecked = true;
    final supported = await DrmSupport.hasWidevine();
    if (mounted && !supported) setState(() => _noWidevine = true);
  }

  Future<void> _openPlatformApp() async {
    final url = widget.videoUrl;
    if (url == null) return;
    // The platform's own app if it's installed, otherwise its website.
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {}
    if (!ok) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _noWidevineNotice(bool roomy) => Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Row(
          children: [
            const InIcon(InIcons.lock, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Can’t play ${_drmPlatform ?? 'this'} on this phone',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                  if (roomy)
                    Text('Watch in the app. This room keeps time and chat.',
                        maxLines:
                            MediaQuery.textScalerOf(context).scale(10) > 13
                                ? 1
                                : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _openPlatformApp,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact),
              child: const Text('Open', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      );

  // Music-player style: elapsed / total and a progress bar (draggable by
  // the host), then the host's back-10s / play-pause / forward-10s in the
  // middle. No title or instructions — the picture is the content. Next-
  // in-queue stays on the right (vote to skip for everyone else). Each
  // person's own subtitle/audio/quality settings stay in the site's own
  // player; only play/pause and position are shared.
  // The YouTube watch party's look: controls, then the times, then a thin
  // edge-to-edge bar. Only the host plays, pauses, jumps and drags; everyone
  // can like, open settings, and vote to skip.
  Widget _controlStrip() {
    final elapsed = _dragPosition ?? _elapsedSeconds;
    final duration = _durationSec;
    final max =
        duration != null && duration > elapsed ? duration : _maxDragSeconds;
    const timeStyle = TextStyle(
        color: AppColors.inkMuted,
        fontSize: 10.5,
        fontFeatures: [FontFeature.tabularFigures()]);
    Widget icon(InIconData i, String label, VoidCallback onTap,
            {double size = 22, Color color = Colors.white}) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTap,
            radius: size,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: InIcon(i, color: color, size: size),
            ),
          ),
        );
    final like = widget.onToggleLike == null
        ? null
        : icon(InIcons.heart, widget.liked ? 'Unlike' : 'Like',
            widget.onToggleLike!,
            color: widget.liked ? AppColors.pink : Colors.white);
    final settings =
        icon(InIcons.gear, 'Player settings', _openSettingsSheet, size: 20);
    final right = widget.isHost
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            settings,
            if (widget.onSkip != null)
              icon(InIcons.skipNext, 'Next in queue', widget.onSkip!, size: 20),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (like != null) like,
            settings,
            if (widget.onVoteSkip != null)
              Semantics(
                button: true,
                label:
                    'Vote to skip, ${widget.skipVoteCount} of ${widget.skipVoteRequired}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: widget.onVoteSkip,
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const InIcon(InIcons.skipNext,
                          color: Colors.white, size: 15),
                      const SizedBox(width: 4),
                      Text(
                          'Vote skip · ${widget.skipVoteCount}/${widget.skipVoteRequired}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ]);
    return ColoredBox(
      color: Colors.black,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // The bar runs along the bottom edge of the picture, as on YouTube.
        SizedBox(
          height: 14,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: widget.isHost ? 6 : 0,
                  disabledThumbRadius: 0),
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: const RectangularSliderTrackShape(),
              disabledActiveTrackColor: AppColors.primary,
              disabledInactiveTrackColor: Colors.white24,
            ),
            child: Slider(
              value: elapsed.clamp(0, max),
              max: max,
              activeColor: AppColors.primary,
              inactiveColor: Colors.white24,
              onChanged: widget.isHost && widget.onSeek != null
                  ? _handleSeekChanged
                  : null,
              onChangeEnd: widget.isHost && widget.onSeek != null
                  ? _handleSeekEnd
                  : null,
            ),
          ),
        ),
        // One row: elapsed on the left, every button in the middle, the
        // full length on the right.
        SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Text(_formatTime(elapsed), style: timeStyle),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.isHost) ...[
                        if (widget.onSeek != null)
                          icon(InIcons.back10, 'Back 10 seconds',
                              () => _hostSeekTo(_elapsedSeconds - 10)),
                        icon(
                            _isPlaying ? InIcons.pause : InIcons.play,
                            _isPlaying
                                ? 'Pause for everyone'
                                : 'Play for everyone',
                            _hostTogglePlay,
                            size: 28),
                        if (widget.onSeek != null)
                          icon(InIcons.forward10, 'Forward 10 seconds',
                              () => _hostSeekTo(_elapsedSeconds + 10)),
                      ],
                      right,
                    ]),
                  ),
                ),
              ),
              Text(duration != null ? _formatTime(duration) : '--:--',
                  style: timeStyle),
            ]),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _stretchTimer?.cancel();
    InAppWebViewController.disposeKeepAlive(_keepAlive);
    _loginCheck?.cancel();
    _webSyncTimer?.cancel();
    _tickTimer?.cancel();
    _nudgeDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.videoUrl;
    if (url == null) {
      final placeholder = Container(
          color: AppColors.surface2,
          alignment: Alignment.center,
          child: const Text('No video',
              style: TextStyle(color: AppColors.textFaint)));
      return widget.fillHeight
          ? SizedBox.expand(child: placeholder)
          : AspectRatio(aspectRatio: 16 / 9, child: placeholder);
    }
    // No rounded-corner card/box — the video now runs edge-to-edge at full
    // screen width right under the header, so a "boxed" look doesn't apply.
    final webview = ClipRect(
        child: Stack(
      fit: StackFit.expand,
      children: [
        if (_appOnly)
          const ColoredBox(color: Colors.black)
        else
          IgnorePointer(
            ignoring: _blockTouch,
            child: InAppWebView(
              keepAlive: _keepAlive,
              initialUrlRequest: URLRequest(url: WebUri(url)),
              // The desktop website, the same as where the title was picked
              // (webview_browse_screen.dart), so it opens on the same player.
              initialSettings: desktopWebViewSettings,
              onWebViewCreated: (controller) {
                _controller = controller;
                if (_isOtt) {
                  _webSync = OttSyncEngine(
                    target: _WebPlayerTarget(controller),
                    isHost: () => widget.isHost,
                    roomPlaying: () => _isPlaying,
                    hasRoomState: () => _playback != null,
                    roomPosition: () => _elapsedSeconds,
                    onPlay: _emitPlay,
                    onPause: _emitPause,
                    onSeek: widget.onSeek == null ? null : _emitSeek,
                  );
                }
              },
              // Sign-in can finish without a full page load.
              onUpdateVisitedHistory: (controller, url, isReload) =>
                  _checkLoginUrl(url),
              onLoadStop: (controller, url) {
                _checkLoginUrl(url);
                _injectFullBleedVideoCss();
                _checkWidevine();
                _watchForLoginWall();
              },
              // Same "don't error out on a custom app-deeplink scheme" guard
              // as webview_browse_screen.dart — see its comment for why.
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final scheme = navigationAction.request.url?.scheme;
                if (scheme != null && scheme != 'http' && scheme != 'https') {
                  // Netflix answers a phone browser's watch link by handing
                  // off to its app (intent:// / nflx://) — confirmed live —
                  // which left this page blank.
                  if (_isOtt && !_useApp && !_webPlayed && !_onLoginPage) {
                    _onAppLink(controller, navigationAction.request.url);
                  }
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              // Android WebView denies DRM (Widevine) permission requests by
              // default — without granting this, Netflix/Prime's player
              // can't initialize EME at all and fails with a generic
              // HTML5-player error (confirmed live: Netflix's M7701-1003)
              // regardless of user agent or anything else being right.
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT);
              },
            ),
          ),
        if ((_webTrouble ?? '').isNotEmpty && !_useApp)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Expanded(
                  child: Text(
                      'It isn’t playing here yet. Press play on the video, '
                      'or open the app.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5)),
                ),
                if (OttRemote.supported && _hasApp)
                  TextButton(
                    onPressed: () => setState(() => _useApp = true),
                    child: const Text('Open app'),
                  ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: () => setState(() => _webTrouble = ''),
                  icon: const InIcon(InIcons.close,
                      size: 16, color: Colors.white70),
                ),
              ]),
            ),
          ),
        if (_isOtt && _showSiteControls)
          Positioned(
            top: 52,
            right: 8,
            child: Semantics(
              button: true,
              label: 'Done with player settings',
              child: GestureDetector(
                onTap: _toggleSiteControls,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _showSiteControls
                          ? AppColors.primary
                          : Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle),
                  child: InIcon(
                      _showSiteControls ? InIcons.check : InIcons.gear,
                      color: Colors.white,
                      size: 18),
                ),
              ),
            ),
          ),
        if (_showSiteControls)
          Positioned(
            left: 8,
            right: 52,
            top: 8,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text(
                    'Change language, subtitles or quality in the player, '
                    'then tap ✓. Only your phone changes.',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ),
        if (_noWidevine || _appOnly)
          Positioned.fill(
            child: LayoutBuilder(builder: (context, box) {
              final roomy = box.maxHeight >= 150;
              return Padding(
                padding:
                    EdgeInsets.only(bottom: roomy ? 88 : box.maxHeight * 0.5),
                child: _appOnly
                    ? OttSyncPanel(
                        key: _ottPanel,
                        platform:
                            _drmPlatform == 'Netflix' ? 'netflix' : 'amazon',
                        label: _drmPlatform!,
                        titleUrl: widget.videoUrl!,
                        isHost: widget.isHost,
                        roomPlaying: _isPlaying,
                        hasRoomState: _playback != null,
                        roomPosition: () => _elapsedSeconds,
                        onPlay: _emitPlay,
                        onPause: _emitPause,
                        onSeek: widget.onSeek == null ? null : _emitSeek,
                        onStatus: widget.onOttStatus,
                        statuses: widget.ottStatuses,
                        roomy: roomy,
                      )
                    : _noWidevineNotice(roomy),
              );
            }),
          ),
        if (_needsLogin && !_onLoginPage)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.72),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const InIcon(InIcons.lock, size: 26, color: Colors.white),
                    const SizedBox(height: 8),
                    Text('Log in to ${_drmPlatform ?? 'watch'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                        'Everyone watches with their own account. Log in, '
                        'then you’ll catch up with the room.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _openLogin,
                      child: const Text('Log in'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        if (_onLoginPage)
          Positioned(
            left: 8,
            right: 8,
            bottom: 96,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Expanded(
                  child: Text('Log in with your own account, then go back.',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                TextButton(
                  onPressed: _backToShow,
                  child: const Text('Back to the show'),
                ),
              ]),
            ),
          ),
        if (_heldForAds || (_webStatus == 'ad'))
          Positioned(
            top: 8,
            left: 8,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    _webStatus == 'ad'
                        ? 'Ad playing · the room will wait'
                        : 'Waiting for ads on ${_screensInAds == 0 ? 1 : _screensInAds} screen${_screensInAds > 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        if (_nudgeBanner != null)
          Positioned(
            top: 44,
            left: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _nudgeBanner!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    ));
    // The controls sit under the picture, never over it. Where there's no
    // room for them (the small floating window), just the picture.
    const stripHeight = 60.0;
    // The title's own shape once its video reports one (ads included), so
    // it fits exactly; 16:9 until then.
    final seen = _webSync?.local?.aspect;
    final ratio = widget.compact
        ? 21 / 9
        : (seen != null && seen >= 0.5 && seen <= 2.6 ? seen : 16 / 9);
    return LayoutBuilder(builder: (context, box) {
      if (widget.fillHeight) {
        final room = !box.hasBoundedHeight || box.maxHeight >= stripHeight * 2;
        return room
            ? Column(children: [Expanded(child: webview), _controlStrip()])
            : SizedBox.expand(child: webview);
      }
      final pictureHeight = box.maxWidth / ratio;
      final room =
          !box.hasBoundedHeight || box.maxHeight >= pictureHeight + stripHeight;
      final picture = FitVideoBox(aspectRatio: ratio, child: webview);
      if (!room) return picture;
      return Column(
          mainAxisSize: MainAxisSize.min, children: [picture, _controlStrip()]);
    });
  }
}

/// Netflix's (or Prime's) web player inside the room's WebView. Uses
/// Netflix's own player controls where the page exposes them — setting
/// the video element's time directly makes Netflix error out — and the
/// plain <video> element otherwise. Copy protection covers the picture,
/// not these controls, so the page's own script can drive them.
class _WebPlayerTarget implements OttTarget {
  final InAppWebViewController controller;
  _WebPlayerTarget(this.controller);

  /// Set once the page shows a playback error.
  bool error = false;
  String? errorCode;

  static const _setup = r"""
(function(){
  if (window.__insync) return;
  function nfPlayer(){
    try {
      var vp = netflix.appContext.state.playerApp.getAPI().videoPlayer;
      var ids = vp.getAllPlayerSessionIds();
      var id = ids.filter(function(i){ return i.indexOf('watch') >= 0; })[0] || ids[ids.length - 1];
      return id ? vp.getVideoPlayerBySessionId(id) : null;
    } catch (e) { return null; }
  }
  function video(){
    var vs = Array.from(document.querySelectorAll('video'));
    vs.sort(function(a,b){ return (b.offsetWidth*b.offsetHeight) - (a.offsetWidth*a.offsetHeight); });
    return vs[0] || null;
  }
  function inAd(){
    if (document.querySelector('.ad-showing, .ad-interrupting, [class*="ad-badge"], [class*="adBadge"], [class*="AdBadge"], [class*="ad-countdown"], [data-testid*="ad-badge"], [aria-label*="Advertisement"]')) return true;
    var t = document.body ? document.body.innerText.slice(0, 3000) : '';
    return /(^|\n)\s*(Ad|Advertisement)\s*([·•:|]|\d+\s*(of|\/)\s*\d+)/i.test(t) || /Skip Ads?\b|Ad will end in|Your video will (play|resume) after/i.test(t);
  }
  function hasError(){
    if (document.querySelector('.nf-error, .error-page, [data-uia="error-page"], [data-uia="player-error"]')) return true;
    var t = document.body ? document.body.innerText.slice(0, 4000) : '';
    return /Error Code|Pardon the interruption|isn.t available to watch/i.test(t);
  }
  window.__insync = {
    state: function(){
      if (hasError()) {
        var m = (document.body ? document.body.innerText : '').match(/\b[A-Z]{1,3}\d{2,5}(-\d+)?\b/);
        return JSON.stringify({error: true, code: m ? m[0] : null});
      }
      var v = video();
      if (!v || !(v.duration > 0)) return null;
      var p = nfPlayer();
      var pos = p && p.getCurrentTime ? p.getCurrentTime() / 1000 : v.currentTime;
      var dur = p && p.getDuration ? p.getDuration() / 1000 : v.duration;
      return JSON.stringify({playing: !v.paused, pos: pos, dur: isFinite(dur) ? dur : 0, canSeek: true, ad: inAd(), ar: (v.videoWidth && v.videoHeight) ? v.videoWidth / v.videoHeight : 0});
    },
    play: function(){ var p = nfPlayer(); if (p && p.play) p.play(); else { var v = video(); if (v) v.play(); } },
    pause: function(){ var p = nfPlayer(); if (p && p.pause) p.pause(); else { var v = video(); if (v) v.pause(); } },
    seek: function(s){ var p = nfPlayer(); if (p && p.seek) p.seek(Math.round(s * 1000)); else { var v = video(); if (v) v.currentTime = s; } }
  };
})();
""";

  Future<dynamic> _run(String call) async {
    try {
      return await controller.evaluateJavascript(source: '$_setup\n$call');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OttPlayerState?> state() async {
    final raw = await _run('window.__insync.state()');
    if (raw is! String) return null;
    final m = jsonDecode(raw);
    if (m is! Map) return null;
    if (m['error'] == true) {
      error = true;
      errorCode = m['code'] as String?;
      return null;
    }
    return OttPlayerState(
      playing: m['playing'] == true,
      positionSec: (m['pos'] as num?)?.toDouble() ?? 0,
      canSeek: m['canSeek'] == true,
      durationSec:
          ((m['dur'] as num?) ?? 0) > 0 ? (m['dur'] as num).toDouble() : null,
      inAd: m['ad'] == true,
      aspect: ((m['ar'] as num?) ?? 0) > 0 ? (m['ar'] as num).toDouble() : null,
    );
  }

  @override
  Future<void> play() => _run('window.__insync.play()');
  @override
  Future<void> pause() => _run('window.__insync.pause()');
  @override
  Future<void> seekTo(double seconds) => _run('window.__insync.seek($seconds)');
}

/// Bottom sheet for the person's own player settings: speed, and the
/// title's audio languages and subtitles where the site's video lists them.
/// Anything else (quality on most sites) is in the site's own menu, which
/// "More settings" opens.
class _OttSettingsSheet extends StatefulWidget {
  final String label;
  final double rate;
  final List<Map> audio;
  final List<Map> text;
  final ValueChanged<double> onRate;
  final ValueChanged<int> onAudio;
  final ValueChanged<int> onText;
  final VoidCallback onMore;
  final bool fill;
  final ValueChanged<bool> onFill;
  const _OttSettingsSheet({
    required this.fill,
    required this.onFill,
    required this.label,
    required this.rate,
    required this.audio,
    required this.text,
    required this.onRate,
    required this.onAudio,
    required this.onText,
    required this.onMore,
  });

  @override
  State<_OttSettingsSheet> createState() => _OttSettingsSheetState();
}

class _OttSettingsSheetState extends State<_OttSettingsSheet> {
  static const _rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  late double _rate = widget.rate;
  late int? _audio = _onIndex(widget.audio);
  late int _text = _onIndex(widget.text) ?? -1;
  // Which list is open: null for the main settings list.
  String? _page;

  static int? _onIndex(List<Map> list) {
    for (final m in list) {
      if (m['on'] == true) return (m['i'] as num).toInt();
    }
    return null;
  }

  String _rateLabel(double r) => r == 1.0
      ? 'Normal'
      : (r == r.roundToDouble() ? '${r.toInt()}x' : '${r}x');

  String _labelOf(List<Map> list, int? i, String none) {
    for (final m in list) {
      if ((m['i'] as num).toInt() == i) return '${m['label']}';
    }
    return none;
  }

  Widget _row(
          InIconData icon, String label, String value, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(children: [
            InIcon(icon, size: 18, color: AppColors.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text(value,
                style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(width: 6),
            const InIcon(InIcons.right, size: 16, color: AppColors.textFaint),
          ]),
        ),
      );

  Widget _pick(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: on
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
                ),
                if (on)
                  const InIcon(InIcons.check, size: 18, color: AppColors.lilac),
              ]),
            ),
          ),
        ),
      );

  Widget _header(String title, {bool back = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(children: [
          if (back)
            IconButton(
              tooltip: 'Back',
              onPressed: () => setState(() => _page = null),
              icon: const InIcon(InIcons.back,
                  size: 18, color: AppColors.inkMuted),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: InIcon(InIcons.gear, size: 18, color: AppColors.lilac),
            ),
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          if (!back)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('Only your phone changes',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
            ),
        ]),
      );

  List<Widget> _main() => [
        _header('Player settings'),
        _row(InIcons.play, 'Speed', _rateLabel(_rate),
            () => setState(() => _page = 'speed')),
        // Quality is chosen in the site's own menu on these players.
        _row(InIcons.tv, 'Quality', 'On ${widget.label}', widget.onMore),
        widget.audio.length > 1
            ? _row(
                InIcons.speaker,
                'Audio language',
                _labelOf(widget.audio, _audio, 'Default'),
                () => setState(() => _page = 'audio'))
            : _row(InIcons.speaker, 'Audio language', 'On ${widget.label}',
                widget.onMore),
        widget.text.isNotEmpty
            ? _row(
                InIcons.comment,
                'Subtitles',
                _labelOf(widget.text, _text, 'Off'),
                () => setState(() => _page = 'text'))
            : _row(InIcons.comment, 'Subtitles', 'On ${widget.label}',
                widget.onMore),
        const Divider(color: AppColors.border, height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onMore,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              const InIcon(InIcons.more, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text('More settings on ${widget.label}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const InIcon(InIcons.right, size: 16, color: AppColors.textFaint),
            ]),
          ),
        ),
      ];

  List<Widget> _picture() => [
        _header('Picture', back: true),
        _pick('Fill · no black bands', widget.fill, () {
          widget.onFill(true);
          setState(() => _page = null);
        }),
        _pick('Fit · show the whole picture', !widget.fill, () {
          widget.onFill(false);
          setState(() => _page = null);
        }),
      ];

  List<Widget> _speed() => [
        _header('Speed', back: true),
        for (final r in _rates)
          _pick(_rateLabel(r), (_rate - r).abs() < 0.01, () {
            widget.onRate(r);
            setState(() {
              _rate = r;
              _page = null;
            });
          }),
      ];

  List<Widget> _audioPage() => [
        _header('Audio language', back: true),
        for (final a in widget.audio)
          _pick('${a['label']}', _audio == (a['i'] as num).toInt(), () {
            final i = (a['i'] as num).toInt();
            widget.onAudio(i);
            setState(() {
              _audio = i;
              _page = null;
            });
          }),
      ];

  List<Widget> _textPage() => [
        _header('Subtitles', back: true),
        _pick('Off', _text == -1, () {
          widget.onText(-1);
          setState(() {
            _text = -1;
            _page = null;
          });
        }),
        for (final s in widget.text)
          _pick('${s['label']}', _text == (s['i'] as num).toInt(), () {
            final i = (s['i'] as num).toInt();
            widget.onText(i);
            setState(() {
              _text = i;
              _page = null;
            });
          }),
      ];

  @override
  Widget build(BuildContext context) {
    final children = switch (_page) {
      'speed' => _speed(),
      'audio' => _audioPage(),
      'text' => _textPage(),
      'picture' => _picture(),
      _ => _main(),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: Column(
              key: ValueKey(_page),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2))),
                ),
                ...children,
              ]),
        ),
      ),
    );
  }
}
