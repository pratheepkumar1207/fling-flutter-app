import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
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
  bool _loadFailed = false;
  String? _kycStatus;
  String? _bankLast4;
  String? _accountHolderName;
  double _rupeesPerDiamond = 0.7;
  int _minDiamonds = 1000;
  int? _diamonds;
  bool _submitting = false;
  final _amountController = TextEditingController();
  List<dynamic> _cashouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final List<dynamic> results;
    try {
      results = await Future.wait([
        ApiClient.get('/kyc/status'),
        ApiClient.get('/wallet/cashout-info'),
        ApiClient.get('/wallet/cashouts').catchError((_) => []),
      ]);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    final kyc = results[0] as Map<String, dynamic>;
    final rate = results[1] as Map<String, dynamic>;
    setState(() {
      _kycStatus = kyc['status'] as String? ?? 'none';
      _bankLast4 = kyc['bankLast4'] as String?;
      _accountHolderName = kyc['accountHolderName'] as String?;
      _rupeesPerDiamond = asNum(rate['rupeesPerDiamond']).toDouble();
      _minDiamonds = asNum(rate['minCashoutDiamonds']).round();
      _cashouts = (results[2] as List?) ?? [];
      _loading = false;
    });
  }

  double _rupeesFor(num diamonds) => diamonds * _rupeesPerDiamond;

  void _setAmount(int? v) {
    setState(() => _diamonds = v);
    _amountController.text = v == null ? '' : '$v';
  }

  Future<void> _submit() async {
    final diamonds = _diamonds;
    if (diamonds == null || diamonds < _minDiamonds || _submitting) return;
    setState(() => _submitting = true);
    try {
      final res =
          await ApiClient.post('/wallet/cashout', body: {'diamonds': diamonds})
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
    final balance = user?.diamondBalance ?? 0;
    final canSubmit = _diamonds != null &&
        _diamonds! >= _minDiamonds &&
        _diamonds! <= balance;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const InsyncPageTitle('Withdraw')),
      body: _loading
          ? const Center(child: Spinner())
          : _loadFailed
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Couldn’t load your cash-out details.',
                        style: TextStyle(color: AppColors.textDim)),
                    const SizedBox(height: 10),
                    OutlinedButton(
                        onPressed: _load, child: const Text('Try again')),
                  ]),
                )
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
                                    color: AppColors.warning
                                        .withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                'You need verified KYC before withdrawing. Current status: ${_kycStatus ?? 'none'}.',
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
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
                                    const Text('Diamonds you can withdraw',
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
                                              text: 'diamonds',
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
                              Text(
                                  'Diamonds to withdraw (minimum $_minDiamonds)',
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
                                    const InIcon(InIcons.cash,
                                        color: AppColors.gold, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _amountController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                            color: AppColors.text,
                                            fontSize: 13.5),
                                        decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    vertical: 11)),
                                        onChanged: (v) => setState(
                                            () => _diamonds = int.tryParse(v)),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _setAmount(balance.floor()),
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 11),
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
                                        builder: (_) =>
                                            const WalletKycScreen()))
                                    .then((_) => _load()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppColors.accent, width: 1.5),
                                    color: AppColors.accent
                                        .withValues(alpha: 0.16),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(9)),
                                        alignment: Alignment.center,
                                        child: const InIcon(InIcons.bank,
                                            color: AppColors.accent, size: 17),
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
                                                      color:
                                                          AppColors.textFaint,
                                                      fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      const InIcon(InIcons.chev,
                                          color: AppColors.textFaint, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(14)),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InIcon(InIcons.info,
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
                              if (_cashouts.isNotEmpty) ...[
                                const SizedBox(height: 22),
                                const Text('RECENT REQUESTS',
                                    style: TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6)),
                                const SizedBox(height: 8),
                                ..._cashouts.map((c) {
                                  final paid = c['type'] == 'cashout_paid';
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 7),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            asNum(c['diamonds']) > 0
                                                ? '${c['diamonds']} diamonds · ₹${c['rupees']}'
                                                : '${c['coins']} coins',
                                            style: const TextStyle(
                                                color: AppColors.text,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600)),
                                        Text(paid ? 'Paid' : 'Pending',
                                            style: TextStyle(
                                                color: paid
                                                    ? AppColors.success
                                                    : AppColors.gold,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  );
                                }),
                              ],
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
                                _submitting
                                    ? 'Submitting…'
                                    : _diamonds != null &&
                                            _diamonds! >= _minDiamonds
                                        ? 'Withdraw ₹${_rupeesFor(_diamonds!).toStringAsFixed(2)}'
                                        : 'Withdraw',
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
