import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../messages/messages_screen.dart';
import '../notifications/notification_bell.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

/// App bar from the approved design: profile photo, logo and wordmark on the
/// left; coins, rankings, notifications and Messages on the right.
class FlingTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FlingTopBar({super.key});
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
              _CoinPill(
                  coins: user?.coinBalance,
                  onTap: () => push(const WalletScreen())),
              InIconButton(InIcons.trophy,
                  tooltip: 'Leaderboards',
                  size: 38,
                  onPressed: () => push(const LeaderboardsScreen())),
              const NotificationBell(),
              const _MessagesButton(),
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
    final base = TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: AppColors.text);
    return Text.rich(
      TextSpan(style: base, children: const [
        TextSpan(text: 'ins'),
        TextSpan(text: 'y', style: TextStyle(color: Color(0xFFC268F2))),
        TextSpan(text: 'nc'),
      ]),
      maxLines: 1,
    );
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

/// Messages moved from the bottom bar into the top bar; badge is the total
/// unread across conversations, refreshed on new DMs and on return.
class _MessagesButton extends StatefulWidget {
  const _MessagesButton();

  @override
  State<_MessagesButton> createState() => _MessagesButtonState();
}

class _MessagesButtonState extends State<_MessagesButton> {
  int _unread = 0;
  bool _bound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
    if (!_bound) {
      final socket = context.read<SocketService>().socket;
      if (socket != null) {
        _bound = true;
        socket.on('dm:message', (_) => _load());
        socket.on('group:message', (_) => _load());
      }
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/messages/conversations'),
        ApiClient.get('/groups').catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      var total = 0;
      for (final list in results) {
        if (list is! List) continue;
        for (final c in list) {
          if (c is Map) total += (c['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }
      setState(() => _unread = total);
    } catch (_) {
      // Badge is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    return InIconButton(
      InIcons.chat,
      tooltip: 'Messages',
      size: 38,
      badge: _unread,
      onPressed: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MessagesScreen()));
        _load();
      },
    );
  }
}
