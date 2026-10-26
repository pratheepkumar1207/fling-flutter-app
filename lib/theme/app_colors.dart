import 'package:flutter/material.dart';

/// Insync palette — black ground with the logo's pink → purple → blue.
class AppColors {
  AppColors._();
  // Fill for selected chips/pills; [ink] is the text drawn on it and on
  // [accent], so it stays white.
  static const paper = Color(0xFF8A2BE2);
  static const ink = Color(0xFFFFFFFF);
  static const inkMuted = Color(0xFFE7DDF5);

  static const bg = Color(0xFF0A0A0D);
  static const surface = Color(0xFF16141D);
  static const surface2 = Color(0xFF1F1C29);
  static const surface3 = Color(0xFF2A2436);
  static const border = Color(0xFF2E2A3A);
  static const primary = Color(0xFF8A2BE2);
  static const primaryDim = Color(0xFF6A1FB0);
  static const accent = Color(0xFF9B3BF5);
  static const accent2 = Color(0xFFFB3F65);
  static const gold = Color(0xFFFFC93C);

  // Brand hues straight from the logo.
  static const pink = Color(0xFFFB3F65);
  static const purple = Color(0xFF9B3BF5);
  static const blue = Color(0xFF4073FC);
  static const lilac = Color(0xFFC79BFF);
  static const diamond = Color(0xFF7AD7FF);

  static const text = Color(0xFFF4F4F6);
  static const textDim = Color(0xFFA29FB0);
  static const textFaint = Color(0xFF8D899C);

  static const success = Color(0xFF43B966);
  static const danger = Color(0xFFE5384F);
  static const warning = Color(0xFFFFC93C);
}

class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4F1ED);
  static const surface3 = Color(0xFFEBE7E1);
  static const border = Color(0xFFE4E1DD);

  static const primary = Color(0xFF8A2BE2);
  static const primaryDim = Color(0xFF6A1FB0);
  static const accent = Color(0xFF9B3BF5);
  static const accent2 = Color(0xFFFB3F65);
  static const gold = Color(0xFFE0A800);

  static const text = Color(0xFF16130F);
  static const textDim = Color(0xFF5B5752);
  static const textFaint = Color(0xFF96918C);

  static const success = Color(0xFF45B164);
  static const danger = Color(0xFFD73431);
  static const warning = Color(0xFFE0A800);
}

class AppGradients {
  AppGradients._();

  static const List<Color> brand = [
    Color(0xFFFB3F65),
    Color(0xFF9B3BF5),
    Color(0xFF4073FC),
  ];

  static const LinearGradient brandDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brand,
  );
  static const List<Color> volaCta = brand;

  static const LinearGradient volaCtaDiagonal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: volaCta,
  );

  /// Hero cards: dark rose → violet → navy, as on Home and Wallet.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A1430), Color(0xFF22123F), Color(0xFF121A3D)],
    stops: [0, 0.55, 1],
  );
}
