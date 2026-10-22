import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared sculpted surfaces for the cobalt and lime identity.
BoxDecoration insyncClay({bool cobalt = false, double radius = 24}) =>
    BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cobalt
                ? const [Color(0xFF396AFF), Color(0xFF1941CE)]
                : const [Color(0xFF24365D), Color(0xFF16213D)]),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 16,
              offset: const Offset(3, 7)),
          BoxShadow(
              color: const Color(0xFF7295FF).withValues(alpha: .07),
              blurRadius: 10,
              offset: const Offset(-3, -3))
        ]);

class InsyncClayIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const InsyncClayIcon(this.icon, {super.key, this.size = 54});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Container(
          width: size,
          height: size,
          decoration: insyncClay(cobalt: true, radius: size * .3),
          child: Icon(icon,
              size: size * .55,
              color: AppColors.accent,
              shadows: const [
                Shadow(
                    color: Color(0xFF102363),
                    offset: Offset(2, 4),
                    blurRadius: 2)
              ])));
}

class InsyncSectionBanner extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
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
      decoration: insyncClay(cobalt: !compact),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 20 : 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: Color(0xFFD8E3FF), fontSize: 12, height: 1.5)),
        ])),
        const SizedBox(width: 14),
        InsyncClayIcon(icon, size: compact ? 48 : 62)
      ]));
}

/// Compact route heading with a sculpted emblem; leaves room for app-bar actions.
class InsyncPageTitle extends StatelessWidget {
  final String title;
  const InsyncPageTitle(this.title, {super.key});
  IconData get icon {
    final key = title.toLowerCase();
    if (key.contains('wallet') || key.contains('coin') || key.contains('cash')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (key.contains('game')) return Icons.sports_esports_rounded;
    if (key.contains('message') || key.contains('chat')) {
      return Icons.forum_rounded;
    }
    if (key.contains('friend') ||
        key.contains('communit') ||
        key.contains('invite')) {
      return Icons.groups_rounded;
    }
    if (key.contains('profile') || key.contains('account')) {
      return Icons.person_rounded;
    }
    if (key.contains('event')) return Icons.event_rounded;
    if (key.contains('leader') ||
        key.contains('achievement') ||
        key.contains('challenge')) {
      return Icons.emoji_events_rounded;
    }
    if (key.contains('notification')) return Icons.notifications_rounded;
    if (key.contains('setting') || key.contains('preference')) {
      return Icons.tune_rounded;
    }
    if (key.contains('search') || key.contains('discover')) {
      return Icons.explore_rounded;
    }
    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        InsyncClayIcon(icon, size: 32),
        const SizedBox(width: 10),
        // Shrinks a little to fit next to app-bar actions instead of being
        // cut off ("Co…" for Communities).
        Flexible(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(title,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4)))),
      ]);
}
