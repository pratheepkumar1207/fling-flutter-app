import 'package:flutter/material.dart';

/// Dark-mode palette — retuned off the insync logo's own pink -> purple ->
/// blue gradient (see assets/icon/insync-icon.png) instead of the earlier
/// flat Spotify-green accent. See [AppColorsLight] for the light-mode
/// sibling and [AppGradients.brand] for the shared gradient stops.
class AppColors {
  AppColors._();

  // Deep purple-charcoal rather than pure black — claymorphism's soft
  // dual shadows (see ClaySurface) need a mid-dark base to read against.
  static const bg = Color(0xFF15121F);
  static const surface = Color(0xFF1E1A2C);
  static const surface2 = Color(0xFF262137);
  static const surface3 = Color(0xFF2F2941);
  static const border = Color(0x1EFFFFFF);

  // Mid-gradient purple as the single-tone primary; pink/blue live in
  // AppGradients.brand for hero surfaces (buttons, active nav, rings).
  static const primary = Color(0xFFA855F7);
  static const primaryDim = Color(0xFF8B3DFF);
  static const accent = Color(0xFFFF3D77);
  static const gold = Color(0xFFFFC94D);

  static const text = Color(0xFFF5F3FA);
  static const textDim = Color(0xFFA79FC2);
  static const textFaint = Color(0xFF6E6584);

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

/// The insync logo's pink -> purple -> blue gradient, shared by hero
/// buttons, the active bottom-nav pill, and the avatar "story ring".
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
}
