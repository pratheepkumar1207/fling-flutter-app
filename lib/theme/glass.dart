import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Spatial / glass design system — Dart counterpart to the web app's
/// `.glass` / `.glow-ring` / `--ease-spring` CSS additions in index.css.
/// Shared building blocks for the "classy" redesign pass (liquid-glass
/// nav, mascot login, sigil OTP, hot-wings slider, cola profile card,
/// static-bloom player) — keep new bespoke screens drawing from these
/// instead of inventing one-off blur/glow values per screen.

/// Matches CSS `cubic-bezier(0.34, 1.56, 0.64, 1)` — a slight overshoot
/// then settle, the "liquid melt" feel used throughout the reference
/// designs' transitions.
const Curve kSpringCurve = Cubic(0.34, 1.56, 0.64, 1);
const Curve kGlassCurve = Cubic(0.16, 1.0, 0.3, 1.0);

/// Frosted-glass surface: blurred backdrop + translucent tint + hairline
/// border + soft outer shadow. Wrap any child in this instead of a plain
/// Container when a screen calls for the "liquid glass" look.
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
    this.blurSigma = 20,
    this.tint,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? AppColors.surface2).withValues(alpha: 0.55),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
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
