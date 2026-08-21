import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import 'wallet_kyc_screen.dart';

/// Matches CashOutDark.dc.html: an "Available to redeem" balance card, an
/// amount field with a Max shortcut, the KYC bank account on file, and a
/// static payout-timing notice. The mockup's "Bank account" row is real
/// data from GET /kyc/status (added alongside this rewrite) rather than a
/// fabricated saved-payment-method — this app only ever has the one bank
/// account collected during KYC, so the row links to WalletKycScreen to
/// update it instead of the mockup's account-switcher chevron.
class WalletCashoutScreen extends StatefulWidget {
  const WalletCashoutScreen({super.key});

  @override
  State<WalletCashoutScreen> createState() => _WalletCashoutScreenState();
}

class _WalletCashoutScreenState extends State<WalletCashoutScreen> {
  bool _loading = true;
  String? _kycStatus;
  String? _bankLast4;
  String? _accountHolderName;
  double _coinsPerRupee = 10;
  double _cashoutFraction = 0.3333;
  int _minCashoutCoins = 500;
  int? _coins;
  bool _submitting = false;
  final _coinsController = TextEditingController();

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
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/kyc/status'),
      ApiClient.get('/wallet/cashout-info'),
    ]);
    if (!mounted) return;
    final kyc = results[0] as Map<String, dynamic>;
    final rate = results[1] as Map<String, dynamic>;
    setState(() {
      _kycStatus = kyc['status'] as String? ?? 'none';
      _bankLast4 = kyc['bankLast4'] as String?;
      _accountHolderName = kyc['accountHolderName'] as String?;
      _coinsPerRupee = asNum(rate['coinsPerRupee']).toDouble();
      _cashoutFraction = asNum(rate['cashoutFraction']).toDouble();
      _minCashoutCoins = asNum(rate['minCashoutCoins']).round();
      _loading = false;
    });
  }

  double _rupeesFor(num coins) => (coins / _coinsPerRupee) * _cashoutFraction;

  void _setCoins(int? v) {
    setState(() => _coins = v);
    _coinsController.text = v == null ? '' : '$v';
  }

  Future<void> _submit() async {
    final coins = _coins;
    if (coins == null || coins < _minCashoutCoins || _submitting) return;
    setState(() => _submitting = true);
    try {
      final res =
          await ApiClient.post('/wallet/cashout', body: {'coins': coins})
              as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Cashout queued for ₹${asNum(res['rupeesQueued']).toStringAsFixed(2)}')));
      await context.read<AuthProvider>().refreshUser();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final balance = user?.coinBalance ?? 0;
    final canSubmit =
        _coins != null && _coins! >= _minCashoutCoins && _coins! <= balance;

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
                        decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            border: Border.all(
                                color:
                                    AppColors.warning.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                            'You need verified KYC before cashing out. Current status: ${_kycStatus ?? 'none'}.',
                            style: const TextStyle(
                                color: AppColors.warning, fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => const WalletKycScreen()))
                            .then((_) => _load()),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                  colors: AppGradients.brand)),
                          alignment: Alignment.center,
                          child: const Text('Complete KYC',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                const Text('Available to redeem',
                                    style: TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                          text: '${formatNumber(balance)} ',
                                          style: const TextStyle(
                                              color: AppColors.text,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 26)),
                                      const TextSpan(
                                          text: 'coins',
                                          style: TextStyle(
                                              color: AppColors.textFaint,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    '≈ ₹${_rupeesFor(balance).toStringAsFixed(0)} at current rate',
                                    style: const TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Amount to cash out',
                              style: TextStyle(
                                  color: AppColors.textDim,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.border, width: 1.5)),
                            child: Row(
                              children: [
                                const Icon(Icons.monetization_on_rounded,
                                    color: AppColors.gold, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _coinsController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                        color: AppColors.text, fontSize: 13.5),
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(vertical: 11)),
                                    onChanged: (v) => setState(
                                        () => _coins = int.tryParse(v)),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _setCoins(balance.floor()),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 11),
                                    child: Text('Max',
                                        style: TextStyle(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Bank account',
                              style: TextStyle(
                                  color: AppColors.textDim,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => const WalletKycScreen()))
                                .then((_) => _load()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.accent, width: 1.5),
                                color: AppColors.accent.withValues(alpha: 0.16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(9)),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                        Icons.account_balance_rounded,
                                        color: AppColors.accent,
                                        size: 17),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            _bankLast4 != null
                                                ? 'Bank account •••• $_bankLast4'
                                                : 'No bank account on file',
                                            style: const TextStyle(
                                                color: AppColors.text,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5)),
                                        if (_accountHolderName != null)
                                          Text(_accountHolderName!,
                                              style: const TextStyle(
                                                  color: AppColors.textFaint,
                                                  fontSize: 10.5)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.textFaint, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color:
                                    AppColors.success.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: AppColors.success, size: 16),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Redeem requests are reviewed within 2-3 business days and paid directly to your bank account.',
                                    style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 11.5,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: GestureDetector(
                        onTap: (canSubmit && !_submitting) ? _submit : null,
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: (canSubmit && !_submitting)
                                ? const LinearGradient(
                                    colors: AppGradients.brand)
                                : null,
                            color: (canSubmit && !_submitting)
                                ? null
                                : AppColors.surface2,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _submitting ? 'Submitting…' : 'Request cash out',
                            style: TextStyle(
                                color: (canSubmit && !_submitting)
                                    ? Colors.white
                                    : AppColors.textFaint,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
