import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'clay_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark, ClayColors.dark);
  static ThemeData get light => _build(Brightness.light, ClayColors.light);

  /// The dark theme with the platform font instead of Plus Jakarta Sans,
  /// for widget tests (which can't fetch fonts).
  @visibleForTesting
  static ThemeData darkWithoutWebFonts() => _build(
      Brightness.dark, ClayColors.dark,
      textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: ClayColors.dark.text, displayColor: ClayColors.dark.text));

  /// Plus Jakarta Sans throughout; headings use the heavier weights.
  static TextTheme _textTheme(Brightness brightness, Color bodyColor) {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    ).apply(bodyColor: bodyColor, displayColor: bodyColor);
    final display = GoogleFonts.plusJakartaSansTextTheme(base);
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

  static ThemeData _build(Brightness brightness, ClayColors clay,
      {TextTheme? textTheme}) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    textTheme ??= _textTheme(brightness, clay.text);
    // Button labels must carry the font family explicitly — a bare
    // TextStyle here falls back to the platform font.
    final buttonText = textTheme.labelLarge!
        .copyWith(fontWeight: FontWeight.w600, fontSize: 15);
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
        onSecondary: Colors.white,
        error: clay.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: clay.bg,
        foregroundColor: clay.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
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
              backgroundColor: clay.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
              textStyle: buttonText,
              shape: const StadiumBorder())),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: clay.text,
              backgroundColor: clay.surface,
              side: BorderSide(color: clay.border),
              minimumSize: const Size(48, 48),
              textStyle: buttonText,
              shape: const StadiumBorder())),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: AppColors.lilac,
              textStyle: buttonText.copyWith(fontSize: 14))),
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
          labelStyle: textTheme.labelLarge
              ?.copyWith(color: clay.text, fontWeight: FontWeight.w500),
          side: BorderSide(color: clay.border),
          shape: const StadiumBorder()),
      listTileTheme: ListTileThemeData(
          iconColor: AppColors.lilac,
          textColor: clay.text,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4)),
      dividerColor: clay.border,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: clay.textDim),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: clay.surface,
        hintStyle: TextStyle(color: clay.textDim),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: clay.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: clay.border),
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
          shape: const StadiumBorder(),
          textStyle: buttonText,
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
