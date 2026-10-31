import '../theme/insync_icons.dart';

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
  final bool compact;
  final VoidCallback? onSkip;
  final VoidCallback? onSkipPrevious;
  // Compact (room) bar only: like, and a listener's skip vote.
  final bool liked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onVoteSkip;

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
    this.compact = false,
    this.onSkip,
    this.onSkipPrevious,
    this.liked = false,
    this.onToggleLike,
    this.onVoteSkip,
  });

  @override
  State<StaticBloomPlayer> createState() => _StaticBloomPlayerState();
}

class _StaticBloomPlayerState extends State<StaticBloomPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant StaticBloomPlayer old) {
    super.didUpdateWidget(old);
    if (_spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_spinning) {
      _controller.stop();
    }
  }

  // A listener's play/pause only silences their own phone (the room keeps
  // playing for everyone) — remembers the volume to come back to.
  int? _volumeBeforeMute;
  bool get _mutedHere => !widget.isHost && widget.volume == 0;
  bool get _spinning => widget.playing && !_mutedHere;

  void _toggleHere() {
    if (_mutedHere) {
      widget.onVolumeChange(_volumeBeforeMute ?? 80);
    } else {
      _volumeBeforeMute = widget.volume;
      widget.onVolumeChange(0);
    }
    setState(() {});
  }

  /// The slim one-line room bar: spinning CD, name and time, like,
  /// play/pause and skip, with a hairline progress line the host can drag.
  Widget _slim(BuildContext context) {
    final hasTime = widget.duration > 0;
    final progress =
        hasTime ? (widget.currentTime / widget.duration).clamp(0.0, 1.0) : 0.0;
    final playIcon = _spinning ? InIcons.pause : InIcons.play;
    final onPlay = widget.isHost ? widget.onTogglePlay : _toggleHere;
    final onSkip = widget.isHost ? widget.onSkip : widget.onVoteSkip;
    Widget icon(InIconData i, String label, VoidCallback? onTap,
            {Color? color, bool filled = false}) =>
        Semantics(
          button: true,
          label: label,
          child: InkResponse(
            onTap: onTap,
            radius: 20,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                  child: InIcon(i,
                      size: 17,
                      filled: filled,
                      color: onTap == null
                          ? AppColors.textFaint
                          : (color ?? AppColors.text))),
            ),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: AppColors.surface2,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
            child: Row(children: [
              // The cover as a CD: spins while playing, stops on pause.
              RotationTransition(
                turns: _controller,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface3,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(fit: StackFit.expand, children: [
                    if (widget.thumbnail != null &&
                        widget.thumbnail!.isNotEmpty)
                      AppImage(source: widget.thumbnail, fit: BoxFit.cover)
                    else
                      const Center(
                          child: InIcon(InIcons.music,
                              size: 14, color: AppColors.lilac)),
                    Center(
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.surface2),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.title ?? 'Music',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
              if (hasTime) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                        '${_formatTime(widget.currentTime)}/${_formatTime(widget.duration)}',
                        style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 11,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ],
              icon(InIcons.heart, widget.liked ? 'Unlike' : 'Like',
                  widget.onToggleLike,
                  color: widget.liked ? AppColors.pink : null,
                  filled: widget.liked),
              Semantics(
                button: true,
                label: _spinning ? 'Pause' : 'Play',
                child: InkResponse(
                  onTap: onPlay,
                  radius: 18,
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onPlay == null ? Colors.white38 : Colors.white),
                    child: Center(
                        child: InIcon(playIcon,
                            size: 13, color: Colors.black, filled: true)),
                  ),
                ),
              ),
              icon(InIcons.skipNext, widget.isHost ? 'Skip' : 'Vote to skip',
                  onSkip),
            ]),
          ),
          // Hairline progress; the host can tap or drag it to jump.
          LayoutBuilder(builder: (context, box) {
            void seekTo(double dx, {bool end = false}) {
              if (!widget.isHost || !hasTime) return;
              final t = (dx / box.maxWidth).clamp(0.0, 1.0) * widget.duration;
              widget.onSeekChanged?.call(t);
              if (end) widget.onSeekEnd?.call(t);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => seekTo(d.localPosition.dx, end: true),
              onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
              onHorizontalDragEnd: (_) =>
                  widget.onSeekEnd?.call(widget.currentTime),
              child: SizedBox(
                height: widget.isHost ? 8 : 2,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Stack(children: [
                    Container(height: 2, color: AppColors.surface3),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(height: 2, color: AppColors.lilac),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ]),
      ),
    );
  }

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _slim(context);
    }
    final c = widget.compact;
    final discSize = c ? 32.0 : 56.0;
    final bloomSize = c ? 36.0 : 64.0;
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.all(c ? 8 : 16),
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
                      final bloom = widget.playing
                          ? 0.55 +
                              0.3 * (0.5 - (0.5 - _controller.value).abs()) * 2
                          : 0.35;
                      return Container(
                        width: bloomSize,
                        height: bloomSize,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: bloom)),
                      );
                    },
                  ),
                  RotationTransition(
                    turns: _controller,
                    child: Container(
                      width: discSize,
                      height: discSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface3,
                        boxShadow: c
                            ? null
                            : [
                                BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    blurRadius: 0,
                                    spreadRadius: 1),
                                BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    spreadRadius: 1),
                              ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: (widget.thumbnail != null &&
                              widget.thumbnail!.isNotEmpty)
                          ? AppImage(
                              source: widget.thumbnail, fit: BoxFit.cover)
                          : Text('🎵', style: TextStyle(fontSize: c ? 12 : 20)),
                    ),
                  ),
                ],
              ),
              SizedBox(width: c ? 8 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title ?? 'Playing audio only',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: c ? 12 : 14,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (!c) ...[
                      const SizedBox(height: 2),
                      const Text(
                          'Video hidden to save data — sound keeps playing',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (widget.isHost && widget.onSkipPrevious != null) ...[
                SizedBox(width: c ? 6 : 10),
                GestureDetector(
                  onTap: widget.onSkipPrevious,
                  child: Container(
                    width: c ? 28 : 40,
                    height: c ? 28 : 40,
                    decoration: const BoxDecoration(
                        color: AppColors.surface3, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: InIcon(InIcons.skipPrev,
                        color: AppColors.text, size: c ? 16 : 22),
                  ),
                ),
              ],
              SizedBox(width: c ? 6 : 10),
              GestureDetector(
                onTap: widget.onTogglePlay,
                child: Container(
                  width: c ? 28 : 40,
                  height: c ? 28 : 40,
                  decoration: BoxDecoration(
                      color: widget.onTogglePlay == null
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.primary,
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: InIcon(widget.playing ? InIcons.pause : InIcons.play,
                      color: Colors.white, size: c ? 14 : 20),
                ),
              ),
              if (widget.isHost && widget.onSkip != null) ...[
                SizedBox(width: c ? 6 : 10),
                GestureDetector(
                  onTap: widget.onSkip,
                  child: Container(
                    width: c ? 28 : 40,
                    height: c ? 28 : 40,
                    decoration: const BoxDecoration(
                        color: AppColors.surface3, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: InIcon(InIcons.skipNext,
                        color: AppColors.text, size: c ? 16 : 22),
                  ),
                ),
              ],
              if (!c) ...[
                const SizedBox(width: 10),
                Column(
                  children: [
                    Text('${widget.volume}',
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 10)),
                    const SizedBox(height: 4),
                    VolumeDots(
                        volume: widget.volume,
                        onVolumeChange: widget.onVolumeChange),
                    const SizedBox(height: 4),
                    const Text('VOL',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 9,
                            letterSpacing: 0.5)),
                  ],
                ),
              ],
            ],
          ),
          if (widget.duration > 0)
            Padding(
              padding: EdgeInsets.only(top: c ? 4 : 10),
              child: Row(
                children: [
                  SizedBox(
                      width: 34,
                      child: Text(_formatTime(widget.currentTime),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 10))),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5)),
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
                  SizedBox(
                      width: 34,
                      child: Text(_formatTime(widget.duration),
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 10))),
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
