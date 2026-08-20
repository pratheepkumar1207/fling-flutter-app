import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/theme_controller.dart';
import '../../theme/clay_colors.dart';
import '../../widgets/avatar.dart';
import '../messages/messages_screen.dart';
import '../notifications/notification_bell.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../wallet/wallet_screen.dart';

/// Flat bar (no card/pill background) — avatar->profile, wallet pill,
/// theme toggle, search, messages, notifications.
class FlingTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FlingTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final clay = ClayColors.of(context);
    final themeController = context.watch<ThemeController>();
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
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Avatar(src: user?.avatarUrl, name: user?.name, size: AvatarSize.sm, ring: true, frameId: user?.equippedFrameId),
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
                        IconButton(
                          tooltip: themeController.isDark ? 'Switch to light' : 'Switch to dark',
                          icon: Icon(
                            themeController.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: clay.textDim,
                          ),
                          onPressed: () => themeController.toggle(),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: clay.surface3,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: clay.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.monetization_on_rounded, color: clay.gold, size: 16),
                                const SizedBox(width: 4),
                                Text(formatNumber(user?.coinBalance), style: TextStyle(color: clay.gold, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Image.asset('assets/icons/app/search.png', width: 44, height: 44),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
                        ),
                        IconButton(
                          icon: Image.asset('assets/icons/app/message.png', width: 44, height: 44),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
                        ),
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
