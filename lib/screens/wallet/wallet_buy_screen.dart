import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../models/coin_package.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/heat_slider.dart';
import '../../widgets/spinner.dart';

const _kPresets = [100, 250, 500, 1000, 2500];

/// Creates a Razorpay order via the backend, opens Razorpay's native
/// checkout with it, then sends the resulting payment id + signature to
/// POST /wallet/buy/verify so the server can verify the signature and
/// credit coins — the order's `key` comes back from the backend itself
/// (sourced from its own Razorpay account credentials), so this screen
/// needs no client-side key configuration.
class WalletBuyScreen extends StatefulWidget {
  const WalletBuyScreen({super.key});

  @override
  State<WalletBuyScreen> createState() => _WalletBuyScreenState();
}

class _WalletBuyScreenState extends State<WalletBuyScreen> {
  int _presetIndex = 1;
  int? _customRupees;
  bool _paying = false;

  List<CoinPackage>? _packages;
  String? _selectedPackageId;

  late final Razorpay _razorpay;
  // Set right before Razorpay.open() so the success/error callbacks (which
  // only get paymentId/signature back from the SDK, not the coin amount)
  // know which pending order they're completing.
  String? _pendingOrderId;

  int get _rupees => _customRupees ?? _kPresets[_presetIndex];

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
    super.dispose();
  }

  Future<void> _loadPackages() async {
    try {
      final data = await ApiClient.get('/wallet/packages');
      if (!mounted) return;
      setState(() => _packages = (data as List).map((e) => CoinPackage.fromJson(e as Map<String, dynamic>)).toList());
    } catch (_) {
      if (mounted) setState(() => _packages = []);
    }
  }

  void _selectPackage(CoinPackage pkg) {
    setState(() {
      _selectedPackageId = pkg.id;
      _customRupees = null;
    });
  }

  Future<void> _buy() async {
    setState(() => _paying = true);
    try {
      final body = _selectedPackageId != null ? {'packageId': _selectedPackageId} : {'rupees': _rupees};
      final order = await ApiClient.post('/wallet/buy/order', body: body) as Map<String, dynamic>;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _paying = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open checkout: $e')));
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
        SnackBar(content: Text('🪙 Coins added! New balance: ${result['coinBalance']}'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment succeeded but verification failed: ${e.message}'), backgroundColor: AppColors.danger));
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
      SnackBar(content: Text(response.message ?? 'Payment failed'), backgroundColor: AppColors.danger),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _pendingOrderId = null;
    if (!mounted) return;
    setState(() => _paying = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opened ${response.walletName}')));
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
    final payLabel = selectedPackage != null ? 'Pay ₹${selectedPackage.priceRupees.toStringAsFixed(0)}' : 'Pay ₹$_rupees';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Buy coins')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_packages == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Spinner(size: 20)))
          else if (_packages!.isNotEmpty) ...[
            const Text('COIN PACKAGES', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: _packages!.map((pkg) {
                final selected = pkg.id == _selectedPackageId;
                return GestureDetector(
                  onTap: () => _selectPackage(pkg),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(pkg.name, style: const TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('🪙 ${pkg.coins}', style: TextStyle(color: selected ? AppColors.primary : AppColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('₹${pkg.priceRupees.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('OR PICK A CUSTOM AMOUNT', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 10),
          ],
          GlassSurface(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('DRAG TO PICK YOUR HEAT', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 16),
                HeatSlider(
                  values: _kPresets,
                  index: _presetIndex,
                  formatLabel: (v) => '₹$v',
                  onChanged: (i) => setState(() {
                    _presetIndex = i;
                    _customRupees = null;
                    _selectedPackageId = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(labelText: 'Or type a custom amount (₹)'),
            onChanged: (v) => setState(() {
              _customRupees = v.isEmpty ? null : int.tryParse(v);
              _selectedPackageId = null;
            }),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _paying ? null : _buy,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: _paying ? null : const LinearGradient(colors: AppGradients.brand),
                color: _paying ? AppColors.surface2 : null,
              ),
              alignment: Alignment.center,
              child: Text(_paying ? 'Opening payment…' : payLabel, style: TextStyle(color: _paying ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Payments are processed securely by Razorpay.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
