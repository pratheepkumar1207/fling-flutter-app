import 'package:flutter/material.dart';

/// Dark-mode palette — literal monochrome (black/white/gray only). success
/// and danger are the one deliberate exception: they're functional status
/// signals (delete confirmations, error states), not brand decoration, so
/// they keep red/green rather than becoming indistinguishable grays. Every
/// other token — including what used to be the brand pink/purple/gold — is
/// grayscale. See AppColorsLight for the light-mode sibling.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF161616);
  static const surface2 = Color(0xFF202020);
  static const surface3 = Color(0xFF2A2A2A);
  static const border = Color(0x1EFFFFFF);

  static const primary = Color(0xFFFFFFFF);
  static const primaryDim = Color(0xFFCCCCCC);
  static const accent = Color(0xFFB3B3B3);
  static const gold = Color(0xFFE0E0E0);

  static const text = Color(0xFFF5F5F5);
  static const textDim = Color(0xFFAAAAAA);
  static const textFaint = Color(0xFF6E6E6E);

  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFF4D6D);
  static const warning = Color(0xFFE0E0E0);
}

/// Light-mode palette — same monochrome approach, inverted base.
class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF2F2F2);
  static const surface3 = Color(0xFFE5E5E5);
  static const border = Color(0x14000000);

  static const primary = Color(0xFF0A0A0A);
  static const primaryDim = Color(0xFF333333);
  static const accent = Color(0xFF4D4D4D);
  static const gold = Color(0xFF666666);

  static const text = Color(0xFF0A0A0A);
  static const textDim = Color(0xFF666666);
  static const textFaint = Color(0xFF999999);

  static const success = Color(0xFF1FAE7A);
  static const danger = Color(0xFFE23F63);
  static const warning = Color(0xFF666666);
}

/// Grayscale "brand" gradient — previously the insync logo's pink/purple/
/// blue; kept as a gradient (white -> gray) for the same decorative call
/// sites (avatar story ring, etc.) rather than removing the gradient
/// treatment entirely.
class AppGradients {
  AppGradients._();

  static const List<Color> brand = [
    Color(0xFFFFFFFF),
    Color(0xFFAAAAAA),
    Color(0xFF555555),
  ];

  static const LinearGradient brandDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brand,
  );

  /// Primary CTA pill gradient — white to light gray, the monochrome
  /// equivalent of what used to be a magenta-to-purple two-tone button.
  static const List<Color> volaCta = [
    Color(0xFFFFFFFF),
    Color(0xFFCCCCCC),
  ];

  static const LinearGradient volaCtaDiagonal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: volaCta,
  );
}
