import '../../widgets/insync_clay.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

const _kSeenKey = 'onboarding_seen';

/// One-time welcome screen, matches OnboardingDark.dc.html literally —
/// including its own phone-number field, not just a "Get started" hero.
/// The actual auth logic (dev login, Firebase OTP, fake-account login)
/// stays in LoginScreen alone — this screen just carries the typed phone
/// number through via initialPhone rather than duplicating that flow.
/// The mockup's second "Continue with Google" button is left out: there's
/// no working Google sign-in anywhere in this app to wire it to (the
/// existing GoogleAccountLink/google_content_service.dart is for linking
/// a Google account for YouTube content browsing, not for signing in).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenKey) ?? false;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _phoneController = TextEditingController();

  static Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }

  Future<void> _continue() async {
    await _markSeen();
    if (!mounted) return;
    final phone = _phoneController.text.trim();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            LoginScreen(initialPhone: phone.isEmpty ? null : phone)));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text('insync',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1)),
          const SizedBox(height: 20),
          Container(
              decoration: insyncClay(cobalt: true),
              padding: const EdgeInsets.all(12),
              child: Image.asset('assets/icons/app/watch_clay.png',
                  height: 180,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true)),
          const SizedBox(height: 24),
          const Text('Your people.\nYour kind of moment.',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6)),
          const SizedBox(height: 12),
          const Text('Watch together, talk for hours, or play one more round.',
              style: TextStyle(
                  color: AppColors.textDim, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continue(),
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+ country code and number',
                  prefixIcon:
                      Icon(Icons.phone_rounded, color: AppColors.accent))),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _continue,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size(48, 52)),
              child: const Text('Continue',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 16),
          const Text('By continuing you agree to our Terms and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textDim, fontSize: 11, height: 1.5)),
        ],
      )),
    );
  }
}
