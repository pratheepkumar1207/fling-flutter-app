import 'package:flutter/material.dart';

/// Voice Room's dedicated visual identity — matched to the "ClubRoom"
/// reference app (dark near-black background, mint-green accent), used
/// only for roomType == 'voice' in party_screen.dart/voice_stage_view.dart.
/// Deliberately diverges from the rest of the app's claymorphism/
/// logo-gradient theme (see ClayColors) — an explicit, scoped choice for
/// this one room type, not a global rebrand.
class ClubRoomColors {
  ClubRoomColors._();

  static const bg = Color(0xFF0B0E11);
  static const surface = Color(0xFF151A1F);
  static const surface2 = Color(0xFF1C232A);
  static const surface3 = Color(0xFF242D35);
  static const border = Color(0x1AFFFFFF);

  static const primary = Color(0xFF3ECF8E);
  static const primaryDim = Color(0xFF2FA876);
  static const gold = Color(0xFFFFC94D);
  static const danger = Color(0xFFFF5470);

  static const text = Color(0xFFF5F7F8);
  static const textDim = Color(0xFF9AA5AC);
  static const textFaint = Color(0xFF5C6870);
}
