import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'clay_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark, ClayColors.dark);
  static ThemeData get light => _build(Brightness.light, ClayColors.light);

  /// Bricolage Grotesque for display/heading text, Plus Jakarta Sans for
  /// body text — the type pairing from the Claude Design redesign
  /// (--font-d / --font-b in the design canvas tokens).
  static TextTheme _textTheme(Brightness brightness, Color bodyColor) {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    ).apply(bodyColor: bodyColor, displayColor: bodyColor);
    final display = GoogleFonts.bricolageGrotesqueTextTheme(base);
    return base.copyWith(
      displayLarge: display.displayLarge,
      displayMedium: display.displayMedium,
      displaySmall: display.displaySmall,
      headlineLarge: display.headlineLarge,
      headlineMedium: display.headlineMedium,
      headlineSmall: display.headlineSmall,
      titleLarge: display.titleLarge,
      titleMedium: display.titleMedium,
    );
  }

  static ThemeData _build(Brightness brightness, ClayColors clay) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: clay.bg,
      primaryColor: clay.primary,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [clay],
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: clay.primary,
        secondary: clay.accent,
        surface: clay.surface,
        onSurface: clay.text,
        onPrimary: Colors.white,
        onSecondary: const Color(0xFF101B35),
        error: clay.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: clay.bg,
        foregroundColor: clay.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          color: clay.text,
          fontWeight: FontWeight.w700,
          fontSize: 19,
        ),
      ),
      cardColor: clay.surface2,
      cardTheme: CardThemeData(
        color: clay.surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: clay.accent,
              foregroundColor: const Color(0xFF101B35),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)))),
      dialogTheme: DialogThemeData(
          backgroundColor: clay.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: clay.surface,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      chipTheme: base.chipTheme.copyWith(
          backgroundColor: clay.surface2,
          selectedColor: clay.primary,
          labelStyle: TextStyle(color: clay.text),
          side: BorderSide(color: clay.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      listTileTheme: ListTileThemeData(
          iconColor: clay.accent,
          textColor: clay.text,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4)),
      dividerColor: clay.border,
      textTheme: _textTheme(brightness, clay.text),
      iconTheme: IconThemeData(color: clay.textDim),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: clay.surface,
        hintStyle: TextStyle(color: clay.textDim),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: clay.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: clay.primary,
          // clay.primary is a vivid purple in both modes, so white text
          // reads correctly against it — this only broke during the
          // brief literal-monochrome palette (primary went pure white),
          // which is no longer in use.
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
