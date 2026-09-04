import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/pip_service.dart';
import '../../core/youtube_util.dart';
import '../../theme/app_colors.dart';
import '../../widgets/room_play_pause_button.dart';
import '../../widgets/room_skip_button.dart';
import '../../widgets/static_bloom_player.dart';
import '../../widgets/volume_dots.dart';

/// Host-controlled real-time-synced YouTube player. Both the local-action
/// path (tap/drag => emit) and the remote-sync path (incoming playback
/// state => apply) are driven explicitly by us here, so there's no
/// ambiguous callback to misread: we only emit on the paths we call
/// ourselves.
///
/// Built directly on flutter_inappwebview (already a dependency, already
/// proven working for the Netflix/Prime "browse together" rooms — see
/// webview_room_player.dart), navigating to this app's own backend-hosted
/// /youtube-embed.html (see embedPlayer.js) instead of using a Flutter
/// YouTube-player package. Both youtube_player_flutter and
/// youtube_player_iframe load their player HTML via loadHtmlString with a
/// spoofed baseUrl claiming to be https://www.youtube.com, to sneak past
/// the embed's same-origin check — that trick started failing outright
/// ("Video unavailable") across both packages, almost certainly because
/// YouTube tightened origin validation against exactly this kind of
/// spoofing. The backend route serves the real thing from a real HTTPS
/// origin, so there's no origin to spoof, and no package-internal
/// auto-pause-on-background behavior to fight either — the JS on that page
/// is ours, and it does nothing on its own in response to lifecycle
/// changes.
class SyncVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final bool isHost;
  final Map<String, dynamic>? playback;
  final String mediaMode;
  final String? title;
  final String? thumbnail;
  final void Function(double position) onPlay;
  final void Function(double position) onPause;
  final void Function(double position) onSeek;
  final VoidCallback onRequestState;
  final VoidCallback onEnded;
  final VoidCallback onSkip;
  final VoidCallback? onSkipPrevious;
  // Non-host "vote to skip the current song" — see room_socket_controller
  // .dart's skipVote/voteSkip. isHost gets the always-immediate onSkip
  // above instead; this row is what everyone else taps.
  final VoidCallback? onVoteSkip;
  final int skipVoteCount;
  final int skipVoteRequired;
  final bool liked;
  final VoidCallback onToggleLike;
  final bool compact;
  // True for the hidden background-continuity instance (see
  // persistent_room_audio.dart) — renders no UI/chrome at all (no skip
  // buttons, seek bar, like icon, PIP button), just the bare WebView at a
  // real but off-screen-effectively size. Always paired with isHost:false
  // by that caller, so this never doubles as a second source of host
  // play/pause/seek emissions.
  final bool silent;

  const SyncVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isHost,
    required this.playback,
    this.mediaMode = 'video',
    this.title,
    this.thumbnail,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onRequestState,
    required this.onEnded,
    required this.onSkip,
    this.onSkipPrevious,
    this.onVoteSkip,
    this.skipVoteCount = 0,
    this.skipVoteRequired = 1,
    required this.liked,
    required this.onToggleLike,
    this.compact = false,
    this.silent = false,
  });

  @override
  State<SyncVideoPlayer> createState() => _SyncVideoPlayerState();
}

class _SyncVideoPlayerState extends State<SyncVideoPlayer>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  String? _currentVideoId;
  bool _ready = false;
  // Raw YouTube IFrame API state codes: -1 unstarted, 0 ended, 1 playing,
  // 2 paused, 3 buffering, 5 cued. Null until the page's own onStateChange
  // fires for the first time.
  int? _stateCode;
  Duration _duration = Duration.zero;
  // Separate ValueNotifier (not setState) for position — the embed page
  // ticks this every 500ms while playing, and funneling it through
  // setState would rebuild the entire player tree (including the WebView
  // platform view) that often for no reason. Only the seek bar / bloom
  // player slider actually need it, via a scoped ValueListenableBuilder.
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );
  num? _lastAppliedUpdatedAt;
  bool _dragging = false;
  double _dragPosition = 0;
  int _volume = 80;
  bool _volumePopoverOpen = false;
  bool? _lastReportedIsPlaying;
  // True while genuinely backgrounded/screen-off — suppresses
  // _onYtEvent's host-only auto-emit so Android suspending the WebView
  // (a real possibility on a long screen-off stretch, independent of
  // anything this file does) doesn't broadcast a fake pause to the room.
  bool _backgrounded = false;
  // Set alongside _backgrounded whenever PIP is involved on *either* side
  // of the current paused/inactive/hidden dip — entering PIP (isInPip is
  // usually still false at the very start, catching up moments later) or
  // leaving it (isInPip has already flipped back to false again by the
  // time resumed fires) both need this, since checking isInPip only at the
  // resumed instant misses whichever end hadn't updated yet.
  bool _pipInvolvedInCurrentDip = false;
  // Shows a "catching up" banner right after returning from a real
  // background, instead of the video just looking frozen/broken while the
  // resync round trip is in flight.
  bool _justResumed = false;
  Timer? _justResumedFallback;

  bool get _isPlaying => _stateCode == 1;

  // Defaults to the usual 16:9 box and only changes once the real size
  // comes back (or stays put if the lookup fails) — see _loadAspectRatio.
  double _aspectRatio = 16 / 9;

  String _embedUrl(String videoId) =>
      '${ApiClient.baseUrl}/youtube-embed.html?v=$videoId';

  // The IFrame API has no way to report the video's real pixel dimensions
  // (the actual <video> lives inside a cross-origin youtube.com iframe, out
  // of reach of this page's own JS) — GET /youtube/embed-size asks the
  // backend to look it up via YouTube's oEmbed endpoint instead. Guarded by
  // videoId so a slow response for a video the user has since skipped past
  // doesn't clobber the aspect ratio of whatever's playing now.
  Future<void> _loadAspectRatio(String videoId) async {
    try {
      final data = await ApiClient.get('/youtube/embed-size?v=$videoId') as Map;
      final width = (data['width'] as num?)?.toDouble();
      final height = (data['height'] as num?)?.toDouble();
      if (!mounted || videoId != _currentVideoId) return;
      if (width != null && height != null && width > 0 && height > 0) {
        setState(() => _aspectRatio = width / height);
      }
    } catch (_) {
      // Best-effort — stays on the current (default 16:9) ratio.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PipService.isInPip.addListener(_onPipChanged);
    _currentVideoId = extractYouTubeId(widget.videoUrl);
    if (_currentVideoId != null) _loadAspectRatio(_currentVideoId!);
    if (!widget.isHost) widget.onRequestState();
  }

  @override
  void didUpdateWidget(covariant SyncVideoPlayer old) {
    super.didUpdateWidget(old);
    final videoId = extractYouTubeId(widget.videoUrl);
    if (videoId != null && videoId != _currentVideoId) {
      _currentVideoId = videoId;
      _ready = false;
      _stateCode = null;
      _duration = Duration.zero;
      _positionNotifier.value = Duration.zero;
      _lastReportedIsPlaying = null;
      _lastAppliedUpdatedAt = null;
      _aspectRatio = 16 / 9;
      _loadAspectRatio(videoId);
      _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_embedUrl(videoId))),
      );
    }
    _applyRemotePlaybackIfNeeded();
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'ytEvent',
      callback: (args) {
        if (args.isEmpty) return;
        try {
          final msg = jsonDecode(args.first as String) as Map<String, dynamic>;
          _onYtEvent(
            msg['type'] as String?,
            (msg['data'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
        } catch (_) {}
      },
    );
  }

  void _onYtEvent(String? type, Map<String, dynamic> data) {
    switch (type) {
      case 'Ready':
        _ready = true;
        _controller?.evaluateJavascript(source: 'ytSetVolume($_volume);');
        // Commands sent before the page reported ready (e.g. the initial
        // _applyRemotePlaybackIfNeeded call from initState) were no-ops on
        // the JS side — retry now that they'll actually land.
        _applyRemotePlaybackIfNeeded();
      case 'StateChange':
        final code = (data['state'] as num?)?.toInt();
        if (code == null) return;
        setState(() => _stateCode = code);
        if (code == 0) widget.onEnded();
        _maybeReportPlayState();
      case 'Tick':
        final t = (data['time'] as num?)?.toDouble();
        final d = (data['duration'] as num?)?.toDouble();
        if (t != null) {
          _positionNotifier.value = Duration(
            milliseconds: (t * 1000).round(),
          );
        }
        if (d != null && d > 0) {
          final newDuration = Duration(milliseconds: (d * 1000).round());
          if (newDuration != _duration) setState(() => _duration = newDuration);
        }
      case 'Error':
        // Player errors (invalid id, removed video, etc.) — nothing
        // actionable to do client-side beyond not crashing; the room stays
        // on whatever it last showed.
        break;
    }
  }

  // The host is the source of truth for playback state, but this
  // WebView-embedded YouTube player doesn't always route play/pause
  // through our own tap handler. Mirroring the real state here (host-only,
  // deduped against the last value reported) makes the emitted state match
  // reality regardless of what triggered the change.
  void _maybeReportPlayState() {
    if (!widget.isHost) return;
    // Don't trust state while backgrounded — didChangeAppLifecycleState
    // re-syncs for real once we're back.
    if (_backgrounded) return;
    final isPlaying = _isPlaying;
    if (isPlaying == _lastReportedIsPlaying) return;
    _lastReportedIsPlaying = isPlaying;
    if (isPlaying) {
      widget.onPlay(_positionSeconds);
    } else {
      widget.onPause(_positionSeconds);
    }
  }

  void _handleVolumeChange(int next) {
    final clamped = next.clamp(0, 100);
    setState(() => _volume = clamped);
    _controller?.evaluateJavascript(source: 'ytSetVolume($clamped);');
  }

  void _applyRemotePlaybackIfNeeded() {
    final p = widget.playback;
    final c = _controller;
    if (p == null || c == null || !_ready) return;
    final updatedAt = p['updatedAt'] == null ? null : asNum(p['updatedAt']);
    if (updatedAt != null && updatedAt == _lastAppliedUpdatedAt) return;
    _lastAppliedUpdatedAt = updatedAt;

    var position = asNum(p['position']).toDouble();
    // Correct for however long this event took to arrive (network latency,
    // event-loop scheduling) — mirrors the backend's own
    // getCorrectedPlaybackState so a laggier connection doesn't land
    // consistently behind everyone else's video. Only meaningful while
    // actually playing; a paused position doesn't drift.
    if (p['isPlaying'] == true && updatedAt != null) {
      final elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - updatedAt) / 1000;
      if (elapsedSeconds > 0) position += elapsedSeconds;
    }
    c.evaluateJavascript(source: 'ytSeek($position);');
    if (p['isPlaying'] == true) {
      c.evaluateJavascript(source: 'ytPlay();');
    } else {
      c.evaluateJavascript(source: 'ytPause();');
    }
    // A genuinely new state just landed — if this was the resync we asked
    // for on resume, it's now safe to stop suppressing locally-driven state
    // changes and clear the catch-up banner.
    _backgrounded = false;
    _clearJustResumed();
  }

  void _clearJustResumed() {
    if (!_justResumed) return;
    _justResumedFallback?.cancel();
    setState(() => _justResumed = false);
  }

  // Fires whenever PipService.isInPip changes, for as long as this widget
  // is mounted — not just while backgrounded — so a PIP entry that starts
  // false and flips true moments later (native onPipModeChanged's async
  // round trip) still gets caught, not just the exit direction where
  // isInPip is already true at the dip's start and flips false again
  // before resumed fires.
  void _onPipChanged() {
    if (PipService.isInPip.value) _pipInvolvedInCurrentDip = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (!_backgrounded) {
          _pipInvolvedInCurrentDip = PipService.isInPip.value;
        }
        _backgrounded = true;
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        if (_pipInvolvedInCurrentDip || PipService.isInPip.value) {
          // PIP was involved somewhere in this dip — nothing was ever
          // actually backgrounded, so skip the just-resumed resync below
          // entirely; running it anyway re-seeks an already-fine,
          // already-playing video for no reason.
          _pipInvolvedInCurrentDip = false;
          // _backgrounded stays true a bit longer, though — Chromium's own
          // WebView-level pause/resume around the PIP transition sends its
          // StateChange event to Dart asynchronously, and that message can
          // still be in flight when this handler runs. Clearing the
          // suppression guard immediately let a late-arriving "paused"
          // StateChange through _maybeReportPlayState, broadcasting it to
          // the whole room as a real pause — which then stuck, since
          // nothing ever told the room (or this page's own shouldBePlaying
          // flag) to resume again. Absorbing that window first fixes it at
          // the source instead of chasing the broadcast after the fact.
          Timer(const Duration(milliseconds: 1200), () {
            if (mounted) _backgrounded = false;
          });
          return;
        }
        setState(() => _justResumed = true);
        _justResumedFallback?.cancel();
        // In case the server never answers (dropped connection etc.) —
        // don't leave the banner, or the guard above, stuck forever.
        _justResumedFallback = Timer(const Duration(seconds: 6), () {
          _backgrounded = false;
          _clearJustResumed();
        });
        // Whatever position drifted while genuinely backgrounded (e.g. a
        // long screen-off stretch, if the WebView got suspended at the OS
        // level) is untrustworthy for host or viewer alike — ask the room
        // for its real, elapsed-time-corrected position instead of
        // trusting local state.
        widget.onRequestState();
      case AppLifecycleState.detached:
        break;
    }
  }

  double get _positionSeconds => _positionNotifier.value.inMilliseconds / 1000;

  // Same idea as webview_room_player.dart's OTT fullscreen button — see
  // ytRequestFullscreen's doc in embedPlayer.js for why this targets the
  // <iframe> itself rather than a <video> element.
  Future<void> _requestFullscreen() async {
    await _controller?.evaluateJavascript(source: 'ytRequestFullscreen();');
  }

  // Just toggles the page's player — the resulting StateChange event picks
  // up the change and emits it via _maybeReportPlayState, so this doesn't
  // also emit directly (that would double-report the same transition).
  void _handleTap() {
    if (!widget.isHost || _controller == null) return;
    _controller!
        .evaluateJavascript(source: _isPlaying ? 'ytPause();' : 'ytPlay();');
  }

  void _handleSeekChanged(double v) {
    setState(() {
      _dragging = true;
      _dragPosition = v;
    });
  }

  void _handleSeekEnd(double v) {
    _controller?.evaluateJavascript(source: 'ytSeek($v);');
    widget.onSeek(v);
    setState(() => _dragging = false);
  }

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  InAppWebView _buildWebView() {
    final videoId = _currentVideoId!;
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_embedUrl(videoId))),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: false,
        // flutter_inappwebview defaults to Hybrid Composition (a real
        // native Android View embedded directly in the view hierarchy),
        // which is known to be fragile exactly during Activity window
        // reconfiguration — precisely what a PIP transition is (a real
        // resize of the whole window, not just a visibility change). The
        // texture-based composition here should be far more resilient to
        // that, since it doesn't require re-coordinating a real embedded
        // view's position with the OS resizing the window around it. This
        // player has no text input/complex gestures into the page itself
        // (touches are blocked entirely via pointer-events:none in
        // embedPlayer.js, control is all through evaluateJavascript), so
        // none of hybrid composition's usual advantages apply here anyway.
        useHybridComposition: false,
      ),
      onWebViewCreated: _onWebViewCreated,
      // Same "don't error out on a custom app-deeplink scheme" guard as
      // webview_browse_screen.dart / webview_room_player.dart.
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final scheme = navigationAction.request.url?.scheme;
        if (scheme != null && scheme != 'http' && scheme != 'https') {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentVideoId == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppColors.surface2,
          alignment: Alignment.center,
          child: const Text(
            'No video',
            style: TextStyle(color: AppColors.textFaint),
          ),
        ),
      );
    }

    if (widget.silent) {
      // No UI at all — this instance only exists to keep producing audio
      // while off-screen. Kept at a real 100x100 size, not shrunk further
      // or made transparent, for the same reason as the audioOnly branch
      // below: WebView-backed players can silently stall once shrunk near
      // zero or fully culled.
      return SizedBox(
        width: 100,
        height: 100,
        child: IgnorePointer(child: _buildWebView()),
      );
    }

    final audioOnly = widget.mediaMode == 'audio';

    // The WebView stays mounted at a real (if tiny) size either way — it's
    // what's actually producing the audio, and WebView-backed players
    // commonly suspend playback if shrunk to a literal zero size or taken
    // fully offstage. In audio-only mode it's just shrunk to 100x100 and
    // hidden behind the Static Bloom card instead.
    // No rounded-corner card/box — the video now runs edge-to-edge at full
    // screen width right under the header, so a "boxed" look doesn't apply.
    final videoTree = AspectRatio(
      aspectRatio: _aspectRatio,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildWebView(),
            // A dedicated button row, not a whole-video tap target — tapping
            // anywhere on the video (e.g. near the seek bar) was toggling
            // playback by accident. Skip buttons flank play/pause: left
            // jumps back to the previous queue item (non-destructive —
            // reuses queue:jump, same as tapping "play" on an earlier queue
            // row), right is the existing skip-forward (removes the current
            // item and advances, same as it always has).
            if (widget.isHost)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoomSkipButton(
                      forward: false,
                      onTap: widget.onSkipPrevious,
                    ),
                    const SizedBox(width: 20),
                    RoomPlayPauseButton(playing: _isPlaying, onTap: _handleTap),
                    const SizedBox(width: 20),
                    RoomSkipButton(forward: true, onTap: widget.onSkip),
                  ],
                ),
              )
            else if (widget.onVoteSkip != null)
              Center(
                child: GestureDetector(
                  onTap: widget.onVoteSkip,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.skip_next_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Vote to skip (${widget.skipVoteCount}/${widget.skipVoteRequired})',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manual PIP trigger — auto-PIP-on-minimize has been
                  // unreliable (see PipService/MainActivity.kt), so this
                  // gives a direct, always-available way in rather than
                  // depending solely on Android detecting the app leaving.
                  GestureDetector(
                    onTap: PipService.enterPip,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.picture_in_picture_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  if (_justResumed)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Catching up…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  // Same fullscreen affordance the OTT player already has
                  // (webview_room_player.dart) — now available for YouTube
                  // too, via ytRequestFullscreen() on the embed page.
                  GestureDetector(
                    onTap: _requestFullscreen,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onToggleLike,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.liked ? '❤️' : '🤍',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_volumePopoverOpen)
              Positioned(
                right: 8,
                bottom: 64,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: VolumeDots(
                    volume: _volume,
                    onVolumeChange: _handleVolumeChange,
                    trackColor: Colors.white24,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: ValueListenableBuilder<Duration>(
                  valueListenable: _positionNotifier,
                  builder: (context, positionDuration, _) {
                    final duration = _duration.inSeconds.toDouble();
                    final position = _dragging
                        ? _dragPosition
                        : positionDuration.inSeconds.toDouble();
                    return Row(
                      children: [
                        Text(
                          _formatTime(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              value: duration > 0
                                  ? position.clamp(0, duration)
                                  : 0,
                              max: duration > 0 ? duration : 1,
                              activeColor: AppColors.primary,
                              inactiveColor: Colors.white24,
                              onChanged:
                                  widget.isHost ? _handleSeekChanged : null,
                              onChangeEnd:
                                  widget.isHost ? _handleSeekEnd : null,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _volumePopoverOpen = !_volumePopoverOpen,
                          ),
                          icon: Icon(
                            _volume == 0
                                ? Icons.volume_off
                                : (_volume < 50
                                    ? Icons.volume_down
                                    : Icons.volume_up),
                            color: Colors.white,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!audioOnly) return videoTree;

    // Kept at a modest real size (not shrunk to 1x1 / wrapped in Opacity)
    // — mobile WebViews commonly throttle or silently stall a platform
    // view's playback once it's made near-zero-size or fully transparent,
    // which was causing audio to drift out of sync after switching to
    // audio-only. 100x100 comfortably clears that threshold while staying
    // fully covered by the StaticBloomPlayer card, which sizes itself
    // naturally here rather than being force-stretched to match the
    // video's aspect ratio (that stretch previously caused a layout
    // overflow — StaticBloomPlayer's own content doesn't fit an arbitrary
    // forced height).
    return ValueListenableBuilder<Duration>(
      valueListenable: _positionNotifier,
      builder: (context, positionDuration, _) {
        final duration = _duration.inSeconds.toDouble();
        final position =
            _dragging ? _dragPosition : positionDuration.inSeconds.toDouble();
        return Stack(
          children: [
            SizedBox(
                width: 100,
                height: 100,
                child: IgnorePointer(child: videoTree)),
            StaticBloomPlayer(
              playing: _isPlaying,
              title: widget.title,
              thumbnail: widget.thumbnail,
              volume: _volume,
              onVolumeChange: _handleVolumeChange,
              onTogglePlay: widget.isHost ? _handleTap : null,
              currentTime: position,
              duration: duration,
              isHost: widget.isHost,
              onSeekChanged: _handleSeekChanged,
              onSeekEnd: _handleSeekEnd,
              compact: widget.compact,
              onSkip: widget.isHost ? widget.onSkip : null,
              onSkipPrevious: widget.isHost ? widget.onSkipPrevious : null,
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipService.isInPip.removeListener(_onPipChanged);
    _justResumedFallback?.cancel();
    _positionNotifier.dispose();
    _controller = null;
    super.dispose();
  }
}
