import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';

class NavItemData {
  final String icon;
  final String label;
  const NavItemData(this.icon, this.label);
}

/// Liquid-glass pill nav with a "meniscus" bead that melts from tab to
/// tab — Flutter port of layout/BottomNav.jsx's redesign. Segment widths
/// come from LayoutBuilder (equal columns) rather than percentage CSS, but
/// the visual result — a glass pill, a soft bead sliding under the active
/// tab with a spring overshoot — matches.
class LiquidGlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItemData> items;

  const LiquidGlassBottomNav({super.key, required this.currentIndex, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(999),
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = (constraints.maxWidth - 12) / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 520),
                      curve: kSpringCurve,
                      left: currentIndex * segmentWidth,
                      top: 0,
                      bottom: 0,
                      width: segmentWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(items.length, (i) {
                        final selected = i == currentIndex;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  duration: const Duration(milliseconds: 500),
                                  curve: kSpringCurve,
                                  scale: selected ? 1.15 : 1.0,
                                  child: Text(items[i].icon, style: const TextStyle(fontSize: 18)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  items[i].label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: selected ? AppColors.primary : AppColors.textFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
