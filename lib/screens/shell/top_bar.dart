import 'package:flutter/material.dart';
import '../../core/live_now.dart';
import '../live/live_feed_screen.dart';
import '../../widgets/insync_brand.dart';
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
import '../tournaments/tournaments_list_screen.dart';

/// App bar from the approved design: profile photo, logo and wordmark on the
/// left; coins, rankings, notifications and Messages on the right.
class InsyncTopBar extends StatelessWidget implements PreferredSizeWidget {
  // Popcorn tab: the red live button (opens the live feed).
  final bool showLive;
  // Popcorn tab, newer layout: no separate logo symbol (the name is the
  // logo), Tournament where Live was, and no + (the bottom bar's centre +
  // creates rooms there; Go live is the first card in the live row).
  final bool popcorn;
  const InsyncTopBar({super.key, this.showLive = false, this.popcorn = false});
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
              if (!popcorn) ...[
                Image.asset('assets/icon/insync-symbol.png',
                    height: 24, semanticLabel: 'Insync'),
                const SizedBox(width: 6),
              ],
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: InsyncWordmark(size: 20),
                ),
              ),
              if (showLive)
                ValueListenableBuilder<int>(
                  valueListenable: liveNowCount,
                  builder: (context, n, _) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Semantics(
                      button: true,
                      label: n > 0 ? 'Live now, $n' : 'Live',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => push(Scaffold(
                          backgroundColor: Colors.black,
                          // The live screen has its own "Live" header.
                          appBar: AppBar(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              toolbarHeight: 44),
                          body: const LiveFeedScreen(),
                        )),
                        child: SizedBox(
                          width: 36,
                          height: 32,
                          child: Stack(clipBehavior: Clip.none, children: [
                            Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: n > 0
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF3A3A40),
                                  boxShadow: n > 0
                                      ? const [
                                          BoxShadow(
                                              color: Color(0x40E53935),
                                              spreadRadius: 4)
                                        ]
                                      : null,
                                ),
                                child: const Center(
                                    child: InIcon(InIcons.live,
                                        size: 16, color: Colors.white)),
                              ),
                            ),
                            if (n > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(7)),
                                  child: Text(n > 99 ? '99+' : '$n',
                                      style: const TextStyle(
                                          color: Color(0xFFE53935),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              if (popcorn)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Semantics(
                    button: true,
                    label: 'Tournaments',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => push(const TournamentsListScreen()),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2A2140), shape: BoxShape.circle),
                        child: const Center(
                            child: InIcon(InIcons.swords,
                                size: 18, color: Color(0xFFC9A6FF))),
                      ),
                    ),
                  ),
                ),
              // No + here: on Home, swipe left to right for the camera
              // (post, story, reel, live); on Popcorn the bottom bar's
              // centre + creates a room.
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
