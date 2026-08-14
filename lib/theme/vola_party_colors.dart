import 'package:flutter/material.dart';

/// Watch Party's visual identity — deep purple-magenta gradient, matching
/// the reference "Movie Lobby / Music Lobby" look (glowing violet cards over
/// a near-black purple base). Kept as its own class since it's tuned
/// specifically for this room type rather than reusing the global tokens
/// directly.
class VolaPartyColors {
  VolaPartyColors._();

  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1B4A), Color(0xFF0B0714)],
  );

  static const surface = Color(0xFF241A3F);
  static const surface2 = Color(0xFF2E2350);
  static const border = Color(0x408B5CF6);

  static const primary = Color(0xFFEC4899);
  static const primaryDim = Color(0xFF9B5CF6);
  static const gold = Color(0xFFFFD54D);
  static const danger = Color(0xFFFF4D6D);

  static const text = Color(0xFFF5F3FA);
  static const textDim = Color(0xFFB6A9D6);
  static const textFaint = Color(0xFF7C6FA0);
}
