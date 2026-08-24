import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/clay_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/glass.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../notifications/notification_bell.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

/// Flat bar (no card/pill background) — avatar->profile, wallet pill,
/// leaderboards, notifications.
class FlingTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FlingTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final clay = ClayColors.of(context);
    return PreferredSize(
      preferredSize: preferredSize,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Avatar(
                      src: user?.avatarUrl,
                      name: user?.name,
                      size: AvatarSize.sm,
                      ring: true,
                      frameId: user?.equippedFrameId),
                ),
                const Spacer(),
                // FittedBox is a safety net, not the primary sizing
                // mechanism — icons render at their normal default size
                // and only shrink if a device is ever too narrow to fit
                // them, instead of silently overflowing off-screen.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const WalletScreen())),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: GlassPanel(
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.monetization_on_rounded,
                                        color: clay.gold, size: 16),
                                    const SizedBox(width: 4),
                                    Text(formatNumber(user?.coinBalance),
                                        style: TextStyle(
                                            color: clay.gold,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Who's on top — gifters/supporters, creators,
                        // users, communities — replaces the old search
                        // icon slot (search still lives on Home's own
                        // search bar, so this wasn't the only way to it).
                        // Glass circle (matching the bottom nav's look)
                        // around the app's own trophy asset instead of a
                        // plain Material glyph on a bare IconButton.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GlassCircleButton(
                            size: 40,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const LeaderboardsScreen())),
                            child: Image.asset(
                                'assets/icons/app/achievement.png',
                                width: 26,
                                height: 26),
                          ),
                        ),
                        // Messages moved to its own bottom-nav slot (was
                        // duplicated here and in the nav) — see app_shell.dart.
                        const NotificationBell(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
