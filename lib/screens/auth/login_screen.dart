import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/mascot_eyes.dart';

/// Flips to true once `flutterfire configure` has been run and firebase_auth
/// wired up for real phone-OTP sign-in — mirrors firebaseConfigured in the
/// web app's src/lib/firebase.js. Until then, dev-login is the only path
/// (same as the web app defaults to when Firebase env vars are unset).
const bool kFirebaseConfigured = false;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  String _error = '';
  bool _loading = false;
  bool _devMode = !kFirebaseConfigured;
  bool _fieldFocused = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() {
      setState(() => _fieldFocused = _phoneFocus.hasFocus);
    });
  }

  String get _normalizedPhone {
    final trimmed = _phoneController.text.trim();
    return trimmed.startsWith('+') ? trimmed : '+$trimmed';
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      if (_devMode) {
        await context.read<AuthProvider>().devLogin(_normalizedPhone);
      } else {
        // TODO: once flutterfire configure has been run, send a real OTP here
        // via firebase_auth's verifyPhoneNumber and push OtpScreen.
        throw Exception('Real phone verification isn\'t configured yet — use dev login.');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(top: -80, left: -80, child: Blob(color: AppColors.accent, size: 280)),
          Positioned(right: -96, top: 220, child: Blob(color: AppColors.primary, size: 320)),
          Positioned(bottom: -64, left: 60, child: Blob(color: AppColors.success, size: 260)),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: MascotEyes(covering: _fieldFocused)),
                        const SizedBox(height: 16),
                        const Text(
                          'Fling',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Meet people, hang out, vibe together.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textDim, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        if (_error.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                          ),
                        const Text('Phone number', style: TextStyle(color: AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          focusNode: _phoneFocus,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: AppColors.text),
                          decoration: const InputDecoration(hintText: '+91XXXXXXXXXX'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(_loading ? 'Sending…' : (_devMode ? 'Continue (dev login)' : 'Send code')),
                          ),
                        ),
                        if (kFirebaseConfigured)
                          TextButton(
                            onPressed: () => setState(() => _devMode = !_devMode),
                            child: Text(
                              _devMode ? 'Use real phone verification' : 'Use dev login instead',
                              style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Firebase isn\'t configured yet — using dev login.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textFaint, fontSize: 11),
                            ),
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
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }
}
