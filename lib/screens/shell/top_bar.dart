import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      backgroundColor: AppColors.surface2.withValues(alpha: 0.55),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Avatar(src: user?.avatarUrl, name: user?.name, size: AvatarSize.sm),
          ),
          const SizedBox(width: 10),
          const Text('Fling', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 20)),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('🪙 ${formatNumber(user?.coinBalance)}', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        IconButton(
          icon: const Text('🔍'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        IconButton(
          icon: const Text('💬'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
        ),
        const NotificationBell(),
        const SizedBox(width: 4),
      ],
    );
  }
}
