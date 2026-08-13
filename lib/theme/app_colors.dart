import 'package:flutter/material.dart';

/// Dark-mode palette — retuned to the "Vola Party" reference look (deep
/// purple-magenta, flat cards over a saturated purple base) that
/// VolaPartyColors first proved out for the Watch Party room; see
/// AppColorsLight for the light-mode sibling and AppGradients.brand /
/// AppGradients.volaCta for the shared gradient stops.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF1A0F2E);
  static const surface = Color(0xFF3A2463);
  static const surface2 = Color(0xFF4A2F7A);
  static const surface3 = Color(0xFF5A3A94);
  static const border = Color(0x33FFFFFF);

  static const primary = Color(0xFFE91E8C);
  static const primaryDim = Color(0xFFC0157A);
  static const accent = Color(0xFFFF3D77);
  static const gold = Color(0xFFF0C419);

  static const text = Color(0xFFF5F3FA);
  static const textDim = Color(0xFFC9B8E8);
  static const textFaint = Color(0xFF8B7AB0);

  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFF4D6D);
  static const warning = Color(0xFFFFC94D);
}

/// Light-mode palette — soft lavender-white base, same brand hues.
class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFF3F1FA);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF7F5FC);
  static const surface3 = Color(0xFFEFEAFA);
  static const border = Color(0x14201040);

  static const primary = Color(0xFF9B4DFF);
  static const primaryDim = Color(0xFF8B3DFF);
  static const accent = Color(0xFFE23F77);
  static const gold = Color(0xFFC98A1F);

  static const text = Color(0xFF1E1B2E);
  static const textDim = Color(0xFF6B6480);
  static const textFaint = Color(0xFFA79FC2);

  static const success = Color(0xFF1FAE7A);
  static const danger = Color(0xFFE23F63);
  static const warning = Color(0xFFC98A1F);
}

/// The insync logo's pink -> purple -> blue gradient, shared by the avatar
/// "story ring" and other decorative uses it already had before the Vola
/// Party retune — kept as-is since those uses aren't primary CTAs.
class AppGradients {
  AppGradients._();

  static const List<Color> brand = [
    Color(0xFFFF3D77),
    Color(0xFF9B4DFF),
    Color(0xFF3D7BFF),
  ];

  static const LinearGradient brandDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brand,
  );

  /// Primary CTA pill gradient (Go Live / Send / Take Picture-style
  /// buttons) — magenta to purple, matching the Vola Party reference's
  /// flat two-tone buttons rather than the three-stop brand gradient.
  static const List<Color> volaCta = [
    Color(0xFFE91E8C),
    Color(0xFF8B2FC9),
  ];

  static const LinearGradient volaCtaDiagonal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: volaCta,
  );
}
