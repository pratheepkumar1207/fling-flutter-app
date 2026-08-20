import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';

const _kLength = 6;

/// "Sigil" slot-style OTP screen — Dart port of src/pages/OtpPage.jsx.
/// Reached after login_screen.dart sends a real Firebase OTP. [onVerify]
/// receives the assembled code and confirms it via firebase_auth.
class OtpScreen extends StatefulWidget {
  final String phone;
  final Future<void> Function(String code)? onVerify;

  const OtpScreen({super.key, required this.phone, this.onVerify});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(_kLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_kLength, (_) => FocusNode());
  String _error = '';
  bool _loading = false;
  double _shakeOffset = 0;

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Whole code pasted into one slot.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < digits.length && index + i < _kLength; i++) {
        _controllers[index + i].text = digits[i];
      }
      final target = (index + digits.length).clamp(0, _kLength - 1);
      _focusNodes[target].requestFocus();
    } else if (value.isNotEmpty) {
      if (index < _kLength - 1) _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    if (_code.length == _kLength && !_loading) _submit();
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _submit() async {
    if (widget.onVerify == null) {
      setState(() => _error = 'Real phone verification isn\'t configured in this build yet. Use dev login instead.');
      _triggerShake();
      return;
    }
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      await widget.onVerify!(_code);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      _triggerShake();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _triggerShake() {
    setState(() => _shakeOffset = 1);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shakeOffset = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -64, left: -96, child: Blob(color: AppColors.primary, size: 280)),
          Positioned(bottom: -32, right: -80, child: Blob(color: AppColors.accent, size: 320)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(24),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlassIcon.circle(
                          size: 56,
                          colors: const [AppColors.accent2, AppColors.primary],
                          glowColor: AppColors.primary.withValues(alpha: 0.4),
                          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 16),
                        const Text('Enter the code', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Sent to ${widget.phone}', style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                        const SizedBox(height: 20),
                        if (_error.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _shakeOffset),
                          duration: const Duration(milliseconds: 500),
                          curve: kSpringCurve,
                          builder: (context, value, child) {
                            final wobble = value == 0 ? 0.0 : (value * 8) * (1 - value);
                            return Transform.translate(offset: Offset(wobble * (value > 0.5 ? -1 : 1), 0), child: child);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_kLength, (i) {
                              final filled = _controllers[i].text.isNotEmpty;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: SizedBox(
                                  width: 42,
                                  height: 52,
                                  child: KeyboardListener(
                                    focusNode: FocusNode(skipTraversal: true),
                                    onKeyEvent: (event) => _onKey(i, event),
                                    child: TextField(
                                      controller: _controllers[i],
                                      focusNode: _focusNodes[i],
                                      enabled: !_loading,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: _kLength,
                                      style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700),
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: AppColors.surface2.withValues(alpha: 0.8),
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: filled ? AppColors.primary : AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: filled ? AppColors.primary : AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                      ),
                                      onChanged: (v) => _onChanged(i, v),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_loading || _code.length != _kLength) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(_loading ? 'Verifying…' : 'Verify'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back', style: TextStyle(color: AppColors.textFaint)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}
