import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../models/coin_package.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/heat_slider.dart';
import '../../widgets/spinner.dart';

const _kPresets = [100, 250, 500, 1000, 2500];

/// Creates a Razorpay order via the backend. Actually completing the
/// payment needs the razorpay_flutter package wired up with your Razorpay
/// key + native Android/iOS setup — not included here (same category as
/// the Firebase phone-auth gap in login_screen.dart: needs your own
/// account/credentials, not something to hand-wire blind).
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

  int get _rupees => _customRupees ?? _kPresets[_presetIndex];

  @override
  void initState() {
    super.initState();
    _loadPackages();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${order['orderId']} created — connect razorpay_flutter to complete checkout.')),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _paying ? null : _buy,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_paying ? 'Opening payment…' : payLabel),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Payments are processed by Razorpay. This won't complete until razorpay_flutter is wired up with your keys.",
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
