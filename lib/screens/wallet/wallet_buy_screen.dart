import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/api_client.dart';
import '../../core/store_purchases.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../models/coin_package.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import '../../widgets/insync_snack.dart';

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
  // The store's own product (with its local price) for each pack.
  Map<String, ProductDetails> _products = const {};
  String? _selectedPackageId;
  StreamSubscription<PurchaseOutcome>? _outcomeSub;

  final _store = StorePurchases.instance;

  @override
  void initState() {
    super.initState();
    _store.start();
    _outcomeSub = _store.outcomes.listen(_onOutcome);
    _loadPackages();
  }

  @override
  void dispose() {
    _outcomeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    try {
      final data = await ApiClient.get('/wallet/packages');
      final packages = (data as List)
          .map((e) => CoinPackage.fromJson(e as Map<String, dynamic>))
          .where((p) => p.storeProductId != null)
          .toList();
      final products = await _store
          .products({for (final p in packages) p.storeProductId!});
      if (!mounted) return;
      // Only packs the store actually sells.
      final sold =
          packages.where((p) => products.containsKey(p.storeProductId)).toList();
      setState(() {
        _packages = sold;
        _products = products;
        if (sold.isNotEmpty) _selectedPackageId = sold.first.id;
      });
    } catch (_) {
      if (mounted) setState(() => _packages = []);
    }
  }

  void _selectPackage(CoinPackage pkg) {
    setState(() => _selectedPackageId = pkg.id);
  }

  CoinPackage? get _selected {
    for (final p in _packages ?? const <CoinPackage>[]) {
      if (p.id == _selectedPackageId) return p;
    }
    return null;
  }

  bool get _canPay => _selected != null;

  String _priceOf(CoinPackage pkg) =>
      _products[pkg.storeProductId]?.price ??
      '₹${pkg.priceRupees.toStringAsFixed(0)}';

  Future<void> _buy() async {
    final pkg = _selected;
    final product = pkg == null ? null : _products[pkg.storeProductId];
    if (product == null || _paying) return;
    setState(() => _paying = true);
    try {
      final started = await _store.buy(product);
      if (!started && mounted) setState(() => _paying = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
          insyncSnackBar(content: Text('Couldn’t open the payment. Try again.')));
    }
  }

  Future<void> _onOutcome(PurchaseOutcome o) async {
    if (!mounted) return;
    if (o.pending) {
      ScaffoldMessenger.of(context).showSnackBar(insyncSnackBar(
          content: Text(
              'Payment pending. Your coins arrive when it goes through.')));
      setState(() => _paying = false);
      return;
    }
    setState(() => _paying = false);
    if (o.ok) {
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(insyncSnackBar(
          content: Text(o.coinBalance != null
              ? '🪙 Coins added! New balance: ${formatNumber(o.coinBalance)}'
              : '🪙 Coins added!'),
          backgroundColor: AppColors.success));
      Navigator.of(context).pop(true);
    } else if (o.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(insyncSnackBar(
          content: Text(o.message!), backgroundColor: AppColors.danger));
    }
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
    final selectedPackage = _selected;
    final payLabel =
        selectedPackage != null ? 'Pay ${_priceOf(selectedPackage)}' : 'Pay';
    final coinBalance = context.watch<AuthProvider>().user?.coinBalance ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const InsyncPageTitle('Buy coins')),
      body: _packages == null
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.surface2, border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 0.8)),
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
                                  Text(_priceOf(pkg),
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
                  ],
                ),
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
                if (_packages!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Coin packs aren’t available on this phone right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textFaint)),
                  ),
                Text(
                    Platform.isIOS
                        ? 'Paid through the App Store.'
                        : 'Paid through Google Play.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 10.5)),
              ],
            ),
    );
  }
}
