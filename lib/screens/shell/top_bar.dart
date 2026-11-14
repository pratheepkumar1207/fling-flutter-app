import 'package:flutter/material.dart';
import '../../widgets/insync_brand.dart';
import 'create_sheet.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../notifications/notification_bell.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

/// App bar from the approved design: profile photo, logo and wordmark on the
/// left; coins, rankings, notifications and Messages on the right.
class InsyncTopBar extends StatelessWidget implements PreferredSizeWidget {
  const InsyncTopBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            child: Row(children: [
              Semantics(
                button: true,
                label: 'Your profile',
                child: GestureDetector(
                  onTap: () => push(const ProfileScreen()),
                  child: Avatar(
                      src: user?.avatarUrl,
                      name: user?.name,
                      size: AvatarSize.sm,
                      ring: true,
                      frameId: user?.equippedFrameId),
                ),
              ),
              const SizedBox(width: 10),
              Image.asset('assets/icon/insync-symbol.png',
                  height: 24, semanticLabel: 'Insync'),
              const SizedBox(width: 6),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: InsyncWordmark(size: 20),
                ),
              ),
              // Create: post, reel, story, room or go live.
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  button: true,
                  label: 'Create',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => showCreateSheet(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                          color: const Color(0xFF7C5CFF),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Center(
                          child: InIcon(InIcons.plus,
                              size: 20, color: Colors.white)),
                    ),
                  ),
                ),
              ),
              _CoinPill(
                  coins: user?.coinBalance,
                  onTap: () => push(const WalletScreen())),
              InIconButton(InIcons.trophy,
                  tooltip: 'Leaderboards',
                  size: 38,
                  onPressed: () => push(const LeaderboardsScreen())),
              const NotificationBell(),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "insync" with the purple y, as in the logo.
class InsyncWordmark extends StatelessWidget {
  final double size;
  const InsyncWordmark({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    // Brand wordmark: "in" solid, "sync" in the gradient.
    return InsyncWordmarkText(size: size, inColor: AppColors.text);
  }
}

class _CoinPill extends StatelessWidget {
  final num? coins;
  final VoidCallback onTap;
  const _CoinPill({required this.coins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Wallet, ${formatNumber(coins)} coins',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoinDot(size: 14),
            const SizedBox(width: 5),
            Text(formatNumber(coins),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
          ]),
        ),
      ),
    );
  }
}

/// Gold coin used wherever a coin amount is shown.
class CoinDot extends StatelessWidget {
  final double size;
  const CoinDot({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
        border: Border.all(
            color: const Color(0xFFE6A800), width: (size / 6).clamp(2, 4)),
      ),
    );
  }
}
