import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
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

class _DriveVideoPlayerState extends State<DriveVideoPlayer> {
  VideoPlayerController? _controller;
  String? _currentFileId;
  num? _lastAppliedUpdatedAt;
  bool _dragging = false;
  double _dragPosition = 0;
  int _volume = 80;
  bool _volumePopoverOpen = false;
  bool _endFired = false;

  @override
  void initState() {
    super.initState();
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

    final videoTree = AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(controller),
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _handleTap),
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
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }
}
