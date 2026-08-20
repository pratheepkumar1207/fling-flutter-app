import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/clay_colors.dart';
import '../../theme/glass.dart';

class NavItemData {
  final IconData icon;
  final String label;
  const NavItemData(this.icon, this.label);
}

/// Flat bottom nav (no pill/card background) — a plain bar with the
/// active tab highlighted by its own icon/label color. The "create room"
/// action lives as a raised circle centered in the bar itself (split the
/// tabs into two even halves either side of it) instead of a separately
/// floating Scaffold FAB.
class LiquidGlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItemData> items;
  final VoidCallback onCreateTap;

  const LiquidGlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final clay = ClayColors.of(context);
    final half = (items.length / 2).ceil();
    final leftItems = items.take(half).toList();
    final rightItems = items.skip(half).toList();

    Widget tab(int i) {
      final selected = i == currentIndex;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(items[i].icon, size: 22, color: selected ? clay.primary : clay.textFaint),
              const SizedBox(height: 2),
              Text(
                items[i].label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: selected ? clay.primary : clay.textFaint),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: clay.bg, border: Border(top: BorderSide(color: clay.border))),
      child: SafeArea(
        top: false,
        // Clip.none so the center button can pop up above the bar's own
        // top edge without getting clipped by this SizedBox.
        child: SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  ...List.generate(leftItems.length, (i) => tab(i)),
                  const SizedBox(width: 64), // reserves space under the center button
                  ...List.generate(rightItems.length, (i) => tab(half + i)),
                ],
              ),
              Positioned(
                top: -14,
                child: GestureDetector(
                  onTap: onCreateTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: clay.bg, width: 3)),
                      ),
                      GlassIcon.circle(
                        size: 50,
                        colors: AppGradients.volaCta,
                        glowColor: AppColors.primary.withValues(alpha: 0.5),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
