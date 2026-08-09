import 'package:flutter/material.dart';

/// Mirrors the color tokens in the web app's src/index.css @theme block —
/// keep these two in sync when either changes.
class AppColors {
  AppColors._();

  // Flat matte dark — Spotify-reference palette. Neutral greys (no blue
  // undertone) instead of the earlier glass-purple-leaning surfaces.
  static const bg = Color(0xFF121212);
  static const surface = Color(0xFF181818);
  static const surface2 = Color(0xFF212121);
  static const surface3 = Color(0xFF2A2A2A);
  static const border = Color(0x14FFFFFF);
  // Brand green (distinct from Spotify's own trademark shade) replaces the
  // earlier pink primary.
  static const primary = Color(0xFF1ED760);
  static const primaryDim = Color(0xFF14A84A);
  static const accent = Color(0xFF0EA5A0);
  static const gold = Color(0xFFFFC94D);
  static const text = Color(0xFFF5F5FA);
  static const textDim = Color(0xFFA8A8BD);
  static const textFaint = Color(0xFF6F6F87);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF43F5E);
  static const warning = Color(0xFFFFC94D);
}
