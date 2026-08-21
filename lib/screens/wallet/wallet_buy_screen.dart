import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../models/coin_package.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

/// Creates a Razorpay order via the backend, opens Razorpay's native
/// checkout with it, then sends the resulting payment id + signature to
/// POST /wallet/buy/verify so the server can verify the signature and
/// credit coins — the order's `key` comes back from the backend itself
/// (sourced from its own Razorpay account credentials), so this screen
/// needs no client-side key configuration.
///
/// Matches BuyCoinsDark.dc.html: a 3-column package grid (was a slide-to-
/// pick "HeatSlider" — old-app UI not in the mockup, and not even the
/// primary purchase path anymore) plus a dashed "Custom" tile. The
/// mockup's saved-card "Payment method" row is left out — this app
/// doesn't store or select a payment method itself; Razorpay's own
/// checkout screen handles that when it opens.
class WalletBuyScreen extends StatefulWidget {
  const WalletBuyScreen({super.key});

  @override
  State<WalletBuyScreen> createState() => _WalletBuyScreenState();
}

class _WalletBuyScreenState extends State<WalletBuyScreen> {
  bool _paying = false;

  List<CoinPackage>? _packages;
  String? _selectedPackageId;
  bool _customMode = false;
  int? _customRupees;
  final _customController = TextEditingController();

  late final Razorpay _razorpay;
  // Set right before Razorpay.open() so the success/error callbacks (which
  // only get paymentId/signature back from the SDK, not the coin amount)
  // know which pending order they're completing.
  String? _pendingOrderId;

  int? get _rupees => _customMode ? _customRupees : null;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    try {
      final data = await ApiClient.get('/wallet/packages');
      if (!mounted) return;
      final packages = (data as List)
          .map((e) => CoinPackage.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _packages = packages;
        if (packages.isNotEmpty) _selectedPackageId = packages.first.id;
      });
    } catch (_) {
      if (mounted) setState(() => _packages = []);
    }
  }

  void _selectPackage(CoinPackage pkg) {
    setState(() {
      _selectedPackageId = pkg.id;
      _customMode = false;
    });
  }

  void _selectCustom() {
    setState(() {
      _selectedPackageId = null;
      _customMode = true;
    });
  }

  bool get _canPay => _customMode
      ? (_customRupees != null && _customRupees! > 0)
      : _selectedPackageId != null;

  Future<void> _buy() async {
    if (!_canPay || _paying) return;
    setState(() => _paying = true);
    try {
      final body = _selectedPackageId != null
          ? {'packageId': _selectedPackageId}
          : {'rupees': _rupees};
      final order = await ApiClient.post('/wallet/buy/order', body: body)
          as Map<String, dynamic>;
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      _pendingOrderId = order['orderId'] as String;
      _razorpay.open({
        'key': order['key'],
        'order_id': order['orderId'],
        'amount': order['amount'],
        'currency': order['currency'],
        'name': 'Insync',
        'description': 'Coin top-up',
        'prefill': {
          if (user?.name != null) 'name': user!.name,
          if (user?.phone != null) 'contact': user!.phone,
        },
        // Matches AppColors.primary (dark theme) — Razorpay's checkout
        // theme only takes a static hex string, not a live Color value.
        'theme': {'color': '#9B5CF6'},
      });
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _paying = false);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open checkout: $e')));
      setState(() => _paying = false);
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = _pendingOrderId;
    if (orderId == null) return;
    try {
      final result = await ApiClient.post('/wallet/buy/verify', body: {
        'orderId': orderId,
        'paymentId': response.paymentId,
        'signature': response.signature,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('🪙 Coins added! New balance: ${result['coinBalance']}'),
            backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Payment succeeded but verification failed: ${e.message}'),
          backgroundColor: AppColors.danger));
    } finally {
      _pendingOrderId = null;
      if (mounted) setState(() => _paying = false);
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _pendingOrderId = null;
    if (!mounted) return;
    setState(() => _paying = false);
    if (response.code == Razorpay.PAYMENT_CANCELLED) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(response.message ?? 'Payment failed'),
          backgroundColor: AppColors.danger),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _pendingOrderId = null;
    if (!mounted) return;
    setState(() => _paying = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Opened ${response.walletName}')));
  }

  // Package.name is admin-set free text — badges are derived from it
  // ("Popular"/"Best value" substrings) rather than a dedicated field,
  // matching the mockup's floating pill without a backend/model change.
  String? _badgeFor(CoinPackage pkg) {
    final n = pkg.name.toLowerCase();
    if (n.contains('best value')) return 'BEST VALUE';
    if (n.contains('popular')) return 'POPULAR';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    CoinPackage? selectedPackage;
    for (final p in _packages ?? const <CoinPackage>[]) {
      if (p.id == _selectedPackageId) {
        selectedPackage = p;
        break;
      }
    }
    final payLabel = selectedPackage != null
        ? 'Pay ₹${selectedPackage.priceRupees.toStringAsFixed(0)}'
        : (_customRupees != null ? 'Pay ₹$_customRupees' : 'Pay');
    final coinBalance = context.watch<AuthProvider>().user?.coinBalance ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Buy coins')),
      body: _packages == null
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current balance',
                          style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text('${formatNumber(coinBalance)} coins',
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    ..._packages!.map((pkg) {
                      final selected = pkg.id == _selectedPackageId;
                      final badge = _badgeFor(pkg);
                      final badgeGold = badge == 'BEST VALUE';
                      final tint =
                          badgeGold ? AppColors.gold : AppColors.accent;
                      return GestureDetector(
                        onTap: () => _selectPackage(pkg),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? tint.withValues(alpha: 0.14)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: selected ? tint : AppColors.border,
                                    width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${pkg.coins}',
                                      style: TextStyle(
                                          color:
                                              selected ? tint : AppColors.text,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('₹${pkg.priceRupees.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          color: selected
                                              ? tint
                                              : AppColors.textFaint,
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                            if (badge != null)
                              Positioned(
                                top: -9,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: badgeGold
                                          ? const LinearGradient(colors: [
                                              Color(0xFFE0B15E),
                                              Color(0xFFC98F3A)
                                            ])
                                          : const LinearGradient(
                                              colors: AppGradients.brand),
                                    ),
                                    child: Text(badge,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: _selectCustom,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _customMode
                                  ? AppColors.accent
                                  : AppColors.border,
                              width: 1.5,
                              style: BorderStyle.solid),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded,
                                color: _customMode
                                    ? AppColors.accent
                                    : AppColors.textFaint,
                                size: 18),
                            const SizedBox(height: 4),
                            Text('Custom',
                                style: TextStyle(
                                    color: _customMode
                                        ? AppColors.accent
                                        : AppColors.textFaint,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_customMode) ...[
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: _customController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(
                          prefixText: '₹ ',
                          labelText: 'Amount',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14)),
                      onChanged: (v) =>
                          setState(() => _customRupees = int.tryParse(v)),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: (_canPay && !_paying) ? _buy : null,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: (_canPay && !_paying)
                          ? const LinearGradient(colors: AppGradients.brand)
                          : null,
                      color: (_canPay && !_paying) ? null : AppColors.surface2,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _paying ? 'Opening payment…' : payLabel,
                      style: TextStyle(
                          color: (_canPay && !_paying)
                              ? Colors.white
                              : AppColors.textFaint,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Payments are processed securely by Razorpay.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
              ],
            ),
    );
  }
}
