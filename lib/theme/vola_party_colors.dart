import 'package:flutter/material.dart';

/// Watch Party/Voice/Game's shared "zero color" room look — a neutral,
/// desaturated slate-to-black background instead of the earlier purple-
/// magenta tint, matching the reference Home mockup's backdrop (a plain
/// dark blurred photo, not a colored gradient). Every surface on top of it
/// is real frosted glass (see widgets/glass.dart's GlassPanel), so this
/// class only needs to supply the base background plus the small set of
/// functional accent colors (gold for boost/premium, danger for live-mic/
/// destructive, primary for the send button and other CTAs) that still
/// carry real meaning against the neutral backdrop.
class VolaPartyColors {
  VolaPartyColors._();

  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF203052), Color(0xFF0C1226)],
  );

  static const surface = Color(0xFF16213D);
  static const surface2 = Color(0xFF203052);
  static const border = Color(0x33FFFFFF);

  static const primary = Color(0xFF2455F5);
  static const primaryDim = Color(0xFF6B7280);
  static const gold = Color(0xFFFFD54D);
  static const danger = Color(0xFFFF4D6D);

  static const text = Color(0xFFF4F5F6);
  static const textDim = Color(0xFFADBBD7);
  static const textFaint = Color(0xFF91A1C2);
}
