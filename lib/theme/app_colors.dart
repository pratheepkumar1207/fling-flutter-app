import 'package:flutter/material.dart';

/// Dark-mode palette — vivid purple/magenta glassmorphic look (matches the
/// "Popcorn"-style reference: deep violet-black backgrounds, pink-to-purple
/// gradient CTAs, glowing accents). Supersedes the earlier literal-monochrome
/// palette. success/danger stay as functional status signals regardless of
/// brand color. See AppColorsLight for the light-mode sibling.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0B0714);
  static const surface = Color(0xFF1B1330);
  static const surface2 = Color(0xFF241A3F);
  static const surface3 = Color(0xFF2E2350);
  static const border = Color(0x338B5CF6);

  static const primary = Color(0xFF9B5CF6);
  static const primaryDim = Color(0xFF7C3AED);
  static const accent = Color(0xFFEC4899);
  static const gold = Color(0xFFFFD54D);

  static const text = Color(0xFFF5F3FA);
  static const textDim = Color(0xFFB6A9D6);
  static const textFaint = Color(0xFF7C6FA0);

  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFF4D6D);
  static const warning = Color(0xFFFFD54D);
}

/// Light-mode palette — same purple identity, inverted base.
class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFFAF8FF);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF1ECFB);
  static const surface3 = Color(0xFFE4D9F7);
  static const border = Color(0x268B5CF6);

  static const primary = Color(0xFF8B5CF6);
  static const primaryDim = Color(0xFF7C3AED);
  static const accent = Color(0xFFEC4899);
  static const gold = Color(0xFFE0A800);

  static const text = Color(0xFF1D1533);
  static const textDim = Color(0xFF6B5E8C);
  static const textFaint = Color(0xFF9C90B8);

  static const success = Color(0xFF1FAE7A);
  static const danger = Color(0xFFE23F63);
  static const warning = Color(0xFFB8860B);
}

/// Brand gradient — pink-to-purple, used for the avatar story-ring and other
/// decorative accents.
class AppGradients {
  AppGradients._();

  static const List<Color> brand = [
    Color(0xFFEC4899),
    Color(0xFF9B5CF6),
    Color(0xFF6366F1),
  ];

  static const LinearGradient brandDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brand,
  );

  /// Primary CTA pill gradient — vivid pink-to-purple, for buttons like
  /// "Create Room" / "Upgrade Now" / the floating "+" action.
  static const List<Color> volaCta = [
    Color(0xFFEC4899),
    Color(0xFF9B5CF6),
  ];

  static const LinearGradient volaCtaDiagonal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: volaCta,
  );
}
