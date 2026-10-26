import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import 'wallet_buy_screen.dart';
import 'wallet_cashout_screen.dart';
import 'wallet_kyc_screen.dart';
import 'spin_wheel_screen.dart';
import 'livestream_dashboard_screen.dart';
import 'referral_screen.dart';
import 'vip_store_screen.dart';
import '../shell/top_bar.dart' show CoinDot;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _kycStatus;
  bool _activityLoading = true;
  List<Map<String, dynamic>> _activity = [];

  @override
  void initState() {
    super.initState();
    _loadKyc();
    _loadActivity();
  }

  Future<void> _loadKyc() async {
    try {
      final data = await ApiClient.get('/kyc/status') as Map<String, dynamic>;
      if (mounted) {
        setState(() => _kycStatus = data['status'] as String? ?? 'none');
      }
    } catch (_) {}
  }

  Future<void> _loadActivity() async {
    try {
      final data = await ApiClient.get('/wallet/transactions');
      if (mounted) {
        setState(() {
          _activity = (data as List).cast<Map<String, dynamic>>();
          _activityLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  String _activityTitle(Map<String, dynamic> t) {
    final type = t['type'] as String?;
    final relatedName = t['relatedUserName'] as String?;
    final giftType = t['giftType'] as String?;
    return switch (type) {
      'buy' => 'Bought coins',
      'gift_sent' =>
        relatedName != null ? 'Gift to $relatedName' : 'Sent a gift',
      'gift_received' => giftType == 'spin_wheel'
          ? 'Daily spin'
          : (relatedName != null
              ? '${_titleCase(giftType)} from $relatedName'
              : 'Received a gift'),
      'cashout_requested' => 'Cash out requested',
      'cashout_paid' => 'Cash out to bank',
      'username_change' => 'Username change',
      'reverse_swipe' => 'Undo swipe',
      _ => 'Transaction',
    };
  }

  String _titleCase(String? s) {
    if (s == null || s.isEmpty) return 'Gift';
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }

  Widget _quickTile(InIconData icon, String label, Color color, Color tile,
      Widget Function() screen) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => screen())),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: tile, borderRadius: BorderRadius.circular(12)),
                child: Center(child: InIcon(icon, size: 20, color: color)),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      // Explicit, not inherited — this screen's body is hardcoded to the
      // dark AppColors palette regardless of the app's light/dark toggle,
      // so a plain AppBar() would otherwise pick up a light AppBarTheme
      // background when the user is in light mode, leaving what looks
      // like a blank white bar (and clashing badly with the dark body).
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: AppGradients.hero,
              border: Border.all(color: const Color(0xFF3A2A55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coin balance',
                    style: TextStyle(color: Color(0xFFCFC6E6), fontSize: 13)),
                const SizedBox(height: 6),
                Row(children: [
                  const CoinDot(size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(formatNumber(user?.coinBalance),
                          style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1)),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const WalletBuyScreen())),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44)),
                        icon: const InIcon(InIcons.plus,
                            size: 18, color: Colors.white),
                        label: const Text('Buy coins'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const WalletCashoutScreen())),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        icon: const InIcon(InIcons.cash,
                            size: 18, color: Colors.white),
                        label: const Text('Cash out'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _quickTile(InIcons.wheel, 'Daily spin', const Color(0xFFFF9F5A),
                const Color(0xFF2A1A10), () => const SpinWheelScreen()),
            const SizedBox(width: 8),
            _quickTile(
                InIcons.crown,
                user?.isVip == true ? 'VIP active' : 'VIP store',
                AppColors.gold,
                const Color(0xFF2A2310),
                () => const VipStoreScreen()),
            const SizedBox(width: 8),
            _quickTile(InIcons.ticket, 'Refer · 50', AppColors.success,
                const Color(0xFF0F2216), () => const ReferralScreen()),
            const SizedBox(width: 8),
            _quickTile(
                InIcons.live,
                'Live earnings',
                AppColors.pink,
                const Color(0xFF2A1028),
                () => const LivestreamDashboardScreen()),
          ]),
          const SizedBox(height: 14),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => const WalletKycScreen()))
                  .then((_) => _loadKyc()),
              leading: const InIcon(InIcons.verified, color: AppColors.blue),
              title: const Text('Identity check (KYC)',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                  'Needed to cash out · ${_kycStatus ?? 'not started'}',
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 12)),
              trailing: const InIcon(InIcons.chev,
                  size: 18, color: AppColors.textFaint),
            ),
          ),
          const SizedBox(height: 22),
          const Text('Recent activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_activityLoading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))))
          else if (_activity.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No activity yet.',
                    style:
                        TextStyle(color: AppColors.textFaint, fontSize: 12.5)))
          else
            ..._activity.map((t) {
              final coins = asNum(t['coins']).toDouble();
              final positive = coins >= 0;
              final createdAt =
                  DateTime.tryParse(t['createdAt']?.toString() ?? '');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(11)),
                      alignment: Alignment.center,
                      child: InIcon(
                          positive ? InIcons.arrowdn : InIcons.arrowup,
                          color:
                              positive ? AppColors.success : AppColors.textDim,
                          size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_activityTitle(t),
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              createdAt != null
                                  ? formatRelativeTime(createdAt)
                                  : '',
                              style: const TextStyle(
                                  color: AppColors.textFaint, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      '${positive ? '+' : ''}${formatNumber(coins)}',
                      style: TextStyle(
                          color: positive ? AppColors.success : AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
