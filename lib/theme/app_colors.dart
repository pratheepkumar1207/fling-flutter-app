import 'package:flutter/material.dart';

/// Dark-mode palette — precisely converted (oklch -> sRGB) from the
/// fling-redesign design canvas's :root tokens (--bg:oklch(13% .014 280)
/// etc.), which is the single source of truth for both light and dark.
/// success/danger stay as functional status signals regardless of brand
/// color. See AppColorsLight for the light-mode sibling.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF06070D);
  static const surface = Color(0xFF101119);
  static const surface2 = Color(0xFF191A23);
  static const surface3 = Color(0xFF232430); // one step past surface2, same progression rate as the design's surface->surface2 step
  static const border = Color(0xFF2C2D38);

  // No separate --primary token in the design canvas — --accent is the
  // single solid brand color used for CTAs/highlights/selected states.
  static const primary = Color(0xFFE74D68);
  static const primaryDim = Color(0xFFC13750);
  static const accent = Color(0xFFE74D68);
  static const accent2 = Color(0xFFA161E0);
  static const gold = Color(0xFFDBB155);

  static const text = Color(0xFFF1F1F4);
  static const textDim = Color(0xFFA9AAB2);
  static const textFaint = Color(0xFF676871);

  static const success = Color(0xFF43B966);
  static const danger = Color(0xFFED4B43);
  static const warning = Color(0xFFDBB155);
}

/// Light-mode palette — warm off-white ground, same coral/violet identity.
class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4F1ED);
  static const surface3 = Color(0xFFEBE7E1);
  static const border = Color(0xFFE4E1DD);

  static const primary = Color(0xFFE74D68);
  static const primaryDim = Color(0xFFC13750);
  static const accent = Color(0xFFE74D68);
  static const accent2 = Color(0xFFA161E0);
  static const gold = Color(0xFFDBB155);

  static const text = Color(0xFF16130F);
  static const textDim = Color(0xFF5B5752);
  static const textFaint = Color(0xFF96918C);

  static const success = Color(0xFF45B164);
  static const danger = Color(0xFFD73431);
  static const warning = Color(0xFFDBB155);
}

/// Brand gradient — coral-to-violet, used for the avatar story-ring, CTAs
/// and other decorative accents. Precisely matches the design canvas's
/// `--grad` token: linear-gradient(135deg, oklch(67% .19 22), oklch(60% .19 320)) —
/// identical in both light and dark canvas variants.
class AppGradients {
  AppGradients._();

  static const List<Color> brand = [
    Color(0xFFF4595E),
    Color(0xFFB051C5),
  ];

  static const LinearGradient brandDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brand,
  );

  /// Primary CTA pill gradient — same coral-to-violet brand gradient, for
  /// buttons like "Create Room" / "Upgrade Now" / the floating "+" action.
  static const List<Color> volaCta = brand;

  static const LinearGradient volaCtaDiagonal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: volaCta,
  );
}
