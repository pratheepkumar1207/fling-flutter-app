import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';
import 'app_image.dart';
import 'volume_dots.dart';

/// "Static Bloom" style audio-only now-playing card — Dart port of
/// StaticBloomPlayer.jsx. A blooming gradient halo pulses behind a slowly
/// spinning disc while playing (sits still when paused, hence "static"
/// bloom), with a vertical drag-to-set volume rail instead of a horizontal
/// Slider.
class StaticBloomPlayer extends StatefulWidget {
  final bool playing;
  final String? title;
  final String? thumbnail;
  final int volume;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback? onTogglePlay;
  final double currentTime;
  final double duration;
  final bool isHost;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;

  const StaticBloomPlayer({
    super.key,
    required this.playing,
    this.title,
    this.thumbnail,
    required this.volume,
    required this.onVolumeChange,
    this.onTogglePlay,
    this.currentTime = 0,
    this.duration = 0,
    this.isHost = false,
    this.onSeekChanged,
    this.onSeekEnd,
  });

  @override
  State<StaticBloomPlayer> createState() => _StaticBloomPlayerState();
}

class _StaticBloomPlayerState extends State<StaticBloomPlayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant StaticBloomPlayer old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing) {
      _controller.stop();
    }
  }

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final bloom = widget.playing ? 0.55 + 0.3 * (0.5 - (0.5 - _controller.value).abs()) * 2 : 0.35;
                  return Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: bloom)),
                  );
                },
              ),
              RotationTransition(
                turns: _controller,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface3,
                    boxShadow: [
                      BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 0, spreadRadius: 1),
                      BoxShadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 1),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
                      ? AppImage(source: widget.thumbnail, fit: BoxFit.cover)
                      : const Text('🎵', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title ?? 'Playing audio only', style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                const Text('Video hidden to save data — sound keeps playing', style: TextStyle(color: AppColors.textFaint, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onTogglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: widget.onTogglePlay == null ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(widget.playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text('${widget.volume}', style: const TextStyle(color: AppColors.textFaint, fontSize: 10)),
              const SizedBox(height: 4),
              VolumeDots(volume: widget.volume, onVolumeChange: widget.onVolumeChange),
              const SizedBox(height: 4),
              const Text('VOL', style: TextStyle(color: AppColors.textFaint, fontSize: 9, letterSpacing: 0.5)),
            ],
          ),
            ],
          ),
          if (widget.duration > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  SizedBox(width: 34, child: Text(_formatTime(widget.currentTime), textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textFaint, fontSize: 10))),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                      child: Slider(
                        value: widget.currentTime.clamp(0, widget.duration),
                        max: widget.duration,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.surface3,
                        onChanged: widget.isHost ? widget.onSeekChanged : null,
                        onChangeEnd: widget.isHost ? widget.onSeekEnd : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 34, child: Text(_formatTime(widget.duration), style: const TextStyle(color: AppColors.textFaint, fontSize: 10))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
