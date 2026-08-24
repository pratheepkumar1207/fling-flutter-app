import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted-glass panel — blurs whatever sits behind it and tints with a
/// low-opacity white overlay instead of a flat/solid or room-tinted
/// background color. Used across the room chrome (AppBar, chat bar, queue
/// and settings sheets, roster drawer) for the "glassy, no flat color" look
/// requested to match the reference home-screen mockup's translucent cards.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;
  final Border? border;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.blur = 20,
    this.opacity = 0.12,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: border ??
                Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The AppBar's own translucent, blurred backing — drop into `flexibleSpace`
/// with the AppBar's `backgroundColor` set to transparent.
class GlassAppBarBackground extends StatelessWidget {
  const GlassAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }
}

/// Circular frosted-glass icon button — the floating rail's mic/gift/poll/
/// share/invite controls and similar round chrome controls, replacing the
/// old flat `Colors.black.withValues(alpha: .45)` circle.
class GlassCircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;
  // Still blurs what's behind it either way — this only swaps the tint, for
  // buttons that need to show an active/status color (mic live, request
  // pending, etc.) without losing the glass treatment.
  final Color? color;

  const GlassCircleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 44,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                  color: color?.withValues(alpha: 0.9) ??
                      Colors.white.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
