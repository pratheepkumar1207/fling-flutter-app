import 'package:flutter/material.dart';

/// Watch Party's dedicated visual identity — matched to the "Vola Party"
/// reference app (deep purple-magenta gradient background), used only for
/// roomType == 'watch' in party_screen.dart. Deliberately diverges from
/// the rest of the app's claymorphism/logo-gradient theme (see ClayColors)
/// and from Voice Room's own separate ClubRoom reskin (see
/// club_room_colors.dart) — each room type's look is an explicit, scoped
/// choice here, not a global rebrand.
class VolaPartyColors {
  VolaPartyColors._();

  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D1B4E), Color(0xFF1A0F2E)],
  );

  static const surface = Color(0xFF3A2463);
  static const surface2 = Color(0xFF4A2F7A);
  static const border = Color(0x33FFFFFF);

  static const primary = Color(0xFFE91E8C);
  static const primaryDim = Color(0xFFC0157A);
  static const gold = Color(0xFFF0C419);
  static const danger = Color(0xFFFF4D6D);

  static const text = Color(0xFFF7F3FF);
  static const textDim = Color(0xFFC9B8E8);
  static const textFaint = Color(0xFF8B7AB0);
}
