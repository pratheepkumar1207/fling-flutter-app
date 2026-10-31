import '../../theme/insync_icons.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/drm_support.dart';
import '../../core/mobile_webview_settings.dart';
import '../../theme/app_colors.dart';
import 'ott_sync_engine.dart';
import 'ott_sync_panel.dart';
import '../../core/ott_remote.dart';
import '../../theme/room_themes.dart';

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
  });

  @override
  State<WebviewRoomPlayer> createState() => _WebviewRoomPlayerState();
}

class _WebviewRoomPlayerState extends State<WebviewRoomPlayer> {
  InAppWebViewController? _controller;
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

  void _moveToApp(String why) {
    debugPrint('OTT: moving to the app: $why');
    if (mounted && !_useApp) setState(() => _useApp = true);
  }

  @override
  void initState() {
    super.initState();
    // Same as the YouTube/Drive players — ask the room for the current
    // state on join so a late joiner's elapsed-time estimate starts
    // correct instead of at zero.
    if (!widget.isHost) widget.onRequestState();
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

  // Asks the page's own <video> element to go fullscreen, so the site's
  // surrounding chrome (nav bar, recommendations, search UI — whatever page
  // the room's URL happens to be) visually disappears and only the video
  // itself is left on screen. NOT guaranteed to work: browsers generally
  // require the Fullscreen API to be triggered by a genuine on-page user
  // gesture, and a script injected from Flutter isn't always treated as
  // one — this is the best available attempt without DRM-level access to
  // the video itself, but confirm on a real device before relying on it.
  Future<void> _requestFullscreen() async {
    await _controller?.evaluateJavascript(source: '''
      (function() {
        var v = document.querySelector('video');
        if (v && v.requestFullscreen) { v.requestFullscreen(); }
        else if (v && v.webkitRequestFullscreen) { v.webkitRequestFullscreen(); }
      })();
    ''');
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
        var props = {
          position: 'fixed', top: '0', left: '0',
          width: '100vw', height: '100vh',
          'object-fit': 'contain', background: '#000',
          'z-index': '2147483647',
        };
        Object.keys(props).forEach(function(k) {
          main.style.setProperty(k, props[k], 'important');
        });
        if (!document.getElementById('__fling_fullbleed_body__')) {
          var style = document.createElement('style');
          style.id = '__fling_fullbleed_body__';
          style.innerHTML = `html, body { overflow: hidden !important; margin: 0 !important; padding: 0 !important; }`;
          document.head.appendChild(style);
        }
        return true;
      })();
    ''';
    var attempt = 0;
    Timer.periodic(const Duration(milliseconds: 600), (timer) async {
      attempt++;
      // Stops first if the page has gone: its controller can't answer now.
      if (attempt >= 8 || !mounted || _appOnly) timer.cancel();
      if (!mounted || _appOnly) return;
      try {
        final found = await _controller?.evaluateJavascript(source: script);
        if (found == true) timer.cancel();
      } catch (_) {
        timer.cancel();
      }
    });
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

  bool get _isOtt => _drmPlatform == 'Netflix' || _drmPlatform == 'Prime Video';

  // In app mode the page isn't shown; the platform's own app plays instead.
  bool get _appOnly => _isOtt && _useApp;

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
      _judgeWebTry(sync.local);
      if (_useApp) return;
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
    if (_useApp) {
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
  Widget _controlStrip() {
    final elapsed = _dragPosition ?? _elapsedSeconds;
    final duration = _durationSec;
    final max =
        duration != null && duration > elapsed ? duration : _maxDragSeconds;
    const timeStyle = TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontFeatures: [FontFeature.tabularFigures()]);
    Widget icon(InIconData i, String label, VoidCallback onTap,
            {double size = 24}) =>
        Semantics(
          button: true,
          label: label,
          child: InkResponse(
            onTap: onTap,
            radius: size,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InIcon(i, color: Colors.white, size: size),
            ),
          ),
        );
    final skip = widget.isHost && widget.onSkip != null
        ? icon(InIcons.skipNext, 'Next in queue', widget.onSkip!, size: 20)
        : (!widget.isHost && widget.onVoteSkip != null)
            ? GestureDetector(
                onTap: widget.onVoteSkip,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const InIcon(InIcons.skipNext, color: Colors.white, size: 18),
                  const SizedBox(width: 3),
                  Text('${widget.skipVoteCount}/${widget.skipVoteRequired}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              )
            : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
      color: Colors.black54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_formatTime(elapsed), style: timeStyle),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: widget.isHost ? 5 : 0,
                        disabledThumbRadius: 0),
                    overlayShape: SliderComponentShape.noOverlay,
                    disabledActiveTrackColor: RoomTheme.of(context).primary,
                    disabledInactiveTrackColor: Colors.white24,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Slider(
                      value: elapsed.clamp(0, max),
                      max: max,
                      activeColor: RoomTheme.of(context).primary,
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
              ),
              Text(duration != null ? _formatTime(duration) : '--:--',
                  style: timeStyle),
            ],
          ),
          SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isHost)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onSeek != null)
                        icon(InIcons.back10, 'Back 10 seconds',
                            () => _hostSeekTo(_elapsedSeconds - 10)),
                      icon(
                          _isPlaying ? InIcons.pause : InIcons.play,
                          _isPlaying
                              ? 'Pause for everyone'
                              : 'Play for everyone',
                          _hostTogglePlay,
                          size: 32),
                      if (widget.onSeek != null)
                        icon(InIcons.forward10, 'Forward 10 seconds',
                            () => _hostSeekTo(_elapsedSeconds + 10)),
                    ],
                  ),
                if (skip != null)
                  Align(alignment: Alignment.centerRight, child: skip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Web mode: a small status pill over the video, and the way out to the
  // platform's app.
  Widget _webSyncChip() {
    final label = _drmPlatform ?? 'the app';
    final inSync =
        widget.ottStatuses.values.where((e) => e['status'] == 'in_sync').length;
    final text = widget.isHost
        ? (widget.ottStatuses.isEmpty
            ? 'You’re driving'
            : '$inSync of ${widget.ottStatuses.length} in sync')
        : switch (_webStatus) {
            _ when !_webPlayed => 'Checking if $label plays here…',
            'in_sync' => 'In sync',
            'behind' ||
            'ahead' =>
              '${(_webSync?.offset.abs() ?? 0).round()}s $_webStatus · fixing',
            _ => 'Press play to start',
          };
    Widget pill(String s, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999)),
            child: Text(s,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: pill(
              text,
              widget.isHost
                  ? () => showOttPeople(context, widget.ottStatuses, label)
                  : () {}),
        ),
        if (OttRemote.supported) ...[
          const SizedBox(width: 6),
          Flexible(
              child:
                  pill('Use $label app', () => setState(() => _useApp = true))),
        ],
      ],
    );
  }

  @override
  void dispose() {
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
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(url)),
            // Netflix sends a phone browser to its app, so its player tries
            // desktop view. It has answered that with error M7701-1003 before;
            // if it still does, the error check below moves the room to the
            // app. Everything else stays on the mobile settings.
            initialSettings: _drmPlatform == 'Netflix'
                ? desktopPlayerWebViewSettings
                : mobileWebViewSettings,
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
        if (!_appOnly)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _requestFullscreen,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle),
                child: const InIcon(InIcons.fullscreen,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        // Compact so it fits the 16:9 box above the room's own control
        // strip, which covers the bottom ~90px of this player.
        if (_isOtt && !_useApp && !_onLoginPage)
          Positioned(
              top: 8,
              left: 8,
              right: 52,
              child: Align(
                  alignment: Alignment.centerLeft, child: _webSyncChip())),
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
        if (_onLoginPage)
          Positioned(
            top: 8,
            left: 8,
            right: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text(
                'Log in here, then come back to catch up with the room.',
                style: TextStyle(color: Colors.white, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        Positioned(left: 0, right: 0, bottom: 0, child: _controlStrip()),
      ],
    ));
    return widget.fillHeight
        ? SizedBox.expand(child: webview)
        : AspectRatio(
            aspectRatio: widget.compact ? 21 / 9 : 16 / 9, child: webview);
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
      return JSON.stringify({playing: !v.paused, pos: pos, dur: isFinite(dur) ? dur : 0, canSeek: true});
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
    );
  }

  @override
  Future<void> play() => _run('window.__insync.play()');
  @override
  Future<void> pause() => _run('window.__insync.pause()');
  @override
  Future<void> seekTo(double seconds) => _run('window.__insync.seek($seconds)');
}
