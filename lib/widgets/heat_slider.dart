import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';

/// "Hot Wings" style heat-level slider — Dart port of HeatSlider.jsx. Drag
/// across a gradient track to pick one of a fixed set of tiers, snapping to
/// the nearest as you go. Built for WalletBuyScreen's coin presets but kept
/// generic so other tiered-choice UIs can reuse it.
class HeatSlider extends StatefulWidget {
  final List<int> values;
  final int index;
  final ValueChanged<int> onChanged;
  final String Function(int value) formatLabel;

  const HeatSlider({super.key, required this.values, required this.index, required this.onChanged, required this.formatLabel});

  @override
  State<HeatSlider> createState() => _HeatSliderState();
}

class _HeatSliderState extends State<HeatSlider> {
  bool _dragging = false;
  double _trackWidth = 0;

  void _updateFromLocalX(double x) {
    if (_trackWidth <= 0) return;
    final ratio = (x / _trackWidth).clamp(0.0, 1.0);
    final nextIndex = (ratio * (widget.values.length - 1)).round();
    if (nextIndex != widget.index) widget.onChanged(nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.values.length > 1 ? widget.index / (widget.values.length - 1) : 0.0;
    final hue = 340 - ratio * 45;
    final trackColor = HSLColor.fromAHSL(1, hue, 0.9, 0.6 - ratio * 0.12).toColor();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.values.length, (i) {
            final lit = i <= widget.index;
            return AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: kSpringCurve,
              scale: lit ? 1.1 : 0.9,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: lit ? 1 : 0.25,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text('🔥', style: TextStyle(fontSize: 18)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Container(
          width: 160,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface2.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: trackColor.withValues(alpha: 0.5), blurRadius: 0, spreadRadius: 1),
              BoxShadow(color: trackColor.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 300),
            curve: kSpringCurve,
            scale: _dragging ? 1.1 : 1.0,
            child: Text(
              widget.formatLabel(widget.values[widget.index]),
              style: TextStyle(color: trackColor, fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            _trackWidth = constraints.maxWidth;
            return GestureDetector(
              onPanStart: (d) {
                setState(() => _dragging = true);
                _updateFromLocalX(d.localPosition.dx);
              },
              onPanUpdate: (d) => setState(() => _updateFromLocalX(d.localPosition.dx)),
              onPanEnd: (_) => setState(() => _dragging = false),
              onTapDown: (d) {
                setState(() => _dragging = true);
                _updateFromLocalX(d.localPosition.dx);
              },
              onTapUp: (_) => setState(() => _dragging = false),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      HSLColor.fromAHSL(1, 340, 0.85, 0.6).toColor(),
                      HSLColor.fromAHSL(1, hue, 0.9, 0.55).toColor(),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: kSpringCurve,
                      alignment: Alignment(ratio * 2 - 1, 0),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: _dragging ? 1.15 : 1.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
                            child: const Text('🌶️', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.formatLabel(widget.values.first), style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
            Text(widget.formatLabel(widget.values.last), style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
