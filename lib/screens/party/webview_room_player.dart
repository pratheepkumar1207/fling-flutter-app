import '../../theme/insync_icons.dart';
import 'dart:async';
import 'dart:convert';

import '../../widgets/fit_video_box.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/drm_support.dart';
import '../../core/mobile_webview_settings.dart';
import '../../theme/app_colors.dart';
import 'ott_sync_engine.dart';
import 'ott_sync_panel.dart';
import '../../core/ott_remote.dart';
import '../../core/ott_page_suggestions.dart';
import '../../core/title_page_list.dart';
import '../../core/room_playback.dart';
import '../../core/room_prefs.dart';
import '../../core/prime_player_menu.dart';
import '../../core/hotstar_player_menu.dart';
import '../../core/aha_player_menu.dart';
import 'full_screen_controls.dart';
import 'player_settings_sheet.dart';

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

/// The address that opens straight on the title's player. Prime Video
/// drops `autoplay=1` from its address once a title starts (it becomes
/// `?ref_=atv_plr_detail_play`), and its trailer button uses
/// `autoplay=trailer`; either way a pinned link would open the title's
/// info page, where nothing plays. Other sites are left as they are.
String playableOttUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null ||
      !u.host.contains('primevideo.') ||
      !u.path.contains('/detail/')) {
    return url;
  }
  if (u.queryParameters['autoplay'] == '1') return url;
  final q = Map<String, String>.from(u.queryParameters)
    ..remove('ref_')
    ..['autoplay'] = '1';
  q.putIfAbsent('t', () => '0');
  return u.replace(queryParameters: q).toString();
}

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
  // Host only: the room's speed for everyone (playback:rate).
  final void Function(double rate, double position)? onRate;
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
    this.onRate,
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

  void _record(double position, bool playing, {double? rate}) => _hostLocal = {
        'position': position,
        'isPlaying': playing,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'rate': rate ?? roomRate(_playback),
      };

  void _emitRate(double rate) {
    final at = _elapsedSeconds;
    _record(at, _isPlaying, rate: rate);
    widget.onRate?.call(rate, at);
    _applyRoomRate();
  }

  // Everyone's video runs at the room's speed (the host's choice).
  double? _appliedRate;
  void _applyRoomRate() {
    final r = roomRate(_playback);
    if (_appliedRate == r) return;
    _appliedRate = r;
    _settingsCall(
        'if (Math.abs(v.playbackRate - $r) > 0.01) v.playbackRate = $r;');
  }

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

  double get _elapsedSeconds => roomPosition(_playback);

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
  // The person went to sign in from the room. Once the site shows them
  // signed in, they're taken back to the room's title, which then plays in
  // step with the room (see _watchSignIn).
  bool _signingIn = false;
  Timer? _signInWatch;

  // Watches for the sign-in to finish: the site leaves its login page, or
  // (sites that sign in over the page, like Hotstar) its Log in buttons go
  // away for a couple of checks in a row.
  void _watchSignIn() {
    _signInWatch?.cancel();
    _signingIn = true;
    var clear = 0;
    var checks = 0;
    _signInWatch = Timer.periodic(const Duration(seconds: 3), (timer) async {
      checks++;
      if (!mounted || !_signingIn || checks > 200) {
        timer.cancel();
        return;
      }
      if (_onLoginPage || checks < 3) {
        clear = 0;
        return;
      }
      try {
        final wall =
            await _controller?.evaluateJavascript(source: _loginWallScript);
        clear = wall == true ? 0 : clear + 1;
        if (clear >= 2) {
          timer.cancel();
          _signedInGoBack();
        }
      } catch (_) {}
    });
  }

  Future<void> _signedInGoBack() async {
    if (!_signingIn || !mounted) return;
    _signingIn = false;
    _signInWatch?.cancel();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('Signed in. Back to the show…'),
        duration: Duration(seconds: 2)));
    await _backToShow();
  }

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
    _watchSignIn();
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

  // The error code on the site's own error page, e.g. Netflix's
  // M7111-1957 — Netflix's sign-in on this phone has run out.
  String? _siteErrorCode;
  bool get _signInExpired => (_siteErrorCode ?? '').startsWith('M7111');

  // Netflix's own fix for its M7111 codes: clear what the site saved on
  // this phone and sign in again. Only this site's saved login, only on
  // this phone; nothing is sent anywhere.
  Future<void> _signInAgain() async {
    final home = Uri.tryParse(widget.videoUrl ?? '');
    if (home == null || !home.hasScheme) return;
    final site = WebUri('${home.scheme}://${home.host}');
    try {
      await CookieManager.instance().deleteCookies(url: site);
      final parts = home.host.split('.');
      if (parts.length >= 2) {
        final domain = '.${parts.sublist(parts.length - 2).join('.')}';
        await CookieManager.instance().deleteCookies(url: site, domain: domain);
      }
      await WebStorageManager.instance().deleteOrigin(origin: site.toString());
    } catch (e) {
      debugPrint('OTT: clearing the site sign-in failed: $e');
    }
    final target = _webSync?.target;
    if (target is _WebPlayerTarget) {
      target.error = false;
      target.errorCode = null;
    }
    setState(() {
      _siteErrorCode = null;
      _webTrouble = null;
      _webPlayed = false;
    });
    _tryStarted = DateTime.now();
    final login = home.host.contains('netflix.com')
        ? 'https://www.netflix.com/login'
        : '${home.scheme}://${home.host}/';
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(login)));
    _watchSignIn();
    _watchForLoginWall();
  }

  // Logged in: back to the room's title, which then catches up with the room.
  Future<void> _backToShow() async {
    final url = widget.videoUrl;
    if (url == null) return;
    _signingIn = false;
    _signInWatch?.cancel();
    setState(() {
      _needsLogin = false;
      _onLoginPage = false;
    });
    _tryStarted = DateTime.now();
    await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(playableOttUrl(url))));
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
      final leftLogin = _onLoginPage && !looksLikeLogin;
      _tryStarted = DateTime.now();
      setState(() => _onLoginPage = looksLikeLogin);
      // Reached the login page some other way (the site sent them there):
      // still bring them back once they're done.
      if (looksLikeLogin && !_signingIn) _watchSignIn();
      // The site moved on from its login page (to its home, a profile
      // picker): signed in, so back to the room's title.
      if (leftLogin && _signingIn) {
        Future.delayed(const Duration(milliseconds: 1500), _signedInGoBack);
      }
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
      return JSON.stringify({rate: v.playbackRate || 1, volume: v.muted ? 0 : v.volume, audio: audio, text: text});
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

  // Prime Video, Hotstar and Aha: the lists from their own players, kept per
  // title so the sheet shows them straight away next time, refreshed each
  // time it opens. One menu job at a time on the page.
  final _siteLists = ValueNotifier<Map<String, List<Map>>?>(null);
  String? _siteListsFor;
  Future<void> _menuWork = Future.value();
  bool _settingsOpen = false;

  Future<T> _onMenu<T>(Future<T> Function() job) {
    final next = _menuWork.then((_) => job());
    _menuWork = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _openSettingsSheet() async {
    // A second tap while it's opening or open does nothing.
    if (_settingsOpen) return;
    _settingsOpen = true;
    try {
      await _showSettingsSheet();
    } finally {
      _settingsOpen = false;
    }
  }

  Future<void> _showSettingsSheet() async {
    Map<String, dynamic> info = const {};
    try {
      final raw = await _controller?.evaluateJavascript(source: _settingsRead);
      if (raw is String) info = Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {}
    if (!mounted) return;
    final c = _controller;
    final isPrime = _drmPlatform == 'Prime Video';
    final isHotstar = _drmPlatform == 'Hotstar';
    final isAha = _drmPlatform == 'Aha';
    final siteMenus = c != null && (isPrime || isHotstar || isAha);
    if (_siteListsFor != widget.videoUrl) {
      _siteListsFor = widget.videoUrl;
      _siteLists.value = null;
    }
    if (siteMenus) {
      // The sheet opens now; the lists fill in when the page answers.
      _onMenu(() async {
        final lists = isPrime
            ? await PrimePlayerMenu.read(c)
            : isAha
                ? await AhaPlayerMenu.read(c)
                : await HotstarPlayerMenu.read(c);
        if (mounted && lists != null) _siteLists.value = lists;
        if (mounted && lists == null && _siteLists.value == null) {
          _siteLists.value = const {};
        }
      });
    }
    final label = _drmPlatform ?? 'this site';
    void siteMenu() {
      if (!_showSiteControls) _toggleSiteControls();
    }

    ValueChanged<int>? sitePick(
        Map<String, List<Map>>? lists, String key, String row, String name) {
      final list = lists?[key] ?? const <Map>[];
      if (c == null || list.isEmpty) return null;
      return (i) {
        final value =
            i < 0 ? null : '${list.firstWhere((m) => m['i'] == i)['value']}';
        // The tick moves now; the page follows a moment later.
        _siteLists.value = {
          ...?lists,
          key: [
            for (final m in list) {...m, 'on': m['i'] == i}
          ],
        };
        _onMenu(() => isHotstar
            ? HotstarPlayerMenu.pick(c, kind: key, value: value ?? 'Off')
            : isAha
                ? AhaPlayerMenu.pick(c, kind: key, value: value ?? 'Off')
                : PrimePlayerMenu.pick(c,
                    row: row, name: name, value: value ?? 'off'));
      };
    }

    final ownAudio = ((info['audio'] as List?) ?? const []).cast<Map>();
    final ownText = ((info['text'] as List?) ?? const []).cast<Map>();
    await showPlayerSettings(
      context,
      (ctx) => ValueListenableBuilder<Map<String, List<Map>>?>(
        valueListenable: _siteLists,
        builder: (ctx, lists, _) => PlayerSettingsSheet(
          label: label,
          isHost: widget.isHost,
          rate: roomRate(_playback),
          onRate: widget.isHost && widget.onRate != null ? _emitRate : null,
          // Still reading the site's own menu.
          loadingSiteLists: siteMenus && lists == null,
          // Quality is chosen in the site's own menu on these players,
          // except Prime and Hotstar, whose choices are listed here.
          onQuality: () {
            Navigator.of(ctx).pop();
            siteMenu();
          },
          qualities: lists?['quality'] ?? const [],
          onQualityPick:
              sitePick(lists, 'quality', 'Video Quality', 'videoQuality'),
          audio: (lists?['audio']?.isNotEmpty ?? false)
              ? lists!['audio']!
              : ownAudio,
          text:
              (lists?['text']?.isNotEmpty ?? false) ? lists!['text']! : ownText,
          onAudio: sitePick(lists, 'audio', 'Audio', 'Audio') ??
              (i) => _settingsCall(
                  'for (var k = 0; k < v.audioTracks.length; k++) v.audioTracks[k].enabled = (k === $i);'),
          onText: sitePick(lists, 'text', 'Subtitles', 'subtitle') ??
              (i) => _settingsCall(
                  'for (var k = 0; k < v.textTracks.length; k++) v.textTracks[k].mode = (k === $i) ? "showing" : "disabled";'),
          volume: ((info['volume'] as num?)?.toDouble() ?? 1) * 100 ~/ 1,
          onVolume: (v) =>
              _settingsCall('v.muted = false; v.volume = ${v / 100};'),
          offsetSec: _webSync?.offset,
          onCatchUp: _catchUp,
          onSiteMenu: siteMenu,
        ),
      ),
    );
  }

  // A viewer's own jump to where the host is (after their network fell
  // behind, say) — their phone only.
  Future<void> _catchUp() async {
    final sync = _webSync;
    if (sync == null) return;
    try {
      await sync.target.seekTo(_elapsedSeconds);
      if (_isPlaying) await sync.target.play();
    } catch (_) {}
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
            ['position','top','left','width','height','object-fit','background','z-index','pointer-events']
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
            ['position','top','left','width','height','object-fit','background','z-index','pointer-events']
              .forEach(function(k) { v.style.removeProperty(k); });
            v.removeAttribute('data-insync-full');
          }
        });
        var props = {
          position: 'fixed', top: '0', left: '0',
          width: '100vw', height: '100vh',
          'object-fit': fit, background: '#000',
          'z-index': '2147483647',
          // Touches and the room's pointer pass through to the site's own
          // control layer under the stretched video (prime_player_menu.dart
          // needs Prime's buttons to appear).
          'pointer-events': 'none',
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
                "window.__insyncFit = '${_fillsScreen ? 'cover' : 'contain'}';\n$script");
      } catch (_) {}
    });
  }

  Timer? _stretchTimer;
  // The video shape the box was last laid out for.
  double? _shownAspect;
  // Upright the box already has the video's own shape. In full screen the
  // picture zooms to fill the screen (edges trimmed) unless this person
  // picked Fit; a tall video (a reel) always shows whole there.
  bool _fullScreen = false;
  bool get _fillsScreen {
    final ar = _webSync?.local?.aspect;
    return _fullScreen &&
        RoomPrefs.instance.fillScreen &&
        (ar == null || ar >= 1);
  }

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
        final code = (sync.target as _WebPlayerTarget).errorCode;
        if (_siteErrorCode != code) setState(() => _siteErrorCode = code);
        _moveToApp('the web player showed an error page: $code');
        return;
      }
      if (widget.isHost) await _followHostTitle(sync.local);
      if (widget.isHost) _holdForAds(sync.local);
      if (_webTrouble == null) _judgeWebTry(sync.local);
      _applyRoomRate();
      if (_useApp) return;
      if (_webTrouble != null && sync.local?.playing == true) {
        setState(() {
          _webTrouble = null;
          _webPlayed = true;
        });
      }
      if (status != _webStatus) setState(() => _webStatus = status);
      // The box takes the video's own shape as soon as the page reports it
      // (and again when it changes, e.g. an ad then the film), so there are
      // no black bands above and below eating into the chat.
      final ar = sync.local?.aspect;
      if (ar != null &&
          (_shownAspect == null || (ar - _shownAspect!).abs() > 0.02)) {
        setState(() => _shownAspect = ar);
      }
      _reportStatus(status, sync.offset);
      unawaited(_readPageSuggestions());
    } finally {
      _webBusy = false;
    }
  }

  // Prime Video: the title's own page stays loaded behind its player, with
  // the season's episodes and "Customers also watched". Read every so often
  // for the suggestions panel (video_suggestions_panel.dart).
  DateTime _pageListReadAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _pageListEvery = Duration(seconds: 15);

  static const _readPageList = r"""
(function(){
  function abs(h){ try { return new URL(h, location.href).href; } catch(e){ return null; } }
  function pic(root){ var im = root && root.querySelector('img'); if (!im) return null; var s = im.currentSrc || im.src || im.getAttribute('data-src') || ''; return /^https?:/.test(s) ? s : null; }
  var out = [], seen = {}, here = location.pathname, eps = [];
  document.querySelectorAll('a[data-testid="episodes-playbutton"]').forEach(function(a){
    var u = abs(a.getAttribute('href')); if (!u) return; var k = new URL(u).pathname; if (seen[k]) return; seen[k] = 1;
    var card = a.closest('li') || a.parentElement;
    var h = card && card.querySelector('h3');
    var m = (a.getAttribute('aria-label') || '').match(/S\d+\s*E\d+/i);
    eps.push({videoUrl: u, title: (h ? h.textContent.trim() : 'Episode').slice(0, 120), badge: m ? m[0].toUpperCase() : null, thumbnail: pic(card), path: k});
  });
  var at = eps.findIndex(function(e){ return e.path === here; });
  (at >= 0 ? eps.slice(at + 1) : eps).forEach(function(e){ delete e.path; out.push(e); });
  seen[here] = 1;
  document.querySelectorAll('section, [data-testid*="carousel"]').forEach(function(s){
    var hd = s.querySelector('h2, h3');
    if (!hd || !/also watched|more like this|you may also like|related/i.test(hd.textContent)) return;
    s.querySelectorAll('a[href*="/detail/"]').forEach(function(a){
      var u = abs(a.getAttribute('href')); if (!u) return; var k = new URL(u).pathname; if (seen[k]) return; seen[k] = 1;
      var card = a.closest('li') || a.parentElement;
      var b = card && card.querySelector('button[aria-label]');
      var t = (b && b.getAttribute('aria-label')) || a.textContent.trim();
      out.push({videoUrl: u, title: (t || 'Prime Video').slice(0, 120), thumbnail: pic(card)});
    });
  });
  return JSON.stringify(out.slice(0, 40));
})()
""";

  // Netflix/Hotstar: read once per title from its own page in a hidden
  // view (TitlePageList). A page that gave nothing is tried again after a
  // while, not on every tick.
  String? _titleListFor;
  DateTime _titleListTriedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _readTitlePageList() async {
    final url = widget.videoUrl;
    final now = DateTime.now();
    if (url == null ||
        _titleListFor == url ||
        now.difference(_titleListTriedAt) < const Duration(minutes: 2)) {
      return;
    }
    _titleListFor = url;
    _titleListTriedAt = now;
    final items = await TitlePageList.read(url);
    if (items.isEmpty) {
      _titleListFor = null;
      return;
    }
    OttPageSuggestions.current.value = (
      key: OttPageSuggestions.keyFor(url),
      items: [
        for (final e in items)
          {
            ...e,
            'thumbnail':
                OttPageSuggestions.jpegThumbnail(e['thumbnail'] as String?),
          }
      ],
    );
  }

  Future<void> _readPageSuggestions() async {
    if (_drmPlatform == 'Netflix' || _drmPlatform == 'Hotstar') {
      // After the title has started, so the hidden page doesn't compete
      // with the player while it loads.
      if (_webPlayed ||
          DateTime.now().difference(_tryStarted) >
              const Duration(seconds: 20)) {
        await _readTitlePageList();
      }
      return;
    }
    final c = _controller;
    final now = DateTime.now();
    if (c == null ||
        _drmPlatform != 'Prime Video' ||
        now.difference(_pageListReadAt) < _pageListEvery) {
      return;
    }
    _pageListReadAt = now;
    try {
      final raw = await c.evaluateJavascript(source: _readPageList);
      if (raw is! String) return;
      final items = [
        for (final e in (jsonDecode(raw) as List).whereType<Map>())
          {
            'videoUrl': playableOttUrl(e['videoUrl'] as String),
            'title': e['title'] as String? ?? 'Prime Video',
            'thumbnail':
                OttPageSuggestions.jpegThumbnail(e['thumbnail'] as String?),
            'badge': e['badge'],
            'sourceType': 'amazon',
          }
      ];
      if (items.isEmpty) return;
      OttPageSuggestions.current.value =
          (key: OttPageSuggestions.keyFor(widget.videoUrl), items: items);
    } catch (_) {}
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

  // Upright: nothing under the video. A tap on the picture shows the
  // controls over it for 3 seconds (the tap reaches the room, never the
  // site's own player); a thin light line along the bottom edge shows how
  // far it has played, as on YouTube Shorts.
  bool _tapControls = false;
  Timer? _tapHide;

  void _showTapControls() {
    _tapHide?.cancel();
    setState(() => _tapControls = true);
    _tapHide = Timer(const Duration(seconds: 3), () {
      if (mounted && _dragPosition == null) {
        setState(() => _tapControls = false);
      }
    });
  }

  void _toggleTapControls() {
    if (_tapControls) {
      _tapHide?.cancel();
      setState(() => _tapControls = false);
    } else {
      _showTapControls();
    }
  }

  // A button on the overlay: does its job and keeps the controls up.
  Widget _overlayIcon(InIconData i, String label, VoidCallback? onTap,
          {double size = 22, Color color = Colors.white}) =>
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap == null
              ? null
              : () {
                  onTap();
                  _showTapControls();
                },
          radius: size + 4,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: InIcon(i, size: size, color: color),
          ),
        ),
      );

  void _enterFullScreen() => SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  Widget _progressLine() {
    final elapsed = _dragPosition ?? _elapsedSeconds;
    final duration = _durationSec;
    final value = duration != null && duration > 0
        ? (elapsed / duration).clamp(0.0, 1.0)
        : 0.0;
    return IgnorePointer(
      child: SizedBox(
        height: 2,
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.white24),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: const ColoredBox(color: Color(0xE6FFFFFF)),
          ),
        ]),
      ),
    );
  }

  Widget _tapOverlay() {
    final elapsed = _dragPosition ?? _elapsedSeconds;
    final duration = _durationSec;
    final max =
        duration != null && duration > elapsed ? duration : _maxDragSeconds;
    const timeStyle = TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontFeatures: [FontFeature.tabularFigures()]);
    final like = widget.onToggleLike == null
        ? null
        : _overlayIcon(InIcons.heart, widget.liked ? 'Unlike' : 'Like',
            widget.onToggleLike,
            color: widget.liked ? AppColors.pink : Colors.white);
    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Color(0x61000000))),
      Positioned(
        top: 0,
        right: 2,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (like != null) like,
          _overlayIcon(InIcons.more, 'Player settings', _openSettingsSheet,
              size: 20),
        ]),
      ),
      if (widget.isHost)
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.onSeek != null)
              _overlayIcon(InIcons.back10, 'Back 10 seconds',
                  () => _hostSeekTo(_elapsedSeconds - 10)),
            const SizedBox(width: 18),
            _overlayIcon(
                _isPlaying ? InIcons.pause : InIcons.play,
                _isPlaying ? 'Pause for everyone' : 'Play for everyone',
                _hostTogglePlay,
                size: 34),
            const SizedBox(width: 18),
            if (widget.onSeek != null)
              _overlayIcon(InIcons.forward10, 'Forward 10 seconds',
                  () => _hostSeekTo(_elapsedSeconds + 10)),
          ]),
        ),
      Positioned(
        left: 10,
        right: 2,
        bottom: 6,
        child: Row(children: [
          Text(
              '${_formatTime(elapsed)} / ${duration != null ? _formatTime(duration) : '--:--'}',
              style: timeStyle),
          const Spacer(),
          if (widget.isHost && widget.onSkip != null)
            _overlayIcon(InIcons.skipNext, 'Next in queue', widget.onSkip,
                size: 20),
          if (!widget.isHost && widget.onVoteSkip != null)
            Semantics(
              button: true,
              label:
                  'Vote to skip, ${widget.skipVoteCount} of ${widget.skipVoteRequired}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  widget.onVoteSkip!();
                  _showTapControls();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14)),
                  child: Text(
                      'Vote skip ${widget.skipVoteCount}/${widget.skipVoteRequired}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          _overlayIcon(InIcons.fullscreen, 'Full screen', _enterFullScreen,
              size: 20),
        ]),
      ),
      // The host drags the line itself to move the room.
      if (widget.isHost && widget.onSeek != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: -6,
          height: 16,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: elapsed.clamp(0, max),
              max: max,
              activeColor: const Color(0xE6FFFFFF),
              inactiveColor: Colors.white24,
              onChanged: (v) {
                _tapHide?.cancel();
                _handleSeekChanged(v);
              },
              onChangeEnd: (v) {
                _handleSeekEnd(v);
                _showTapControls();
              },
            ),
          ),
        ),
    ]);
  }

  @override
  void dispose() {
    _tapHide?.cancel();
    _siteLists.dispose();
    _stretchTimer?.cancel();
    InAppWebViewController.disposeKeepAlive(_keepAlive);
    _loginCheck?.cancel();
    _signInWatch?.cancel();
    _webSyncTimer?.cancel();
    _tickTimer?.cancel();
    _nudgeDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _fullScreen = !widget.compact &&
        !widget.fillHeight &&
        MediaQuery.orientationOf(context) == Orientation.landscape;
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
              // Every touch on the player goes to the site, so its seek bar
              // and volume can be dragged; the room's own sideways swipe
              // (people list / Home) would otherwise take the drag.
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
              },
              initialUrlRequest: URLRequest(url: WebUri(playableOttUrl(url))),
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
        // Only for a sign-in that ran out; no "press play" bar otherwise.
        if ((_webTrouble ?? '').isNotEmpty && !_useApp && _signInExpired)
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
                Expanded(
                  child: Text(
                      _signInExpired
                          ? '${_drmPlatform ?? 'The site'} says your sign-in on '
                              'this phone has run out ($_siteErrorCode).'
                          : 'It isn’t playing here yet. Press play on the '
                              'video, or open the app.',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12.5)),
                ),
                if (_signInExpired)
                  TextButton(
                    onPressed: _signInAgain,
                    child: const Text('Sign in again'),
                  ),
                if (OttRemote.supported && _hasApp && !_signInExpired)
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
                  child: Text(
                      "Sign in with your own account. You'll come back to the show by itself.",
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
        if (!_fullScreen &&
            !widget.compact &&
            !_showSiteControls &&
            !_needsLogin &&
            !_onLoginPage &&
            !_appOnly &&
            !_noWidevine) ...[
          Positioned(left: 0, right: 0, bottom: 0, child: _progressLine()),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleTapControls,
            ),
          ),
          if (_tapControls) Positioned.fill(child: _tapOverlay()),
        ],
        // Not while the site's own menu, its sign-in or the app note is up:
        // those need the touch.
        if (_fullScreen &&
            !_showSiteControls &&
            !_needsLogin &&
            !_onLoginPage &&
            !_appOnly &&
            !_noWidevine)
          Positioned.fill(
            child: RoomFullScreenControls(
              title: widget.title,
              isHost: widget.isHost,
              playing: _isPlaying,
              elapsed: _dragPosition ?? _elapsedSeconds,
              duration: _durationSec,
              onTogglePlay: _hostTogglePlay,
              onSeekTo: widget.onSeek != null ? _hostSeekTo : null,
              onSkip: widget.onSkip,
              liked: widget.liked,
              onToggleLike: widget.onToggleLike,
              onVoteSkip: widget.onVoteSkip,
              skipVoteCount: widget.skipVoteCount,
              skipVoteRequired: widget.skipVoteRequired,
              onSettings: _openSettingsSheet,
              onCatchUp: _webSync == null ? null : _catchUp,
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
    // The title's own shape once its video reports one (ads included), so
    // it fits exactly; 16:9 until then.
    final seen = _shownAspect ?? _webSync?.local?.aspect;
    final screen = MediaQuery.sizeOf(context);
    // Full screen: the box is the whole screen; the page itself fits or
    // fills the picture inside it (see _fillsScreen).
    final ratio = widget.compact
        ? 21 / 9
        : _fullScreen
            ? screen.width / screen.height
            : (seen != null && seen >= 0.5 && seen <= 2.6 ? seen : 16 / 9);
    // Same widgets around the page either way (only the strip comes and
    // goes after it), so turning the phone never moves the page and makes
    // it load again.
    if (widget.fillHeight) return webview;
    return FitVideoBox(aspectRatio: ratio, child: webview);
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
