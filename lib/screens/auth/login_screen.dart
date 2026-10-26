import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/firebase_service.dart';
import '../../core/google_auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'otp_screen.dart';
import 'safety_guidelines_screen.dart';

class LoginScreen extends StatefulWidget {
  // Carried over from OnboardingScreen's own phone field (the mockup shows
  // phone entry on both screens — Onboarding just hands the typed number
  // through to here rather than duplicating the actual auth flow).
  final String? initialPhone;

  const LoginScreen({super.key, this.initialPhone});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _phoneController =
      TextEditingController(text: widget.initialPhone);
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

  // The +91 box is shown; a number typed with its own +code is kept as is.
  String get _normalizedPhone {
    final trimmed = _phoneController.text.trim().replaceAll(' ', '');
    if (trimmed.startsWith('+')) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 && digits.startsWith('91')
        ? '+$digits'
        : '+91$digits';
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      if (_fakeLoginMode) {
        await context.read<AuthProvider>().loginFake(
            _usernameController.text.trim(), _passwordController.text);
      } else if (_devMode) {
        await context.read<AuthProvider>().devLogin(_normalizedPhone);
      } else {
        final phone = _normalizedPhone;
        final authProvider = context.read<AuthProvider>();
        await _verifyPhone(phone, authProvider, _PhoneVerification());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      final idToken = await GoogleAuthService.signInAndGetFirebaseIdToken();
      if (idToken == null) return; // user cancelled the picker
      if (!mounted) return;
      await context.read<AuthProvider>().loginWithFirebaseIdToken(idToken);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Split out of _handleSubmit so OtpScreen's "Resend code" can call this
  // again with the same mutable [verification] holder — forceResendingToken
  // makes it a real resend rather than starting a brand-new verification
  // flow, and only the very first codeSent push()es OtpScreen; later ones
  // (from a resend) just update the holder the already-open screen reads
  // verificationId/resendToken from.
  Future<void> _verifyPhone(
      String phone, AuthProvider authProvider, _PhoneVerification verification,
      {int? forceResendingToken}) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final cred =
            await FirebaseAuth.instance.signInWithCredential(credential);
        final idToken = await cred.user?.getIdToken();
        if (idToken != null) {
          await authProvider.loginWithFirebaseIdToken(idToken);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() => _error = e.message ?? 'Verification failed');
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        verification.verificationId = verificationId;
        verification.resendToken = resendToken;
        if (verification.pushed || !mounted) return;
        verification.pushed = true;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: phone,
            onVerify: (code) async {
              final credential = PhoneAuthProvider.credential(
                  verificationId: verification.verificationId, smsCode: code);
              final cred =
                  await FirebaseAuth.instance.signInWithCredential(credential);
              final idToken = await cred.user?.getIdToken();
              if (idToken == null) throw Exception('Could not verify code.');
              await authProvider.loginWithFirebaseIdToken(idToken);
            },
            onResend: () => _verifyPhone(phone, authProvider, verification,
                forceResendingToken: verification.resendToken),
          ),
        ));
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final submitLabel = _loading
        ? 'Signing in…'
        : (_fakeLoginMode
            ? 'Log in'
            : (_devMode ? 'Continue (dev login)' : 'Send code'));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: canPop
                            ? InIconButton(InIcons.back,
                                tooltip: 'Back',
                                onPressed: () => Navigator.of(context).pop())
                            : Image.asset('assets/icon/insync-symbol.png',
                                height: 28, semanticLabel: 'Insync'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Sign in',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6)),
                    const SizedBox(height: 6),
                    Text(
                        _fakeLoginMode
                            ? 'Use the username and password you were given.'
                            : 'We’ll text you a code to check it’s you.',
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 14)),
                    const SizedBox(height: 20),
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_fakeLoginMode) ...[
                      _label('Username'),
                      _authField(
                          controller: _usernameController,
                          hint: 'username',
                          icon: InIcons.user),
                      const SizedBox(height: 14),
                      _label('Password'),
                      _authField(
                          controller: _passwordController,
                          hint: 'password',
                          icon: InIcons.lock,
                          obscureText: true),
                    ] else ...[
                      _label('Phone number'),
                      Row(children: [
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border)),
                          alignment: Alignment.center,
                          child:
                              const Text('+91', style: TextStyle(fontSize: 15)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _authField(
                              controller: _phoneController,
                              hint: '98765 43210',
                              focusNode: _phoneFocus,
                              keyboardType: TextInputType.phone,
                              highlight: _fieldFocused),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loading ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      icon: _fakeLoginMode
                          ? const SizedBox.shrink()
                          : const InIcon(InIcons.phone,
                              size: 18, color: Colors.white),
                      label: Text(submitLabel),
                    ),
                    if (!_fakeLoginMode) ...[
                      const SizedBox(height: 18),
                      const Row(children: [
                        Expanded(
                            child: Divider(color: AppColors.border, height: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: TextStyle(
                                  color: AppColors.textFaint, fontSize: 13)),
                        ),
                        Expanded(
                            child: Divider(color: AppColors.border, height: 1)),
                      ]),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _loading ? null : _handleGoogleSignIn,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF121016)),
                        icon: const _GoogleMark(),
                        label: const Text('Continue with Google'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _fakeLoginMode = !_fakeLoginMode;
                        _error = '';
                      }),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: InIcon(
                          _fakeLoginMode ? InIcons.phone : InIcons.user,
                          size: 18),
                      label: Text(_fakeLoginMode
                          ? 'Use phone number instead'
                          : 'Use username and password'),
                    ),
                    if (!_fakeLoginMode && firebaseConfigured)
                      TextButton(
                        onPressed: () => setState(() => _devMode = !_devMode),
                        child: Text(
                          _devMode
                              ? 'Use real phone verification'
                              : 'Use dev login instead',
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 12),
                        ),
                      )
                    else if (!_fakeLoginMode)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Firebase isn\'t configured yet — using dev login.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 11),
                        ),
                      ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SafetyGuidelinesScreen(
                                    previewOnly: true))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border)),
                          child: const Row(children: [
                            InIcon(InIcons.shield,
                                size: 20, color: AppColors.success),
                            SizedBox(width: 10),
                            Expanded(
                                child: Text('Read our safety guidelines',
                                    style: TextStyle(fontSize: 13))),
                            InIcon(InIcons.chev,
                                size: 18, color: AppColors.textFaint),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
      );

  Widget _authField(
      {required TextEditingController controller,
      required String hint,
      InIconData? icon,
      FocusNode? focusNode,
      TextInputType? keyboardType,
      bool obscureText = false,
      bool highlight = false}) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: highlight ? AppColors.purple : AppColors.border)),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: AppColors.text, fontSize: 15),
        decoration: InputDecoration(
            hintText: hint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            prefixIcon: icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InIcon(icon, size: 18, color: AppColors.textDim)),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
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

/// Mutable holder shared between OtpScreen's onVerify/onResend closures —
/// a resend's codeSent callback updates verificationId/resendToken in
/// place rather than pushing a second OtpScreen on top of the first.
class _PhoneVerification {
  String verificationId = '';
  int? resendToken;
  bool pushed = false;
}

/// Google "G" in its brand colours (required by Google's sign-in branding).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path fill="#4285F4" d="M22 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.6a4.8 4.8 0 01-2.1 3.1v2.6h3.4c2-1.8 3.1-4.5 3.1-7.5z"/>'
      '<path fill="#34A853" d="M12 22c2.8 0 5.2-.9 6.9-2.5l-3.4-2.6c-.9.6-2.1 1-3.5 1-2.7 0-5-1.8-5.8-4.3H2.7v2.7A10 10 0 0012 22z"/>'
      '<path fill="#FBBC05" d="M6.2 13.6a6 6 0 010-3.8V7.1H2.7a10 10 0 000 9z"/>'
      '<path fill="#EA4335" d="M12 5.9c1.5 0 2.9.5 4 1.5l3-3A10 10 0 002.7 7.1l3.5 2.7C7 7.7 9.3 5.9 12 5.9z"/></svg>',
      width: 20,
      height: 20);
}
