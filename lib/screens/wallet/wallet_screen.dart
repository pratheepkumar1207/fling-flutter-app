import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import 'wallet_buy_screen.dart';
import 'wallet_cashout_screen.dart';
import 'wallet_kyc_screen.dart';
import 'spin_wheel_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _buyingVip = false;
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

  Future<void> _buyVip() async {
    setState(() => _buyingVip = true);
    try {
      await ApiClient.post('/wallet/buy-vip');
      _snack('VIP activated!');
      if (mounted) context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _buyingVip = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: const Text('Wallet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3D2A4A), Color(0xFF261A38)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coin balance',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatNumber(user?.coinBalance),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    const Text('coins',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const WalletBuyScreen())),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: AppGradients.brand),
                              borderRadius: BorderRadius.circular(999)),
                          alignment: Alignment.center,
                          child: const Text('Buy coins',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const WalletCashoutScreen())),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25))),
                          alignment: Alignment.center,
                          child: const Text('Cash out',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SpinWheelScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                    child: const Column(
                      children: [
                        Text('🎡', style: TextStyle(fontSize: 26)),
                        SizedBox(height: 4),
                        Text('Daily spin',
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: (user?.isVip == true || _buyingVip) ? null : _buyVip,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4))),
                    child: Column(
                      children: [
                        const Text('👑', style: TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          user?.isVip == true
                              ? 'VIP active'
                              : (_buyingVip ? 'Purchasing…' : 'Get VIP (500)'),
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(
                    MaterialPageRoute(builder: (_) => const WalletKycScreen()))
                .then((_) => _loadKyc()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                        text: 'KYC status: ',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 13)),
                    TextSpan(
                        text: _kycStatus ?? 'none',
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const TextSpan(
                        text: ' — tap to manage →',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('RECENT ACTIVITY',
              style: TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
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
              final coins = (t['coins'] as num?)?.toDouble() ?? 0;
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
                      child: Icon(
                          positive
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
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
