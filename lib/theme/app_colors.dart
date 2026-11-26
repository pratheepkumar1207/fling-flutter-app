import 'package:flutter/material.dart';

/// Insync palette: black, white and red (changed 26 Nov 2026 from the
/// logo's pink → purple → blue). Black ground, white text and icons, red for
/// the main actions, likes, lobbies and LIVE. Gold stays for coins and green
/// for success, as plain status colours.
class AppColors {
  AppColors._();
  // Fill for selected chips/pills; [ink] is the text drawn on it and on
  // [accent], so it stays white.
  static const paper = Color(0xFFE8112D);
  static const ink = Color(0xFFFFFFFF);
  static const inkMuted = Color(0xFFE6E6E6);

  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF111111);
  // Bottom sheets: plain black, matching the black room.
  static const sheet = Color(0xFF000000);
  static const surface2 = Color(0xFF1A1A1A);
  static const surface3 = Color(0xFF262626);
  static const border = Color(0xFF2A2A2A);
  static const primary = Color(0xFFE8112D);
  static const primaryDim = Color(0xFFB00D22);
  static const accent = Color(0xFFE8112D);
  static const accent2 = Color(0xFFFF5C6E);
  static const gold = Color(0xFFFFC93C);

  // Named hues the screens use, now inside black / white / red.
  static const pink = Color(0xFFE8112D);
  static const purple = Color(0xFFFF5C6E);
  static const blue = Color(0xFFFFFFFF);
  static const lilac = Color(0xFFFFB3BC);
  static const diamond = Color(0xFFE6E6E6);

  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFA3A3A3);
  static const textFaint = Color(0xFF8A8A8A);

  static const success = Color(0xFF43B966);
  static const danger = Color(0xFFE8112D);
  static const warning = Color(0xFFFFC93C);
}

class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4F1ED);
  static const surface3 = Color(0xFFEBE7E1);
  static const border = Color(0xFFE4E1DD);

  static const primary = Color(0xFFD00F28);
  static const primaryDim = Color(0xFFA00B1F);
  static const accent = Color(0xFFD00F28);
  static const accent2 = Color(0xFFE8112D);
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
    Color(0xFFFF3B52),
    Color(0xFFE8112D),
    Color(0xFFA00B1F),
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

  /// Hero cards: dark red into black, as on Home and Wallet.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A0A12), Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
    stops: [0, 0.55, 1],
  );
}
