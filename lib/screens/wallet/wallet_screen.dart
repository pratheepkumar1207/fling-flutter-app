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

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _spinning = false;
  bool _buyingVip = false;
  String? _kycStatus;

  @override
  void initState() {
    super.initState();
    _loadKyc();
  }

  Future<void> _loadKyc() async {
    try {
      final data = await ApiClient.get('/kyc/status') as Map<String, dynamic>;
      if (mounted) setState(() => _kycStatus = data['status'] as String? ?? 'none');
    } catch (_) {}
  }

  Future<void> _spin() async {
    setState(() => _spinning = true);
    try {
      final res = await ApiClient.post('/wallet/spin') as Map<String, dynamic>;
      _snack('You won ${res['coinsWon']} coins! 🎉');
      if (mounted) context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                const Text('Balance', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                Text('🪙 ${formatNumber(user?.coinBalance)}', style: const TextStyle(color: AppColors.gold, fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletBuyScreen())),
                      child: const Text('Buy coins'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletCashoutScreen())),
                      child: const Text('Cash out'),
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
                  onTap: _spinning ? null : _spin,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        const Text('🎡', style: TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(_spinning ? 'Spinning…' : 'Daily spin', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
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
                    decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gold.withValues(alpha: 0.4))),
                    child: Column(
                      children: [
                        const Text('👑', style: TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          user?.isVip == true ? 'VIP active' : (_buyingVip ? 'Purchasing…' : 'Get VIP (500)'),
                          style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w500),
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
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletKycScreen())).then((_) => _loadKyc()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'KYC status: ', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                    TextSpan(text: _kycStatus ?? 'none', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' — tap to manage →', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
