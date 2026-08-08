import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/heat_slider.dart';

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

  int get _rupees => _customRupees ?? _kPresets[_presetIndex];

  Future<void> _buy() async {
    setState(() => _paying = true);
    try {
      final order = await ApiClient.post('/wallet/buy/order', body: {'rupees': _rupees}) as Map<String, dynamic>;
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Buy coins')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            onChanged: (v) => setState(() => _customRupees = v.isEmpty ? null : int.tryParse(v)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _paying ? null : _buy,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_paying ? 'Opening payment…' : 'Pay ₹$_rupees'),
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
