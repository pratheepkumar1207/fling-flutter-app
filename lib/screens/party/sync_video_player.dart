import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/format.dart';
import '../../core/youtube_util.dart';
import '../../theme/app_colors.dart';
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
  final bool liked;
  final VoidCallback onToggleLike;
  final bool compact;

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
    required this.liked,
    required this.onToggleLike,
    this.compact = false,
  });

  @override
  State<SyncVideoPlayer> createState() => _SyncVideoPlayerState();
}

class _SyncVideoPlayerState extends State<SyncVideoPlayer> {
  YoutubePlayerController? _controller;
  String? _currentVideoId;
  num? _lastAppliedUpdatedAt;
  bool _dragging = false;
  double _dragPosition = 0;
  int _volume = 80;
  bool _volumePopoverOpen = false;
  bool? _lastReportedIsPlaying;

  @override
  void initState() {
    super.initState();
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
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false, hideControls: true, disableDragSeek: true, enableCaption: false),
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
    if (p == null || c == null) return;
    final updatedAt = p['updatedAt'] == null ? null : asNum(p['updatedAt']);
    if (updatedAt != null && updatedAt == _lastAppliedUpdatedAt) return;
    _lastAppliedUpdatedAt = updatedAt;

    final position = asNum(p['position']).toDouble();
    c.seekTo(Duration(milliseconds: (position * 1000).round()));
    if (p['isPlaying'] == true) {
      c.play();
    } else {
      c.pause();
    }
  }

  double get _positionSeconds => (_controller?.value.position.inMilliseconds ?? 0) / 1000;

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
        child: Container(color: AppColors.surface2, alignment: Alignment.center, child: const Text('No video', style: TextStyle(color: AppColors.textFaint))),
      );
    }

    final audioOnly = widget.mediaMode == 'audio';

    // The YoutubePlayer widget stays mounted at a real (if tiny) size either
    // way — it's what's actually producing the audio, and WebView-backed
    // players commonly suspend playback if shrunk to a literal zero size or
    // taken fully offstage. In audio-only mode it's just shrunk to 1x1 and
    // hidden behind the Static Bloom card instead.
    final videoTree = AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            YoutubePlayer(controller: controller, showVideoProgressIndicator: false),
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
                child: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final duration = value.metaData.duration.inSeconds.toDouble();
                    final position = _dragging ? _dragPosition : value.position.inSeconds.toDouble();
                    return Row(
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
        final position = _dragging ? _dragPosition : value.position.inSeconds.toDouble();
        return Stack(
          children: [
            SizedBox(width: 100, height: 100, child: IgnorePointer(child: videoTree)),
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
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerStateChanged);
    _controller?.dispose();
    super.dispose();
  }
}
