import 'dart:ui';
import 'package:flutter/material.dart';
import 'clay_colors.dart';

/// Claymorphism design system — soft, matte, "extruded" surfaces instead
/// of the earlier frosted-glass look. Every existing GlassSurface call
/// site keeps working unchanged; the shape stays the same, only the
/// rendering underneath switched from blur+tint to a dual soft shadow.

/// Matches CSS `cubic-bezier(0.34, 1.56, 0.64, 1)` — a slight overshoot
/// then settle, the "liquid melt" feel used throughout the reference
/// designs' transitions.
const Curve kSpringCurve = Cubic(0.34, 1.56, 0.64, 1);
const Curve kGlassCurve = Cubic(0.16, 1.0, 0.3, 1.0);

/// A soft "clay" card: opaque tint, fully rounded, with a light shadow on
/// one side and a dark shadow on the other so it reads as gently pressed
/// out of the background rather than flat or glassy. Named GlassSurface
/// still (rather than renamed to ClaySurface) so every existing screen
/// picks up the new look with zero call-site changes.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? tint;
  final EdgeInsetsGeometry? padding;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 6,
    this.tint,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final clay = ClayColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? clay.surface2,
        borderRadius: borderRadius,
        border: Border.all(color: clay.border),
        boxShadow: [
          BoxShadow(
            color: clay.shadowDark.withValues(alpha: isDark ? 0.16 : 0.16),
            blurRadius: 20,
            offset: const Offset(7, 7),
          ),
          BoxShadow(
            color: clay.shadowLight.withValues(alpha: isDark ? 0.22 : 0.9),
            blurRadius: 16,
            offset: const Offset(-6, -6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A soft multi-layer glow ring, e.g. around an avatar or a "now playing"
/// card — mirrors the web `.glow-ring` utility.
BoxDecoration glowRingDecoration({required Color color, double radius = 999}) {
  return BoxDecoration(
    shape: radius >= 999 ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: radius >= 999 ? null : BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 0, spreadRadius: 1),
      BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 2),
      BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 48, spreadRadius: 6),
    ],
  );
}

/// Soft-3D "glass icon" chip — a colored diagonal-gradient tile with a
/// glowing drop shadow and a glossy top-left highlight, matching the
/// `.glass-ic` treatment from the Claude Design redesign (fling-redesign
/// design canvas). Wraps any icon glyph (pass it white/light-colored —
/// it sits on a saturated gradient, not the page background).
///
/// Usage: `GlassIcon(colors: [Color(0xFF...), Color(0xFF...)], glowColor:
/// Color(0x..), size: 34, radius: 11, child: Icon(Icons.favorite,
/// color: Colors.white, size: 16))`
class GlassIcon extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final Color glowColor;
  final double size;
  final double radius;
  final EdgeInsetsGeometry? padding;

  const GlassIcon({
    super.key,
    required this.child,
    required this.colors,
    required this.glowColor,
    this.size = 34,
    this.radius = 11,
    this.padding,
  });

  /// Circular variant (radius == size / 2), for avatar-style icon badges.
  const GlassIcon.circle({
    super.key,
    required this.child,
    required this.colors,
    required this.glowColor,
    this.size = 34,
    this.padding,
  }) : radius = size / 2;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glossy top-left highlight — mirrors .glass-ic::before's
            // radial-gradient sheen.
            Positioned(
              top: size * 0.02,
              left: size * 0.06,
              child: Container(
                width: size * 0.65,
                height: size * 0.45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// A blurred, softly-glowing color blob for backgrounds — mirrors the web
/// `.blob` utility used behind the Liquid Glass / Lunara style screens.
class Blob extends StatelessWidget {
  final Color color;
  final double size;

  const Blob({super.key, required this.color, this.size = 220});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}
