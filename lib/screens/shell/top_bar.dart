import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/avatar.dart';
import '../messages/messages_screen.dart';
import '../notifications/notification_bell.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../wallet/wallet_screen.dart';

/// Mirrors src/layout/TopBar.jsx — avatar->profile, wallet pill, search,
/// messages, notifications, in the same order.
class FlingTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FlingTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return PreferredSize(
      preferredSize: preferredSize,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Avatar(src: user?.avatarUrl, name: user?.name, size: AvatarSize.sm),
                  ),
                  const SizedBox(width: 10),
                  const Text('Fling', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 20)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 16),
                          const SizedBox(width: 4),
                          Text(formatNumber(user?.coinBalance), style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: AppColors.textDim),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.textDim),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
