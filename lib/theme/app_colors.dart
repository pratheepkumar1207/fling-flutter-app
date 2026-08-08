import 'package:flutter/material.dart';

/// Mirrors the color tokens in the web app's src/index.css @theme block —
/// keep these two in sync when either changes.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0A0A12);
  static const surface = Color(0xFF15151F);
  static const surface2 = Color(0xFF1E1E2C);
  static const surface3 = Color(0xFF292940);
  static const border = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF4D6D);
  static const primaryDim = Color(0xFFE0435F);
  // Warm coral-orange — replaces an earlier violet accent so the whole
  // palette stays in one pink→orange→gold "sunset" family, no purple.
  static const accent = Color(0xFFFF8A3D);
  static const gold = Color(0xFFFFC94D);
  static const text = Color(0xFFF5F5FA);
  static const textDim = Color(0xFFA8A8BD);
  static const textFaint = Color(0xFF6F6F87);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF43F5E);
  static const warning = Color(0xFFFFC94D);
}
