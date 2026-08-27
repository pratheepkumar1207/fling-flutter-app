import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/background_audio_handler.dart';
import '../../core/format.dart';
import '../../core/pip_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/room_play_pause_button.dart';
import '../../widgets/room_skip_button.dart';
import '../../widgets/spinner.dart';
import '../../widgets/static_bloom_player.dart';
import '../../widgets/volume_dots.dart';

/// Drive-sourced sibling of sync_video_player.dart's SyncVideoPlayer — same
/// constructor shape (party_screen.dart picks between the two purely by the
/// current queue item's sourceType, see _buildRoom there) and the same
/// host-emits/guest-applies sync contract, just backed by a native
/// VideoPlayerController streaming from GET /drive/stream/:fileId instead
/// of a YouTube-embedded player. `videoUrl` here is the raw Drive file id
/// (see drive_browse_screen.dart), not a URL.
class DriveVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final String roomId;
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

  const DriveVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.roomId,
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
  });

  @override
  State<DriveVideoPlayer> createState() => _DriveVideoPlayerState();
}

class _DriveVideoPlayerState extends State<DriveVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _currentFileId;
  num? _lastAppliedUpdatedAt;
  bool _dragging = false;
  double _dragPosition = 0;
  int _volume = 80;
  bool _volumePopoverOpen = false;
  bool _endFired = false;
  bool _backgrounded = false;
  // Set alongside _backgrounded whenever PIP is involved on *either* side
  // of the current paused/inactive/hidden dip — see the matching field's
  // doc in sync_video_player.dart for why checking isInPip only at the
  // resumed instant isn't enough (it misses whichever end of the
  // transition — entering or leaving PIP — hadn't updated yet).
  bool _pipInvolvedInCurrentDip = false;
  // True only when we actually started the background audio handler for
  // this background stretch (i.e. it was genuinely playing when we left) —
  // guards _handoffToForegroundVideo from pulling a stale/zero position
  // when there was nothing to hand off in the first place.
  bool _handedOffToBackground = false;
  // Pending, cancellable version of the real background handoff — see the
  // paused case below for why this can't just run immediately.
  Timer? _pendingBackgroundHandoff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PipService.isInPip.addListener(_onPipChanged);
    _rebuildControllerIfNeeded();
    // See the matching comment in sync_video_player.dart: playback:state
    // can already be sitting on widget.playback by this first build (the
    // server sends it proactively on room:join), and didUpdateWidget never
    // fires for a first build — so without this, a joining viewer would
    // silently stay at 0:00 instead of landing on the host's position.
    _applyRemotePlaybackIfNeeded();
    if (!widget.isHost) widget.onRequestState();
  }

  @override
  void didUpdateWidget(covariant DriveVideoPlayer old) {
    super.didUpdateWidget(old);
    _rebuildControllerIfNeeded();
    _applyRemotePlaybackIfNeeded();
  }

  void _rebuildControllerIfNeeded() {
    final fileId = widget.videoUrl;
    if (fileId == null || fileId == _currentFileId) return;
    _currentFileId = fileId;
    _controller?.dispose();
    final token = ApiClient.tokenGetter?.call();
    final uri = Uri.parse(
        '${ApiClient.baseUrl}/drive/stream/$fileId?roomId=${widget.roomId}');
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders:
          token != null ? {'Authorization': 'Bearer $token'} : const {},
    );
    _controller = controller;
    _endFired = false;
    controller
      ..setVolume(_volume / 100)
      ..addListener(_onTick)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        // The controller wasn't initialized yet when initState/didUpdateWidget
        // last tried to apply widget.playback (that call no-ops until
        // isInitialized), so retry now that it actually can seek/play.
        _applyRemotePlaybackIfNeeded();
      });
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final duration = c.value.duration;
    if (!_endFired &&
        duration > Duration.zero &&
        c.value.position >= duration - const Duration(milliseconds: 300) &&
        !c.value.isPlaying) {
      _endFired = true;
      widget.onEnded();
    }
    if (mounted) setState(() {});
  }

  void _handleVolumeChange(int next) {
    final clamped = next.clamp(0, 100);
    setState(() => _volume = clamped);
    _controller?.setVolume(clamped / 100);
  }

  void _applyRemotePlaybackIfNeeded() {
    final p = widget.playback;
    final c = _controller;
    if (p == null || c == null || !c.value.isInitialized) return;
    final updatedAt = p['updatedAt'] == null ? null : asNum(p['updatedAt']);
    if (updatedAt != null && updatedAt == _lastAppliedUpdatedAt) return;
    _lastAppliedUpdatedAt = updatedAt;

    var position = asNum(p['position']).toDouble();
    // Correct for however long this event took to arrive, same reasoning
    // as sync_video_player.dart's identical fix — otherwise the drift
    // comparison below is measured against an already-stale target.
    if (p['isPlaying'] == true && updatedAt != null) {
      final elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - updatedAt) / 1000;
      if (elapsedSeconds > 0) position += elapsedSeconds;
    }
    // Only correct drift beyond 1.5s so local buffering doesn't fight the
    // remote sync tick — same guardrail called for in the original spec.
    final drift = (c.value.position.inMilliseconds / 1000 - position).abs();
    if (drift > 1.5) {
      c.seekTo(Duration(milliseconds: (position * 1000).round()));
    }
    if (p['isPlaying'] == true) {
      c.play();
    } else {
      c.pause();
    }
  }

  // See the matching method's doc in sync_video_player.dart — catches PIP
  // being entered partway through a dip (isInPip still false at the very
  // start, native onPipModeChanged's async round trip lands moments later)
  // so the resumed-side check below isn't limited to whatever isInPip
  // happens to read at that one instant.
  void _onPipChanged() {
    if (PipService.isInPip.value) _pipInvolvedInCurrentDip = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // Entering Picture-in-Picture reports the same paused/inactive/
        // hidden dip as a real background — but PIP keeps the video
        // visibly playing in a small floating window, so pausing it here
        // and handing off to the (invisible) background audio handler is
        // exactly wrong: confirmed live, this is why the video paused/
        // went black the moment PIP kicked in instead of continuing.
        if (PipService.isInPip.value) return;
        if (!_backgrounded) _pipInvolvedInCurrentDip = PipService.isInPip.value;
        _backgrounded = true;
        // The check above only catches PIP entered via our own in-app
        // enterPip() button, which sets isInPip optimistically before this
        // event fires. Auto-PIP (pressing the home button) goes straight to
        // the OS, so isInPip only flips true later, once the native
        // onPipModeChanged round trip lands — this event can easily win
        // that race. Handing off immediately here paused the controller
        // before we knew better, and since the resumed case below just
        // clears the PIP flag and returns without ever undoing that pause,
        // the video was left frozen for the rest of the PIP session
        // (confirmed live — this was the "not play continuously" glitch).
        // Waiting a beat for the round trip to land, and re-checking right
        // before actually committing to the handoff, avoids ever pausing a
        // video that turns out to just be entering PIP.
        _pendingBackgroundHandoff?.cancel();
        _pendingBackgroundHandoff =
            Timer(const Duration(milliseconds: 300), () {
          if (!mounted || !_backgrounded) return;
          if (_pipInvolvedInCurrentDip || PipService.isInPip.value) return;
          _handoffToBackgroundAudio();
        });
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (PipService.isInPip.value) return;
        if (!_backgrounded) _pipInvolvedInCurrentDip = PipService.isInPip.value;
        _backgrounded = true;
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        _backgrounded = false;
        // Whether or not it ever fired, a handoff scheduled for a dip that's
        // now over is either stale or (if PIP) about to be skipped anyway —
        // never let it land after we've already resumed.
        _pendingBackgroundHandoff?.cancel();
        _pendingBackgroundHandoff = null;
        if (_pipInvolvedInCurrentDip || PipService.isInPip.value) {
          // PIP was involved somewhere in this dip — either entering it
          // (isInPip was still false at the very start, caught moments
          // later by _onPipChanged) or leaving it (isInPip has already
          // flipped back to false again by the time resumed fires). Either
          // way nothing was ever actually backgrounded — skip the resync
          // below entirely; requesting + applying a corrected position
          // re-seeks an already-fine, already-playing video for no reason,
          // which is what showed up as a ~1s pause/play glitch on every
          // PIP transition, both directions.
          _pipInvolvedInCurrentDip = false;
          return;
        }
        _handoffToForegroundVideo();
        // Android pauses the decoder while backgrounded/locked for host and
        // viewer alike — re-sync to the room's real, elapsed-time-corrected
        // position instead of leaving the host's own copy stale (a stale
        // host tapping play again would re-broadcast that stale position to
        // everyone else in the room).
        widget.onRequestState();
      case AppLifecycleState.detached:
        break;
    }
  }

  // video_player has no background-survival story on Android at all — the
  // decoder just stops. Handing off to the shared background_audio_handler
  // (a real native media session) is what actually keeps sound going with
  // the screen off/app backgrounded and gives lock-screen play/pause
  // controls, instead of the room just going silent for this device.
  // [pauseController] is skipped when called from dispose() — the local
  // controller is about to be destroyed anyway right after, so pausing it
  // first would just race that teardown for no benefit.
  Future<void> _handoffToBackgroundAudio({bool pauseController = true}) async {
    final c = _controller;
    final fileId = _currentFileId;
    if (c == null ||
        !c.value.isInitialized ||
        fileId == null ||
        !c.value.isPlaying) {
      return;
    }
    final position = c.value.position;
    if (pauseController) await c.pause();
    final token = ApiClient.tokenGetter?.call();
    final uri =
        '${ApiClient.baseUrl}/drive/stream/$fileId?roomId=${widget.roomId}';
    try {
      _handedOffToBackground = true;
      await backgroundAudioHandler.loadAndPlay(
        url: uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : const {},
        initialPosition: position,
        title: widget.title ?? 'Playing in Insync',
        artUri: widget.thumbnail,
      );
    } catch (_) {
      // Best-effort — falling back to silence while backgrounded beats
      // crashing; the foreground handoff below still re-syncs on resume.
      _handedOffToBackground = false;
    }
  }

  Future<void> _handoffToForegroundVideo() async {
    if (!_handedOffToBackground) return;
    _handedOffToBackground = false;
    final c = _controller;
    final bgPosition = backgroundAudioHandler.position;
    await backgroundAudioHandler.stopSource();
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(bgPosition);
    await c.play();
  }

  double get _positionSeconds =>
      (_controller?.value.position.inMilliseconds ?? 0) / 1000;

  void _handleTap() {
    final c = _controller;
    if (!widget.isHost || c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      widget.onPause(_positionSeconds);
    } else {
      c.play();
      widget.onPlay(_positionSeconds);
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
    if (controller == null || !controller.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
            color: AppColors.surface2,
            alignment: Alignment.center,
            child: const Spinner()),
      );
    }

    final duration = controller.value.duration.inSeconds.toDouble();
    final position = _dragging
        ? _dragPosition
        : controller.value.position.inSeconds.toDouble();
    final audioOnly = widget.mediaMode == 'audio';

    // No rounded-corner card/box — the video now runs edge-to-edge at full
    // screen width right under the header, so a "boxed" look doesn't apply.
    final videoTree = AspectRatio(
      // The real native aspect ratio (video_player exposes this once
      // initialized from the actual stream's metadata) — was hardcoded
      // 16:9, which pillarboxed/letterboxed anything else (e.g. a portrait
      // phone recording) inside a wrong-shaped box.
      aspectRatio: controller.value.aspectRatio,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(controller),
            // A dedicated button, not a whole-video tap target — tapping
            // anywhere on the video (e.g. near the seek bar) was toggling
            // playback by accident.
            if (widget.isHost)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoomSkipButton(
                        forward: false, onTap: widget.onSkipPrevious),
                    const SizedBox(width: 24),
                    RoomPlayPauseButton(
                        playing: controller.value.isPlaying, onTap: _handleTap),
                    const SizedBox(width: 24),
                    RoomSkipButton(forward: true, onTap: widget.onSkip),
                  ],
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              // Manual PIP trigger — auto-PIP-on-minimize has been
              // unreliable (see PipService/MainActivity.kt), so this gives
              // a direct, always-available way in rather than depending
              // solely on Android detecting the app leaving.
              child: GestureDetector(
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
                child: Row(
                  children: [
                    Text(_formatTime(position),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6)),
                        child: Slider(
                          value: duration > 0 ? position.clamp(0, duration) : 0,
                          max: duration > 0 ? duration : 1,
                          activeColor: AppColors.primary,
                          inactiveColor: Colors.white24,
                          onChanged: widget.isHost ? _handleSeekChanged : null,
                          onChangeEnd: widget.isHost ? _handleSeekEnd : null,
                        ),
                      ),
                    ),
                    Text(_formatTime(duration),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!audioOnly) return videoTree;

    // Kept at a modest real size (not shrunk to 1x1 / wrapped in Opacity)
    // — see sync_video_player.dart's matching comment: mobile platform-view
    // playback can silently stall when shrunk near-zero or made
    // transparent, which was causing audio to drift after switching to
    // audio-only. 100x100 clears that threshold while staying fully
    // covered by StaticBloomPlayer, which sizes itself naturally here
    // rather than being force-stretched (that stretch previously caused a
    // layout overflow).
    return Stack(
      children: [
        SizedBox(
            width: 100, height: 100, child: IgnorePointer(child: videoTree)),
        StaticBloomPlayer(
          playing: controller.value.isPlaying,
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PipService.isInPip.removeListener(_onPipChanged);
    _pendingBackgroundHandoff?.cancel();
    if (_handedOffToBackground) {
      // Already playing through the background session (we were OS-
      // backgrounded) and now the widget itself is going away too — stop
      // rather than leaving it playing with nothing left to reattach to.
      backgroundAudioHandler.stopSource();
    } else {
      // Leaving this screen while still in the foreground — in-app
      // navigation to another page, not an OS-level background. Hand off
      // to the same background session so audio keeps playing instead of
      // cutting out; ActiveRoomHolder.leave() stops it again if this
      // dispose turns out to be a real "Leave Room", not just a minimize.
      // Fire-and-forget: pauseController:false skips awaiting a pause on
      // the controller we're about to dispose two lines down anyway.
      _handoffToBackgroundAudio(pauseController: false);
    }
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }
}
