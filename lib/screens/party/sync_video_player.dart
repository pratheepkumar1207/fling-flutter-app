import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
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
/// state => apply) are driven explicitly by us here, so — unlike the web
/// app's IFrame-API version, which had to infer intent from onStateChange
/// and hit a stale-closure bug doing it — there's no ambiguous callback to
/// misread: we only emit on the paths we call ourselves.
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
  YoutubePlayerController? _controller;
  String? _currentVideoId;
  num? _lastAppliedUpdatedAt;
  bool _dragging = false;
  double _dragPosition = 0;
  int _volume = 80;
  bool _volumePopoverOpen = false;
  bool? _lastReportedIsPlaying;
  // Tracks controller.value.isReady transitions — see _onControllerStateChanged.
  bool _lastReadyState = false;
  // Android suspends the WebView (and its video element) while the app is
  // backgrounded or the screen is locked — that silently flips isPlaying to
  // false with no real intent behind it. Without this guard,
  // _onControllerStateChanged would read that as the host actually pausing
  // and broadcast it, freezing the video for every other participant just
  // because the host's screen locked (confirmed live).
  bool _backgrounded = false;
  // Set alongside _backgrounded whenever PIP is involved on *either* side
  // of the current paused/inactive/hidden dip — entering PIP (isInPip is
  // usually still false at the very start, catching up moments later) or
  // leaving it (isInPip has already flipped back to false again by the
  // time resumed fires, well before this dip is over) both need this,
  // since checking isInPip only at the resumed instant misses whichever
  // end hadn't updated yet. True background never touches PIP at all, so
  // this only ever suppresses the resync for a PIP-involved dip.
  bool _pipInvolvedInCurrentDip = false;
  // Shows a "catching up" banner right after returning from background,
  // instead of the video just looking frozen/broken while the resync round
  // trip is in flight (see didChangeAppLifecycleState / _applyRemotePlaybackIfNeeded).
  bool _justResumed = false;
  Timer? _justResumedFallback;
  // Counteracts youtube_player_flutter's own internal WidgetsBindingObserver
  // (see raw_youtube_player.dart), which explicitly calls player.pauseVideo()
  // on every AppLifecycleState.paused — a battery-saving default baked into
  // the plugin, not something Android itself forces. Re-asserting play()
  // periodically while backgrounded fights that so audio keeps going
  // instead of cutting out the moment the screen locks/app backgrounds.
  // EXPERIMENTAL: whether the underlying WebView's audio track actually
  // keeps producing sound once the Activity itself isn't visible hasn't
  // been confirmed on a real device — this assumes it does as long as the
  // process stays alive (which RoomPresenceService's foreground service
  // already guarantees) and nothing explicitly re-pauses it.
  Timer? _backgroundKeepAliveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PipService.isInPip.addListener(_onPipChanged);
    _rebuildControllerIfNeeded();
    // playback:state can arrive (and update RoomSocketController.playback)
    // before this widget's very first build — e.g. the server already
    // sends it proactively on room:join, often within the same event-loop
    // tick as the join itself. That means widget.playback can already be
    // non-null right here, but didUpdateWidget (below) never fires for a
    // first build, so without this call the initial state would silently
    // never get applied and a joining viewer would just sit at 0:00
    // forever instead of landing wherever the host actually is.
    _applyRemotePlaybackIfNeeded();
    if (!widget.isHost) widget.onRequestState();
  }

  @override
  void didUpdateWidget(covariant SyncVideoPlayer old) {
    super.didUpdateWidget(old);
    _rebuildControllerIfNeeded();
    _applyRemotePlaybackIfNeeded();
  }

  void _rebuildControllerIfNeeded() {
    final videoId = extractYouTubeId(widget.videoUrl);
    if (videoId == null || videoId == _currentVideoId) return;
    _currentVideoId = videoId;
    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: true,
          disableDragSeek: true,
          enableCaption: false),
    )
      ..addListener(_onControllerStateChanged)
      ..setVolume(_volume);
    _lastReportedIsPlaying = false;
  }

  void _handleVolumeChange(int next) {
    final clamped = next.clamp(0, 100);
    setState(() => _volume = clamped);
    _controller?.setVolume(clamped);
  }

  void _onControllerStateChanged() {
    final c = _controller;
    if (c == null) return;
    if (c.value.playerState == PlayerState.ended) widget.onEnded();

    // A brand-new controller (new video — pinned, auto-advanced, or just
    // selected) isn't ready to accept seek/play/pause the instant it's
    // created; commands sent before the underlying WebView player reports
    // ready get silently dropped. _applyRemotePlaybackIfNeeded's isReady
    // guard skips applying until this fires true — retry here once it
    // does, since nothing else would otherwise re-trigger that apply.
    // Confirmed live: this is why a pinned song loaded but stayed paused —
    // the real play command was sent too early and just got lost.
    if (c.value.isReady && !_lastReadyState) {
      _lastReadyState = true;
      _applyRemotePlaybackIfNeeded();
    } else if (!c.value.isReady) {
      _lastReadyState = false;
    }

    // The host is the source of truth for playback state, but this
    // WebView-backed YouTube embed doesn't always route play/pause through
    // our own tap handler — e.g. it can resume on its own after the app
    // returns from background. Relying solely on the explicit tap emit
    // left the server's playbackStates never updated for those cases, so
    // any viewer requesting state on join got nothing back and stayed
    // frozen at 0:00 instead of landing wherever the host actually is.
    // Mirroring the controller's real isPlaying here (host-only, deduped
    // against the last value we reported) makes the emitted state match
    // reality regardless of what triggered the change.
    if (!widget.isHost) return;
    // Don't trust isPlaying while backgrounded — see _backgrounded's doc.
    // didChangeAppLifecycleState re-syncs for real once we're back.
    if (_backgrounded) return;
    final isPlaying = c.value.isPlaying;
    if (isPlaying == _lastReportedIsPlaying) return;
    _lastReportedIsPlaying = isPlaying;
    if (isPlaying) {
      widget.onPlay(_positionSeconds);
    } else {
      widget.onPause(_positionSeconds);
    }
  }

  void _applyRemotePlaybackIfNeeded() {
    final p = widget.playback;
    final c = _controller;
    // Mirrors drive_video_player.dart's isInitialized guard — a fresh
    // controller can't reliably accept seek/play/pause before the
    // underlying WebView player reports ready (see _onControllerStateChanged,
    // which retries this once it does). Deliberately NOT marking
    // _lastAppliedUpdatedAt below when this bails early, so the retry
    // doesn't get swallowed by the dedup check once the player is ready.
    if (p == null || c == null || !c.value.isReady) return;
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
    c.seekTo(Duration(milliseconds: (position * 1000).round()));
    if (p['isPlaying'] == true) {
      c.play();
    } else {
      c.pause();
    }
    // A genuinely new state just landed — if this was the resync we asked
    // for on resume, it's now safe to stop suppressing locally-driven state
    // changes (see didChangeAppLifecycleState's _backgrounded guard) and
    // clear the catch-up banner.
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
        // NOT skipped for PIP (unlike the resumed-side check below) —
        // youtube_player_flutter's own internal WidgetsBindingObserver
        // (raw_youtube_player.dart) has no concept of PIP at all and
        // unconditionally calls pause() on this exact same dip regardless
        // of whether we're entering PIP or genuinely backgrounding. Only
        // fighting that via _startBackgroundKeepAlive for a real
        // background (skipping it during PIP, as this used to) left
        // nothing to counteract the plugin's own PIP-triggered pause,
        // which is what the reported PIP pause/resume glitch actually was.
        if (!_backgrounded) {
          // Only reset at the *start* of a new dip — AppLifecycleState can
          // report paused/inactive/hidden more than once in a row for the
          // same underlying dip, and resetting on every one of those would
          // throw away a PIP flag _onPipChanged already caught.
          _pipInvolvedInCurrentDip = PipService.isInPip.value;
        }
        _backgrounded = true;
        _startBackgroundKeepAlive();
      case AppLifecycleState.resumed:
        _backgroundKeepAliveTimer?.cancel();
        _backgroundKeepAliveTimer = null;
        if (!_backgrounded) return;
        if (_pipInvolvedInCurrentDip || PipService.isInPip.value) {
          // PIP was involved somewhere in this dip — either entering it
          // (isInPip was still false at the very start, caught moments
          // later by _onPipChanged) or leaving it (isInPip has already
          // flipped back to false again by the time resumed fires, well
          // before this dip is considered over). Either way nothing was
          // ever actually backgrounded — the video kept playing the whole
          // time — so skip the full just-resumed resync below entirely;
          // running it anyway re-seeks an already-fine, already-playing
          // video for no reason, which is what showed up as a ~1s
          // pause/play glitch on every PIP transition, both directions.
          _backgrounded = false;
          _pipInvolvedInCurrentDip = false;
          return;
        }
        // Deliberately NOT cleared here — stays true (suppressing
        // _onControllerStateChanged's host-only auto-emit) until the
        // corrected resync actually lands in _applyRemotePlaybackIfNeeded.
        // The WebView's YouTube embed can resume playback on its own as
        // soon as the app foregrounds, before that resync arrives; without
        // this, that auto-resume fired _onControllerStateChanged with
        // wherever the video had been paused locally (not elapsed-time
        // corrected) and broadcast that stale position as the room's real
        // state — confirmed live: this is why a returning host's video
        // wasn't resuming from where the room actually was.
        setState(() => _justResumed = true);
        _justResumedFallback?.cancel();
        // In case the server never answers (dropped connection etc.) —
        // don't leave the banner, or the guard above, stuck forever.
        _justResumedFallback = Timer(const Duration(seconds: 6), () {
          _backgrounded = false;
          _clearJustResumed();
        });
        // Whatever the WebView's player drifted to while suspended is
        // untrustworthy for host or viewer alike — ask the room for its
        // real, elapsed-time-corrected position instead of trusting local
        // state (or, for the host, silently resuming from a stale spot).
        widget.onRequestState();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _startBackgroundKeepAlive() {
    final c = _controller;
    // Read isPlaying now, before youtube_player_flutter's own observer
    // (registered on a State deeper in the tree, so it fires after ours for
    // the same lifecycle event) gets a chance to call pause() itself.
    if (c == null || !c.value.isPlaying) return;
    _backgroundKeepAliveTimer?.cancel();
    // A quick first re-assert shortly after the plugin's own pause() call
    // (issued moments after this, later in the same lifecycle dispatch)
    // has had time to actually reach the WebView, then keep re-asserting
    // periodically in case Android's own throttling kicks in later. play()
    // on an already-playing video is a no-op in the YouTube IFrame API
    // (doesn't restart/seek), so this is safe to call repeatedly.
    _backgroundKeepAliveTimer =
        Timer.periodic(const Duration(milliseconds: 800), (_) {
      _controller?.play();
    });
  }

  double get _positionSeconds =>
      (_controller?.value.position.inMilliseconds ?? 0) / 1000;

  // Just toggles the local controller — _onControllerStateChanged picks up
  // the resulting isPlaying change and emits it, so this doesn't also emit
  // directly (that would double-report the same transition).
  void _handleTap() {
    if (!widget.isHost || _controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _handleSeekChanged(double v) {
    setState(() {
      _dragging = true;
      _dragPosition = v;
    });
  }

  void _handleSeekEnd(double v) {
    _controller?.seekTo(Duration(milliseconds: (v * 1000).round()));
    widget.onSeek(v);
    setState(() => _dragging = false);
  }

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
            color: AppColors.surface2,
            alignment: Alignment.center,
            child: const Text('No video',
                style: TextStyle(color: AppColors.textFaint))),
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
        child: IgnorePointer(
          child: YoutubePlayer(
              controller: controller, showVideoProgressIndicator: false),
        ),
      );
    }

    final audioOnly = widget.mediaMode == 'audio';

    // The YoutubePlayer widget stays mounted at a real (if tiny) size either
    // way — it's what's actually producing the audio, and WebView-backed
    // players commonly suspend playback if shrunk to a literal zero size or
    // taken fully offstage. In audio-only mode it's just shrunk to 1x1 and
    // hidden behind the Static Bloom card instead.
    // No rounded-corner card/box — the video now runs edge-to-edge at full
    // screen width right under the header, so a "boxed" look doesn't apply.
    final videoTree = AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            YoutubePlayer(
                controller: controller, showVideoProgressIndicator: false),
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
                        forward: false, onTap: widget.onSkipPrevious),
                    const SizedBox(width: 20),
                    ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (context, value, _) => RoomPlayPauseButton(
                          playing: value.isPlaying, onTap: _handleTap),
                    ),
                    const SizedBox(width: 20),
                    RoomSkipButton(forward: true, onTap: widget.onSkip),
                  ],
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
                          shape: BoxShape.circle),
                      child: const Icon(Icons.picture_in_picture_alt_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  if (_justResumed)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 8),
                              Text('Catching up…',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
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
              child: GestureDetector(
                onTap: widget.onToggleLike,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle),
                  child: Text(widget.liked ? '❤️' : '🤍',
                      style: const TextStyle(fontSize: 16)),
                ),
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
                      borderRadius: BorderRadius.circular(16)),
                  child: VolumeDots(
                      volume: _volume,
                      onVolumeChange: _handleVolumeChange,
                      trackColor: Colors.white24),
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
                      Colors.transparent
                    ])),
                child: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final duration =
                        value.metaData.duration.inSeconds.toDouble();
                    final position = _dragging
                        ? _dragPosition
                        : value.position.inSeconds.toDouble();
                    return Row(
                      children: [
                        Text(_formatTime(position),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6)),
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
                        Text(_formatTime(duration),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                        IconButton(
                          onPressed: () => setState(
                              () => _volumePopoverOpen = !_volumePopoverOpen),
                          icon: Icon(
                              _volume == 0
                                  ? Icons.volume_off
                                  : (_volume < 50
                                      ? Icons.volume_down
                                      : Icons.volume_up),
                              color: Colors.white,
                              size: 18),
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
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.metaData.duration.inSeconds.toDouble();
        final position =
            _dragging ? _dragPosition : value.position.inSeconds.toDouble();
        return Stack(
          children: [
            SizedBox(
                width: 100,
                height: 100,
                child: IgnorePointer(child: videoTree)),
            StaticBloomPlayer(
              playing: value.isPlaying,
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
    _backgroundKeepAliveTimer?.cancel();
    _controller?.removeListener(_onControllerStateChanged);
    _controller?.dispose();
    super.dispose();
  }
}
