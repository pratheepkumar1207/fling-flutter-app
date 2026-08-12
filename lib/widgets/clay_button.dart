import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/clay_colors.dart';

/// Primary CTA pill filled with the insync brand gradient (pink -> purple
/// -> blue) plus a soft clay shadow — the Instagram-style "gradient
/// button" treatment. Use for the one or two most important actions on a
/// screen; everything else should stay on the theme's flat ElevatedButton.
class ClayGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const ClayGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
  });

  @override
  Widget build(BuildContext context) {
    final clay = ClayColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppGradients.brand),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: clay.shadowDark.withValues(alpha: isDark ? 0.45 : 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
