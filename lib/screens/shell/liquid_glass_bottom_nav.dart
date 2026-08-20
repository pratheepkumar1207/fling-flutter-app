import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/clay_colors.dart';
import '../../theme/glass.dart';

class NavItemData {
  final IconData icon;
  final String label;
  // Custom 3D icon asset shown instead of [icon] when set — see
  // assets/icons/app/. Nav is icon-only (no text label under it), so
  // [label] is kept only as the tooltip/semantic name for accessibility.
  final String? iconAsset;
  const NavItemData(this.icon, this.label, {this.iconAsset});
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
      final item = items[i];
      return Expanded(
        child: Semantics(
          label: item.label,
          button: true,
          selected: selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Center(
              child: item.iconAsset != null
                  // Full-color 3D asset — selection reads via a soft glow/opacity
                  // instead of a tint swap, since these aren't tintable glyphs.
                  ? AnimatedOpacity(
                      opacity: selected ? 1 : 0.55,
                      duration: const Duration(milliseconds: 150),
                      child: Image.asset(item.iconAsset!, width: 52, height: 52),
                    )
                  : Icon(item.icon, size: 24, color: selected ? clay.primary : clay.textFaint),
            ),
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
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  ...List.generate(leftItems.length, (i) => tab(i)),
                  const SizedBox(width: 80), // reserves space under the center button
                  ...List.generate(rightItems.length, (i) => tab(half + i)),
                ],
              ),
              Positioned(
                // The icon asset is already a complete gradient circle
                // button on its own — no extra decoration wrapped around it.
                top: -22,
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
