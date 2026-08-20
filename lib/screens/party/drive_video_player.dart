import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/background_audio_handler.dart';
import '../../core/format.dart';
import '../../core/pip_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/room_play_pause_button.dart';
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
    required this.liked,
    required this.onToggleLike,
    this.compact = false,
  });

  @override
  State<DriveVideoPlayer> createState() => _DriveVideoPlayerState();
}

class _DriveVideoPlayerState extends State<DriveVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _currentFileId;
  num? _lastAppliedUpdatedAt;
  bool _dragging = false;
  double _dragPosition = 0;
  int _volume = 80;
  bool _volumePopoverOpen = false;
  bool _endFired = false;
  bool _backgrounded = false;
  // True only when we actually started the background audio handler for
  // this background stretch (i.e. it was genuinely playing when we left) —
  // guards _handoffToForegroundVideo from pulling a stale/zero position
  // when there was nothing to hand off in the first place.
  bool _handedOffToBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final uri = Uri.parse('${ApiClient.baseUrl}/drive/stream/$fileId?roomId=${widget.roomId}');
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: token != null ? {'Authorization': 'Bearer $token'} : const {},
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
    if (!_endFired && duration > Duration.zero && c.value.position >= duration - const Duration(milliseconds: 300) && !c.value.isPlaying) {
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

    final position = asNum(p['position']).toDouble();
    // Only correct drift beyond 1.5s so local buffering doesn't fight the
    // remote sync tick — same guardrail called for in the original spec.
    final drift = (c.value.position.inMilliseconds / 1000 - position).abs();
    if (drift > 1.5) c.seekTo(Duration(milliseconds: (position * 1000).round()));
    if (p['isPlaying'] == true) {
      c.play();
    } else {
      c.pause();
    }
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
        // Only truly-backgrounded (not the transient inactive/hidden blip a
        // system dialog can cause) is worth the cost of spinning up a real
        // audio handoff.
        _backgrounded = true;
        _handoffToBackgroundAudio();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (PipService.isInPip.value) return;
        _backgrounded = true;
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        _backgrounded = false;
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
  Future<void> _handoffToBackgroundAudio() async {
    final c = _controller;
    final fileId = _currentFileId;
    if (c == null || !c.value.isInitialized || fileId == null || !c.value.isPlaying) return;
    final position = c.value.position;
    await c.pause();
    final token = ApiClient.tokenGetter?.call();
    final uri = '${ApiClient.baseUrl}/drive/stream/$fileId?roomId=${widget.roomId}';
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

  double get _positionSeconds => (_controller?.value.position.inMilliseconds ?? 0) / 1000;

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
        child: Container(color: AppColors.surface2, alignment: Alignment.center, child: const Spinner()),
      );
    }

    final duration = controller.value.duration.inSeconds.toDouble();
    final position = _dragging ? _dragPosition : controller.value.position.inSeconds.toDouble();
    final audioOnly = widget.mediaMode == 'audio';

    // No rounded-corner card/box — the video now runs edge-to-edge at full
    // screen width right under the header, so a "boxed" look doesn't apply.
    final videoTree = AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(controller),
            // A dedicated button, not a whole-video tap target — tapping
            // anywhere on the video (e.g. near the seek bar) was toggling
            // playback by accident.
            if (widget.isHost) Center(child: RoomPlayPauseButton(playing: controller.value.isPlaying, onTap: _handleTap)),
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
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 16),
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
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: Text(widget.liked ? '❤️' : '🤍', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
            if (_volumePopoverOpen)
              Positioned(
                right: 8,
                bottom: 64,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(16)),
                  child: VolumeDots(volume: _volume, onVolumeChange: _handleVolumeChange, trackColor: Colors.white24),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 6),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent])),
                child: Row(
                  children: [
                    Text(_formatTime(position), style: const TextStyle(color: Colors.white, fontSize: 11)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
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
                    Text(_formatTime(duration), style: const TextStyle(color: Colors.white, fontSize: 11)),
                    IconButton(
                      onPressed: () => setState(() => _volumePopoverOpen = !_volumePopoverOpen),
                      icon: Icon(_volume == 0 ? Icons.volume_off : (_volume < 50 ? Icons.volume_down : Icons.volume_up), color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: widget.onSkip,
                      icon: const Icon(Icons.skip_next, color: Colors.white, size: 20),
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
        SizedBox(width: 100, height: 100, child: IgnorePointer(child: videoTree)),
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
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_handedOffToBackground) backgroundAudioHandler.stopSource();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }
}
