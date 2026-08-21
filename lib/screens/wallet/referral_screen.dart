import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

/// "Invite friends" — matches ReferralDark.dc.html. All backend logic
/// already existed (GET /gamification/me for the code, POST
/// /gamification/referral-code to generate one, POST
/// /gamification/redeem-referral to redeem) — this consolidates what used
/// to be a small inline widget buried in the gamification card on Profile
/// into its own screen. referralCount is new on GET /gamification/me,
/// added alongside this screen since the mock shows "N friends joined".
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _loading = true;
  String? _code;
  int _referralCount = 0;
  bool _generating = false;
  final _redeemController = TextEditingController();
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _redeemController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/gamification/me') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _code = data['referralCode'] as String?;
        _referralCount = data['referralCount'] as int? ?? 0;
        _loading = false;
      });
      if (_code == null) _generateCode();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCode() async {
    setState(() => _generating = true);
    try {
      final res = await ApiClient.post('/gamification/referral-code') as Map<String, dynamic>;
      if (mounted) setState(() => _code = res['referralCode'] as String?);
    } catch (_) {
      _snack('Failed to generate code');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _shareCode() async {
    final code = _code;
    if (code == null) return;
    await Share.share('Join me on Insync! Use my code $code when you sign up and we both get 50 coins.');
  }

  Future<void> _redeem() async {
    final code = _redeemController.text.trim();
    if (code.isEmpty || _redeeming) return;
    setState(() => _redeeming = true);
    try {
      final res = await ApiClient.post('/gamification/redeem-referral', body: {'code': code}) as Map<String, dynamic>;
      _snack('+${res['coinsAwarded']} coins!');
      _redeemController.clear();
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Invalid referral code');
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Invite friends')),
      body: _loading
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(colors: AppGradients.brand),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 16))],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Give 50, get 50', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'Share your code — you both get 50 coins when your friend joins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.accent, width: 1.5),
                    color: AppColors.accent.withValues(alpha: 0.1),
                  ),
                  child: Column(
                    children: [
                      const Text('YOUR CODE', style: TextStyle(color: AppColors.textFaint, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      Text(
                        _generating ? '…' : (_code ?? '—'),
                        style: const TextStyle(color: AppColors.accent, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _code == null ? null : _shareCode,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: AppGradients.brand)),
                          alignment: Alignment.center,
                          child: const Text('Share code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _code == null ? null : () => Clipboard.setData(ClipboardData(text: _code!)).then((_) => _snack('Code copied')),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.copy_rounded, color: AppColors.textDim, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('HAVE A CODE?', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: TextField(
                          controller: _redeemController,
                          style: const TextStyle(color: AppColors.text, fontSize: 13),
                          decoration: const InputDecoration(hintText: 'Enter code', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _redeeming ? null : _redeem,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _redeeming ? AppColors.surface2 : AppColors.text),
                        alignment: Alignment.center,
                        child: Text(_redeeming ? '…' : 'Redeem', style: TextStyle(color: _redeeming ? AppColors.textFaint : AppColors.bg, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '$_referralCount friend${_referralCount == 1 ? '' : 's'} joined with your code so far',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
                ),
              ],
            ),
    );
  }
}
