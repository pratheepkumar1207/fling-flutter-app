import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

class WalletKycScreen extends StatefulWidget {
  const WalletKycScreen({super.key});

  @override
  State<WalletKycScreen> createState() => _WalletKycScreenState();
}

class _WalletKycScreenState extends State<WalletKycScreen> {
  bool _loading = true;
  String? _status;
  final _pan = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _accountHolder = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/kyc/status') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _status = data['status'] as String? ?? 'none';
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
      await ApiClient.post('/kyc/submit', body: {
        'panNumber': _pan.text.trim().toUpperCase(),
        'bankAccountNumber': _bankAccount.text.trim(),
        'ifsc': _ifsc.text.trim().toUpperCase(),
        'accountHolderName': _accountHolder.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KYC submitted — pending review')));
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'verified':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.textFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('KYC verification'),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text(_status ?? 'none', style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Required once before you can cash out coins. This is reviewed by our team, not verified automatically.', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      _field('PAN number', _pan),
                      _field('Bank account number', _bankAccount),
                      _field('IFSC', _ifsc),
                      _field('Account holder name', _accountHolder),
                      const SizedBox(height: 8),
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
                          child: Text(_submitting ? 'Submitting…' : 'Submit for review', style: TextStyle(color: _submitting ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pan.dispose();
    _bankAccount.dispose();
    _ifsc.dispose();
    _accountHolder.dispose();
    super.dispose();
  }
}
