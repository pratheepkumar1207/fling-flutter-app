import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import 'wallet_kyc_screen.dart';

class WalletCashoutScreen extends StatefulWidget {
  const WalletCashoutScreen({super.key});

  @override
  State<WalletCashoutScreen> createState() => _WalletCashoutScreenState();
}

class _WalletCashoutScreenState extends State<WalletCashoutScreen> {
  bool _loading = true;
  String? _kycStatus;
  int _coins = 500;
  bool _submitting = false;
  final _coinsController = TextEditingController(text: '500');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/kyc/status') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _kycStatus = data['status'] as String? ?? 'none';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final res = await ApiClient.post('/wallet/cashout', body: {'coins': _coins}) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cashout queued for ₹${(res['rupeesQueued'] as num).toStringAsFixed(2)}')));
      await context.read<AuthProvider>().refreshUser();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Cash out')),
      body: _loading
          ? const Center(child: Spinner())
          : _kycStatus != 'verified'
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                        child: Text('You need verified KYC before cashing out. Current status: ${_kycStatus ?? 'none'}.', style: const TextStyle(color: AppColors.warning, fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletKycScreen())).then((_) => _load()),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: AppGradients.brand)),
                          alignment: Alignment.center,
                          child: const Text('Complete KYC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balance: 🪙 ${formatNumber(user?.coinBalance)}', style: const TextStyle(color: AppColors.textDim)),
                      const SizedBox(height: 16),
                      const Text('Coins to cash out', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.text),
                          controller: _coinsController,
                          onChanged: (v) => _coins = int.tryParse(v) ?? _coins,
                          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _submitting ? null : _submit,
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: _submitting ? null : const LinearGradient(colors: AppGradients.brand),
                            color: _submitting ? AppColors.surface2 : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(_submitting ? 'Submitting…' : 'Request cashout', style: TextStyle(color: _submitting ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Payouts are sent manually by the team after review — this just queues the request.', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                    ],
                  ),
                ),
    );
  }
}
