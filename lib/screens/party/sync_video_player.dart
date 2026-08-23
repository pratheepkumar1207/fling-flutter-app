import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
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
///
/// Built on youtube_player_iframe (webview_flutter), not youtube_player_flutter
/// (flutter_inappwebview) — see pubspec.yaml's comment on that dependency
/// for why: the older package's own internal plugin code force-paused the
/// video on every app-background event regardless of anything this file
/// did, which was the root cause of a whole family of background/PIP
/// playback glitches. This package has no such behavior, so this file no
/// longer needs to fight it.
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
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _videoStateSub;
  PlayerState _playerState = PlayerState.unknown;
  Duration _duration = Duration.zero;
  // Separate ValueNotifier (not setState) for position specifically — this
  // updates several times a second while playing, and funneling it through
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
  // Android suspends this WebView (and its video element) while the app is
  // backgrounded or the screen is locked — that silently flips isPlaying to
  // false with no real intent behind it. Without this guard,
  // _onValueChanged would read that as the host actually pausing and
  // broadcast it, freezing the video for every other participant just
  // because the host's screen locked.
  bool _backgrounded = false;
  // Set alongside _backgrounded whenever PIP is involved on *either* side
  // of the current paused/inactive/hidden dip — entering PIP (isInPip is
  // usually still false at the very start, catching up moments later) or
  // leaving it (isInPip has already flipped back to false again by the
  // time resumed fires) both need this, since checking isInPip only at the
  // resumed instant misses whichever end hadn't updated yet. True
  // background never touches PIP at all, so this only ever suppresses the
  // resync for a PIP-involved dip — PIP never actually loses playback here
  // (unlike the old youtube_player_flutter-based version), but a spurious
  // resync would still needlessly re-seek an already-fine, already-playing
  // video, which is its own visible glitch.
  bool _pipInvolvedInCurrentDip = false;
  // Shows a "catching up" banner right after returning from a real
  // background, instead of the video just looking frozen/broken while the
  // resync round trip is in flight (see didChangeAppLifecycleState /
  // _applyRemotePlaybackIfNeeded).
  bool _justResumed = false;
  Timer? _justResumedFallback;

  bool get _isPlaying => _playerState == PlayerState.playing;

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
    _valueSub?.cancel();
    _videoStateSub?.cancel();
    _controller?.close();
    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        mute: false,
        // Our own overlay (RoomPlayPauseButton/RoomSkipButton/seek bar) is
        // a separate Flutter layer painted on top — the raw WebView surface
        // underneath doesn't need to react to touches itself, and not
        // reacting avoids YouTube's own native double-tap-to-seek/drag
        // gestures fighting our custom controls.
        pointerEvents: PointerEvents.none,
      ),
    );
    _controller = controller;
    controller.setVolume(_volume);
    _playerState = PlayerState.unknown;
    _duration = Duration.zero;
    _positionNotifier.value = Duration.zero;
    _lastReportedIsPlaying = false;
    _valueSub = controller.listen(_onValueChanged);
    _videoStateSub = controller.videoStateStream.listen(
      (s) => _positionNotifier.value = s.position,
    );
  }

  void _handleVolumeChange(int next) {
    final clamped = next.clamp(0, 100);
    setState(() => _volume = clamped);
    _controller?.setVolume(clamped);
  }

  void _onValueChanged(YoutubePlayerValue value) {
    final stateChanged = value.playerState != _playerState;
    final durationChanged = value.metaData.duration != _duration;
    if (stateChanged || durationChanged) {
      setState(() {
        _playerState = value.playerState;
        _duration = value.metaData.duration;
      });
    }
    if (value.playerState == PlayerState.ended) widget.onEnded();

    // The host is the source of truth for playback state, but this
    // WebView-backed YouTube embed doesn't always route play/pause through
    // our own tap handler — e.g. the user could use YouTube's own keyboard
    // shortcuts on some platforms. Relying solely on the explicit tap emit
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
    final isPlaying = value.playerState == PlayerState.playing;
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
    if (p == null || c == null) return;
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
    // No isReady guard needed here (unlike the old youtube_player_flutter-
    // based version) — youtube_player_iframe's own seekTo/playVideo/
    // pauseVideo internally await the player's ready signal before running,
    // so a call made before the WebView finishes loading is queued, not
    // silently dropped.
    c.seekTo(seconds: position, allowSeekAhead: true);
    if (p['isPlaying'] == true) {
      c.playVideo();
    } else {
      c.pauseVideo();
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
        if (!_backgrounded) {
          // Only reset at the *start* of a new dip — AppLifecycleState can
          // report paused/inactive/hidden more than once in a row for the
          // same underlying dip, and resetting on every one of those would
          // throw away a PIP flag _onPipChanged already caught.
          _pipInvolvedInCurrentDip = PipService.isInPip.value;
        }
        _backgrounded = true;
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        if (_pipInvolvedInCurrentDip || PipService.isInPip.value) {
          // PIP was involved somewhere in this dip — either entering it or
          // leaving it. Nothing was ever actually backgrounded here — this
          // package doesn't auto-pause the way youtube_player_flutter did,
          // so the video kept playing the whole time — so skip the full
          // just-resumed resync below entirely; running it anyway re-seeks
          // an already-fine, already-playing video for no reason.
          _backgrounded = false;
          _pipInvolvedInCurrentDip = false;
          return;
        }
        // Deliberately NOT cleared here — stays true (suppressing
        // _onValueChanged's host-only auto-emit) until the corrected resync
        // actually lands in _applyRemotePlaybackIfNeeded. Confirmed live
        // with the old package that a returning host's video could
        // otherwise broadcast a stale, non-corrected position as the
        // room's real state before the resync arrived; kept here as a
        // still-useful guard even though this package doesn't auto-resume
        // on its own the same way.
        setState(() => _justResumed = true);
        _justResumedFallback?.cancel();
        // In case the server never answers (dropped connection etc.) —
        // don't leave the banner, or the guard above, stuck forever.
        _justResumedFallback = Timer(const Duration(seconds: 6), () {
          _backgrounded = false;
          _clearJustResumed();
        });
        // Whatever position drifted while genuinely backgrounded (e.g. a
        // long screen-off stretch) is untrustworthy for host or viewer
        // alike — ask the room for its real, elapsed-time-corrected
        // position instead of trusting local state.
        widget.onRequestState();
      case AppLifecycleState.detached:
        break;
    }
  }

  double get _positionSeconds => _positionNotifier.value.inMilliseconds / 1000;

  // Just toggles the local controller — _onValueChanged picks up the
  // resulting isPlaying change and emits it, so this doesn't also emit
  // directly (that would double-report the same transition).
  void _handleTap() {
    if (!widget.isHost || _controller == null) return;
    if (_isPlaying) {
      _controller!.pauseVideo();
    } else {
      _controller!.playVideo();
    }
  }

  void _handleSeekChanged(double v) {
    setState(() {
      _dragging = true;
      _dragPosition = v;
    });
  }

  void _handleSeekEnd(double v) {
    _controller?.seekTo(seconds: v, allowSeekAhead: true);
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
        child: IgnorePointer(
          child: YoutubePlayer(
            controller: controller,
            enableFullScreenOnVerticalDrag: false,
          ),
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
              controller: controller,
              enableFullScreenOnVerticalDrag: false,
            ),
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
              child: GestureDetector(
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
    _valueSub?.cancel();
    _videoStateSub?.cancel();
    _positionNotifier.dispose();
    _controller?.close();
    super.dispose();
  }
}
