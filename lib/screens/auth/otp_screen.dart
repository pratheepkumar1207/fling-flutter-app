import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

const _kLength = 6;
const _kResendSeconds = 30;

/// Matches OTPDark.dc.html: full-bleed (no card), plain back button, a
/// violet-gradient lock icon, 6 boxed digit slots, and a "Resend in 0:24"
/// countdown that becomes a tappable "Resend code" once it expires — real
/// functionality wired to Firebase's forceResendingToken via
/// LoginScreen._verifyPhone, not just a static label. [onVerify] receives
/// the assembled code and confirms it via firebase_auth.
class OtpScreen extends StatefulWidget {
  final String phone;
  final Future<void> Function(String code)? onVerify;
  final Future<void> Function()? onResend;

  const OtpScreen(
      {super.key, required this.phone, this.onVerify, this.onResend});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(_kLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_kLength, (_) => FocusNode());
  String _error = '';
  bool _loading = false;
  bool _resending = false;
  double _shakeOffset = 0;
  int _resendSeconds = _kResendSeconds;
  Timer? _resendTimer;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = _kResendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resend() async {
    if (widget.onResend == null || _resending || _resendSeconds > 0) return;
    setState(() => _resending = true);
    try {
      await widget.onResend!();
      if (mounted) _startResendTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

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
      setState(() => _error =
          'Real phone verification isn\'t configured in this build yet. Use dev login instead.');
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.text)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFB565DE), Color(0xFF7A3B9E)]),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF9A3F9E)
                                  .withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.lock_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 16),
                    const Text('Enter the code',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 13,
                            height: 1.5),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to\n'),
                          TextSpan(
                              text: widget.phone,
                              style: const TextStyle(
                                  color: AppColors.textDim,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 32),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _shakeOffset),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        final wobble =
                            value == 0 ? 0.0 : (value * 8) * (1 - value);
                        return Transform.translate(
                            offset: Offset(wobble * (value > 0.5 ? -1 : 1), 0),
                            child: child);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_kLength, (i) {
                          final active = _focusNodes[i].hasFocus;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.5),
                            child: SizedBox(
                              width: 46,
                              height: 56,
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
                                  style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                          color: active
                                              ? AppColors.accent2
                                              : AppColors.border,
                                          width: 1.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                          color: active
                                              ? AppColors.accent2
                                              : AppColors.border,
                                          width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: AppColors.accent2, width: 1.5),
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
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: _resend,
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 12.5),
                          children: [
                            const TextSpan(text: "Didn't get a code? "),
                            TextSpan(
                              text: _resendSeconds > 0
                                  ? 'Resend in 0:${_resendSeconds.toString().padLeft(2, '0')}'
                                  : (_resending ? 'Sending…' : 'Resend code'),
                              style: const TextStyle(
                                  color: AppColors.accent2,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
              child: GestureDetector(
                onTap: (_loading || _code.length != _kLength) ? null : _submit,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: (_loading || _code.length != _kLength)
                        ? null
                        : const LinearGradient(colors: AppGradients.brand),
                    color: (_loading || _code.length != _kLength)
                        ? AppColors.surface2
                        : null,
                    boxShadow: (_loading || _code.length != _kLength)
                        ? null
                        : [
                            BoxShadow(
                                color: AppColors.accent2.withValues(alpha: 0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 10))
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _loading ? 'Verifying…' : 'Verify & continue',
                    style: TextStyle(
                        color: (_loading || _code.length != _kLength)
                            ? AppColors.textFaint
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}
