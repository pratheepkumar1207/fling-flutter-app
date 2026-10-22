import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/clay_colors.dart';
import '../../widgets/avatar.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../notifications/notification_bell.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

class FlingTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FlingTopBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final colors = ClayColors.of(context);
    return Material(
      color: colors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 64,
            child: Row(children: [
              IconButton(
                tooltip: 'Your profile',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
                icon: Avatar(
                    src: user?.avatarUrl,
                    name: user?.name,
                    size: AvatarSize.sm,
                    frameId: user?.equippedFrameId),
              ),
              const SizedBox(width: 8),
              // Shrinks to fit rather than "Insy…" with large system text.
              Expanded(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Insync',
                          maxLines: 1,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8)))),
              Tooltip(
                message: 'Wallet',
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      backgroundColor: colors.surface2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletScreen())),
                  icon: Icon(Icons.toll_rounded, size: 18, color: colors.gold),
                  label: Text(formatNumber(user?.coinBalance),
                      style: TextStyle(color: colors.text)),
                ),
              ),
              IconButton(
                  tooltip: 'Leaderboards',
                  icon: const Icon(Icons.emoji_events_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LeaderboardsScreen()))),
              const NotificationBell(),
            ]),
          ),
        ),
      ),
    );
  }
}
