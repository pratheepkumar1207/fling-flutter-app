import 'package:flutter/material.dart';

/// Voice Room's visual identity — deep purple base with a violet glow,
/// matching the reference "Voice Lobby" look (glowing mic circle, violet
/// speaker rings). Kept as its own class rather than folded into ClayColors
/// since it's tuned for this one room type, not derived from the shared
/// surface tokens.
class ClubRoomColors {
  ClubRoomColors._();

  static const bg = Color(0xFF0B0714);
  static const surface = Color(0xFF1B1330);
  static const surface2 = Color(0xFF241A3F);
  static const surface3 = Color(0xFF2E2350);
  static const border = Color(0x338B5CF6);

  static const primary = Color(0xFF9B5CF6);
  static const primaryDim = Color(0xFF7C3AED);
  static const gold = Color(0xFFFFD54D);
  static const danger = Color(0xFFFF5470);

  static const text = Color(0xFFF5F3FA);
  static const textDim = Color(0xFFB6A9D6);
  static const textFaint = Color(0xFF7C6FA0);
}
