import 'package:flutter/material.dart';
import 'clay_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark, ClayColors.dark);
  static ThemeData get light => _build(Brightness.light, ClayColors.light);

  static ThemeData _build(Brightness brightness, ClayColors clay) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: clay.bg,
      primaryColor: clay.primary,
      extensions: [clay],
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: clay.primary,
        secondary: clay.accent,
        surface: clay.surface,
        error: clay.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: clay.surface.withValues(alpha: 0.85),
        foregroundColor: clay.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardColor: clay.surface2,
      cardTheme: CardThemeData(
        color: clay.surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dividerColor: clay.border,
      textTheme: base.textTheme.apply(bodyColor: clay.text, displayColor: clay.text),
      iconTheme: IconThemeData(color: clay.textDim),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: clay.surface,
        hintStyle: TextStyle(color: clay.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: clay.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: clay.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: clay.surface,
        selectedItemColor: clay.primary,
        unselectedItemColor: clay.textDim,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: clay.surface3,
        contentTextStyle: TextStyle(color: clay.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
