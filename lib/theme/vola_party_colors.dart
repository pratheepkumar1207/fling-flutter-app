import 'package:flutter/material.dart';

/// Watch Party's visual identity — matches the app's global monochrome
/// palette now (previously a deep purple-magenta gradient, before the
/// app-wide black-and-white pass). Kept as its own class since it's still
/// a distinct dark-gradient base tuned for this one room type.
class VolaPartyColors {
  VolaPartyColors._();

  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF262626), Color(0xFF0A0A0A)],
  );

  static const surface = Color(0xFF262626);
  static const surface2 = Color(0xFF303030);
  static const border = Color(0x33FFFFFF);

  static const primary = Color(0xFFFFFFFF);
  static const primaryDim = Color(0xFFB3B3B3);
  static const gold = Color(0xFFCCCCCC);
  static const danger = Color(0xFFFF4D6D);

  static const text = Color(0xFFF5F5F5);
  static const textDim = Color(0xFFC0C0C0);
  static const textFaint = Color(0xFF808080);
}
