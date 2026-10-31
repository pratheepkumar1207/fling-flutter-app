import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_image.dart';

/// A record that spins, with the song cover as its label.
class SpinningVinyl extends StatefulWidget {
  final String? thumbnail;
  final double size;
  final bool spinning;
  const SpinningVinyl(
      {super.key, this.thumbnail, this.size = 120, this.spinning = true});

  @override
  State<SpinningVinyl> createState() => _SpinningVinylState();
}

class _SpinningVinylState extends State<SpinningVinyl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant SpinningVinyl old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) _c.repeat();
    if (!widget.spinning && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RotationTransition(
      turns: _c,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            for (var i = 0; i < 14; i++)
              i.isEven ? const Color(0xFF141317) : const Color(0xFF1E1C23),
          ]),
          border: Border.all(color: const Color(0xFF2A2433), width: 2),
        ),
        child: Center(
          child: Container(
            width: s * 0.42,
            height: s * 0.42,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [
                Color(0xFF3A1430),
                AppColors.primary,
                AppColors.pink,
                Color(0xFF3A1430),
              ]),
            ),
            child: Stack(fit: StackFit.expand, children: [
              if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
                AppImage(source: widget.thumbnail, fit: BoxFit.cover),
              Center(
                child: Container(
                  width: s * 0.06,
                  height: s * 0.06,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.bg),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
