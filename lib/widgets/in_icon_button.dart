import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

/// Round icon button in the Insync line style, with an optional pink count
/// badge (top bar bell and Messages, room header people icon…).
class InIconButton extends StatelessWidget {
  final InIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int badge;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final bool border;

  const InIconButton(this.icon,
      {super.key,
      required this.tooltip,
      this.onPressed,
      this.badge = 0,
      this.size = 40,
      this.iconSize = 22,
      this.color,
      this.background,
      this.border = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: badge > 0 ? '$tooltip, $badge new' : tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: size * 0.6,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: background,
                    border: border ? Border.all(color: AppColors.border) : null,
                  ),
                  child: Center(
                      child: InIcon(icon,
                          size: iconSize, color: color ?? AppColors.text)),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: size * 0.08,
                  right: size * 0.06,
                  child: CountBadge(badge),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: AppColors.pink, borderRadius: BorderRadius.circular(999)),
      alignment: Alignment.center,
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1)),
    );
  }
}
