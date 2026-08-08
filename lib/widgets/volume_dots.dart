import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Vertical drag-to-set volume rail with lit-dot indicators — extracted
/// from StaticBloomPlayer so the same "Static Bloom" volume control can be
/// reused on the video player too (not just audio-only mode).
class VolumeDots extends StatelessWidget {
  final int volume;
  final ValueChanged<int> onVolumeChange;
  final int dots;
  final double height;
  final Color trackColor;

  const VolumeDots({
    super.key,
    required this.volume,
    required this.onVolumeChange,
    this.dots = 8,
    this.height = 80,
    this.trackColor = AppColors.surface3,
  });

  void _updateFromLocalY(double y) {
    final ratio = (1 - (y / height)).clamp(0.0, 1.0);
    onVolumeChange((ratio * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    final litDots = ((volume / 100) * dots).round();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) => _updateFromLocalY(d.localPosition.dy),
      onVerticalDragUpdate: (d) => _updateFromLocalY(d.localPosition.dy),
      onTapDown: (d) => _updateFromLocalY(d.localPosition.dy),
      child: Container(
        width: 24,
        height: height,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(999)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: List.generate(dots, (i) {
            final lit = (dots - 1 - i) < litDots;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: lit ? 6 : 4.5,
                height: lit ? 6 : 4.5,
                decoration: BoxDecoration(shape: BoxShape.circle, color: lit ? AppColors.primary : Colors.white.withValues(alpha: 0.15)),
              ),
            );
          }),
        ),
      ),
    );
  }
}
