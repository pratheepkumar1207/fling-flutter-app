import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme-aware clay design tokens — the values [ClaySurface] and other
/// shared widgets read via `Theme.of(context).extension<ClayColors>()`, so
/// they automatically flip between the light and dark clay palettes
/// without every call site needing its own light/dark branch.
class ClayColors extends ThemeExtension<ClayColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color primary;
  final Color primaryDim;
  final Color accent;
  final Color gold;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color success;
  final Color danger;
  final Color warning;
  final Color shadowLight;
  final Color shadowDark;
  final List<Color> gradient;

  const ClayColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.primary,
    required this.primaryDim,
    required this.accent,
    required this.gold,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.success,
    required this.danger,
    required this.warning,
    required this.shadowLight,
    required this.shadowDark,
    required this.gradient,
  });

  /// Dark clay: glassy purple cards with a soft violet glow highlight and a
  /// near-black shadow, matching the reference's glowing-card look.
  /// GlassSurface applies its own alpha via .withValues() (overwriting
  /// whatever alpha is set here), so the actual translucency happens there —
  /// these just carry the RGB tint.
  static const dark = ClayColors(
    bg: AppColors.bg,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    border: AppColors.border,
    primary: AppColors.primary,
    primaryDim: AppColors.primaryDim,
    accent: AppColors.accent,
    gold: AppColors.gold,
    text: AppColors.text,
    textDim: AppColors.textDim,
    textFaint: AppColors.textFaint,
    success: AppColors.success,
    danger: AppColors.danger,
    warning: AppColors.warning,
    shadowLight: Color(0xFF6B4AA8),
    shadowDark: Color(0xFF000000),
    gradient: AppGradients.brand,
  );

  /// Light clay: true white highlight, soft violet "dark" shadow.
  static const light = ClayColors(
    bg: AppColorsLight.bg,
    surface: AppColorsLight.surface,
    surface2: AppColorsLight.surface2,
    surface3: AppColorsLight.surface3,
    border: AppColorsLight.border,
    primary: AppColorsLight.primary,
    primaryDim: AppColorsLight.primaryDim,
    accent: AppColorsLight.accent,
    gold: AppColorsLight.gold,
    text: AppColorsLight.text,
    textDim: AppColorsLight.textDim,
    textFaint: AppColorsLight.textFaint,
    success: AppColorsLight.success,
    danger: AppColorsLight.danger,
    warning: AppColorsLight.warning,
    shadowLight: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFB49BDD),
    gradient: AppGradients.brand,
  );

  @override
  ClayColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? primary,
    Color? primaryDim,
    Color? accent,
    Color? gold,
    Color? text,
    Color? textDim,
    Color? textFaint,
    Color? success,
    Color? danger,
    Color? warning,
    Color? shadowLight,
    Color? shadowDark,
    List<Color>? gradient,
  }) {
    return ClayColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryDim: primaryDim ?? this.primaryDim,
      accent: accent ?? this.accent,
      gold: gold ?? this.gold,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      textFaint: textFaint ?? this.textFaint,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      shadowLight: shadowLight ?? this.shadowLight,
      shadowDark: shadowDark ?? this.shadowDark,
      gradient: gradient ?? this.gradient,
    );
  }

  @override
  ClayColors lerp(ThemeExtension<ClayColors>? other, double t) {
    if (other is! ClayColors) return this;
    return ClayColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      text: Color.lerp(text, other.text, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      shadowLight: Color.lerp(shadowLight, other.shadowLight, t)!,
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t)!,
      gradient: t < 0.5 ? gradient : other.gradient,
    );
  }

  /// Shorthand for `Theme.of(context).extension<ClayColors>()!`.
  static ClayColors of(BuildContext context) => Theme.of(context).extension<ClayColors>()!;
}
