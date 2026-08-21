import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/firebase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/mascot_eyes.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _error = '';
  bool _loading = false;
  bool _devMode = !firebaseConfigured;
  bool _fieldFocused = false;
  bool _fakeLoginMode = false;

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
      if (_fakeLoginMode) {
        await context.read<AuthProvider>().loginFake(_usernameController.text.trim(), _passwordController.text);
      } else if (_devMode) {
        await context.read<AuthProvider>().devLogin(_normalizedPhone);
      } else {
        final phone = _normalizedPhone;
        final authProvider = context.read<AuthProvider>();
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            final cred = await FirebaseAuth.instance.signInWithCredential(credential);
            final idToken = await cred.user?.getIdToken();
            if (idToken != null) await authProvider.loginWithFirebaseIdToken(idToken);
          },
          verificationFailed: (FirebaseAuthException e) {
            if (mounted) setState(() => _error = e.message ?? 'Verification failed');
          },
          codeSent: (String verificationId, int? resendToken) {
            if (!mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OtpScreen(
                phone: phone,
                onVerify: (code) async {
                  final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code);
                  final cred = await FirebaseAuth.instance.signInWithCredential(credential);
                  final idToken = await cred.user?.getIdToken();
                  if (idToken == null) throw Exception('Could not verify code.');
                  await authProvider.loginWithFirebaseIdToken(idToken);
                },
              ),
            ));
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
                          'Insync',
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
                        if (_fakeLoginMode) ...[
                          const Text('Username', style: TextStyle(color: AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          _authField(controller: _usernameController, hint: 'username'),
                          const SizedBox(height: 12),
                          const Text('Password', style: TextStyle(color: AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          _authField(controller: _passwordController, hint: 'password', obscureText: true),
                        ] else ...[
                          const Text('Phone number', style: TextStyle(color: AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          _authField(controller: _phoneController, hint: '+91XXXXXXXXXX', focusNode: _phoneFocus, keyboardType: TextInputType.phone),
                        ],
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _loading ? null : _handleSubmit,
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: _loading ? null : const LinearGradient(colors: AppGradients.brand),
                              color: _loading ? AppColors.surface2 : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _loading ? 'Signing in…' : (_fakeLoginMode ? 'Log in' : (_devMode ? 'Continue (dev login)' : 'Send code')),
                              style: TextStyle(color: _loading ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ),
                        if (!_fakeLoginMode)
                          if (firebaseConfigured)
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
                        TextButton(
                          onPressed: () => setState(() {
                            _fakeLoginMode = !_fakeLoginMode;
                            _error = '';
                          }),
                          child: Text(
                            _fakeLoginMode ? 'Use phone number instead' : 'Have a test account? Log in with username',
                            style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
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

  Widget _authField({required TextEditingController controller, required String hint, FocusNode? focusNode, TextInputType? keyboardType, bool obscureText = false}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
