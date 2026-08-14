import 'package:flutter/material.dart';

/// Voice Room's visual identity — matches the app's global monochrome
/// palette now (previously a mint-green accent, before the app-wide
/// black-and-white pass). Kept as its own class rather than folded into
/// ClayColors since it's still a distinct near-black base tuned for this
/// one room type, not derived from the shared surface tokens.
class ClubRoomColors {
  ClubRoomColors._();

  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF161616);
  static const surface2 = Color(0xFF1E1E1E);
  static const surface3 = Color(0xFF262626);
  static const border = Color(0x1AFFFFFF);

  static const primary = Color(0xFFFFFFFF);
  static const primaryDim = Color(0xFFB3B3B3);
  static const gold = Color(0xFFCCCCCC);
  static const danger = Color(0xFFFF5470);

  static const text = Color(0xFFF5F5F5);
  static const textDim = Color(0xFFA0A0A0);
  static const textFaint = Color(0xFF666666);
}
