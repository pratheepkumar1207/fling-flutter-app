import 'package:flutter/material.dart';

/// Dark-mode palette — matches the Claude Design redesign: a deep
/// charcoal-violet ground (not literal black/purple), a coral-to-violet
/// brand gradient reserved for stories/matches/primary actions, and a warm
/// gold accent for coins/VIP. Derived from the design canvas's oklch tokens
/// (--bg:oklch(13% .014 280) etc.) — see fling-redesign design canvas.
/// success/danger stay as functional status signals regardless of brand
/// color. See AppColorsLight for the light-mode sibling.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF17141F);
  static const surface = Color(0xFF201C2A);
  static const surface2 = Color(0xFF282433);
  static const surface3 = Color(0xFF322D3F);
  static const border = Color(0xFF3B3547);

  static const primary = Color(0xFFB0509A);
  static const primaryDim = Color(0xFF8E3C81);
  static const accent = Color(0xFFE04D6B);
  static const accent2 = Color(0xFFA24FE0);
  static const gold = Color(0xFFD9AC55);

  static const text = Color(0xFFF3F1F5);
  static const textDim = Color(0xFFBDB7C6);
  static const textFaint = Color(0xFF7E7889);

  static const success = Color(0xFF3FBE7E);
  static const danger = Color(0xFFE2493F);
  static const warning = Color(0xFFD9AC55);
}

/// Light-mode palette — warm off-white ground, same coral/violet identity.
class AppColorsLight {
  AppColorsLight._();

  static const bg = Color(0xFFFAF9F7);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4F2EF);
  static const surface3 = Color(0xFFEAE7E3);
  static const border = Color(0xFFE6E2DD);

  static const primary = Color(0xFFC24880);
  static const primaryDim = Color(0xFFA83A6E);
  static const accent = Color(0xFFE8506B);
  static const accent2 = Color(0xFF9B4FDE);
  static const gold = Color(0xFFCB9A3E);

  static const text = Color(0xFF2B2724);
  static const textDim = Color(0xFF6E6864);
  static const textFaint = Color(0xFFA39D98);

  static const success = Color(0xFF3FAE73);
  static const danger = Color(0xFFD93B3B);
  static const warning = Color(0xFFCB9A3E);
}

/// Brand gradient — coral-to-violet, used for the avatar story-ring, CTAs
/// and other decorative accents. Matches the design canvas's `--grad`
/// token: linear-gradient(135deg, coral, violet).
class AppGradients {
  AppGradients._();

  static const List<Color> brand = [
    Color(0xFFF0576A),
    Color(0xFF9B4DE0),
  ];

  static const LinearGradient brandDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brand,
  );

  /// Primary CTA pill gradient — same coral-to-violet brand gradient, for
  /// buttons like "Create Room" / "Upgrade Now" / the floating "+" action.
  static const List<Color> volaCta = brand;

  static const LinearGradient volaCtaDiagonal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: volaCta,
  );
}
