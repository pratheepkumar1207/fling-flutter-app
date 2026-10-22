import 'package:flutter/material.dart';
import '../../theme/clay_colors.dart';

class NavItemData {
  final IconData icon;
  final String label;
  final String? iconAsset;
  const NavItemData(this.icon, this.label, {this.iconAsset});
}

/// Stable, labelled destinations with a distinct room-creation action.
class LiquidGlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItemData> items;
  final VoidCallback onCreateTap;
  const LiquidGlassBottomNav(
      {super.key,
      required this.currentIndex,
      required this.onTap,
      required this.items,
      required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final colors = ClayColors.of(context);
    final middle = (items.length / 2).ceil();
    Widget destination(String label, IconData icon, VoidCallback action,
        {bool selected = false, bool create = false}) {
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          child: Tooltip(
            message: label,
            child: InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: create
                          ? colors.accent
                          : selected
                              ? colors.accent.withValues(alpha: 0.14)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: create
                          ? [
                              BoxShadow(
                                  color: colors.accent.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]
                          : null,
                    ),
                    child: Icon(icon,
                        size: 23,
                        color: create
                            ? const Color(0xFF101B35)
                            : selected
                                ? colors.accent
                                : colors.textDim),
                  ),
                  const SizedBox(height: 5),
                  // Shrinks to fit with large system text instead of
                  // cutting off ("Disco…", "Messa…").
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: selected ? colors.accent : colors.textDim,
                            fontWeight: selected || create
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i == middle)
                  destination('Create', Icons.add_rounded, onCreateTap,
                      create: true),
                destination(items[i].label, items[i].icon, () => onTap(i),
                    selected: i == currentIndex),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
