import '../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared card surface from the redesign: a flat dark card with a hairline
/// border. [cobalt] is the hero variant (rose → violet → navy).
BoxDecoration insyncClay({bool cobalt = false, double radius = 24}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius.clamp(0, 22).toDouble()),
      color: cobalt ? null : AppColors.surface,
      gradient: cobalt ? AppGradients.hero : null,
      border: Border.all(
          color: cobalt ? const Color(0xFF3A2A55) : AppColors.border),
    );

class InsyncClayIcon extends StatelessWidget {
  final InIconData icon;
  final double size;
  const InsyncClayIcon(this.icon, {super.key, this.size = 54});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: const Color(0xFF1F1A2C),
              borderRadius: BorderRadius.circular(size * .32)),
          child: InIcon(icon, size: size * .5, color: AppColors.lilac)));
}

class InsyncSectionBanner extends StatelessWidget {
  final String title, subtitle;
  final InIconData icon;
  final bool compact;
  const InsyncSectionBanner(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: insyncClay(cobalt: true, radius: 22),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: Color(0xFFCFC6E6), fontSize: 13, height: 1.45)),
        ])),
        const SizedBox(width: 14),
        InsyncClayIcon(icon, size: compact ? 48 : 62)
      ]));
}

/// Page title for app bars; shrinks to leave room for actions. [icon] is
/// kept for callers that show it elsewhere.
class InsyncPageTitle extends StatelessWidget {
  final String title;
  const InsyncPageTitle(this.title, {super.key});
  InIconData get icon {
    final key = title.toLowerCase();
    if (key.contains('wallet') ||
        key.contains('coin') ||
        key.contains('cash')) {
      return InIcons.wallet;
    }
    if (key.contains('game')) return InIcons.game;
    if (key.contains('message') || key.contains('chat')) {
      return InIcons.chat;
    }
    if (key.contains('friend') ||
        key.contains('communit') ||
        key.contains('invite')) {
      return InIcons.community;
    }
    if (key.contains('profile') || key.contains('account')) {
      return InIcons.user;
    }
    if (key.contains('event')) return InIcons.calendar;
    if (key.contains('leader') ||
        key.contains('achievement') ||
        key.contains('challenge')) {
      return InIcons.trophy;
    }
    if (key.contains('notification')) return InIcons.bell;
    if (key.contains('setting') || key.contains('preference')) {
      return InIcons.tune;
    }
    if (key.contains('search') || key.contains('discover')) {
      return InIcons.globe;
    }
    return InIcons.spark;
  }

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        // Plain title, as in the design (the emblem was the old look).
        // Shrinks a little to fit next to app-bar actions instead of being
        // cut off ("Co…" for Communities).
        Flexible(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(title,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.3)))),
      ]);
}
