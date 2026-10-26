import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';

class NavItemData {
  final InIconData icon;
  final String label;

  /// Small pink tag on the icon (the Live tab's "LIVE").
  final String? tag;
  const NavItemData(this.icon, this.label, {this.tag});
}

/// Bottom bar from the approved design: four labelled tabs with the
/// gradient "+" in the middle; the selected tab gets white text and a pink
/// dot underneath.
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
    final middle = (items.length / 2).ceil();
    return Material(
      color: const Color(0xF50E0C14),
      child: DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF1E1B27)))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i == middle) _CreateButton(onTap: onCreateTap),
                Expanded(
                  child: _Tab(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final NavItemData item;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.text : AppColors.textFaint;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              InIcon(item.icon, size: 23, color: color),
              if (item.tag != null)
                Positioned(
                  top: -6,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: AppColors.pink,
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(item.tag!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            // Shrinks with large system text instead of cutting off.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(item.label,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500)),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.pink : Colors.transparent),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      // heightFactor keeps the bar its own height; a plain Center would
      // stretch it to fill the screen inside bottomNavigationBar.
      child: Center(
        heightFactor: 1,
        child: Semantics(
          button: true,
          label: 'Create',
          child: Tooltip(
            message: 'Create',
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                    gradient: AppGradients.brandDiagonal,
                    borderRadius: BorderRadius.circular(16)),
                child: const Center(
                    child: InIcon(InIcons.plus, size: 24, color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
