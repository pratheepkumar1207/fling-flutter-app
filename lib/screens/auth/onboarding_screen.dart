import 'dart:ui';
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(initialPhone: phone.isEmpty ? null : phone)));
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
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: ClipRect(
              child: Stack(
              children: [
                Positioned(
                  top: -140,
                  right: -120,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Opacity(
                      opacity: 0.4,
                      child: Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: AppGradients.brand)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -70,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Opacity(
                      opacity: 0.25,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(colors: AppGradients.brand),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 12))],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text('fling', style: TextStyle(color: AppColors.text, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                      const SizedBox(height: 44),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _heroCard(120, const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8A5A2E), Color(0xFF3A2410)])),
                          const SizedBox(width: 12),
                          _heroCard(150, const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A3E96), Color(0xFF2A1740)]), badge: true),
                          const SizedBox(width: 12),
                          _heroCard(120, const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3E8A5E), Color(0xFF14301E)])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Where real connections spark.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.text, fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Swipe, chat, watch parties, and more — one place to meet people who actually match your vibe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim, fontSize: 13.5, height: 1.5),
                  ),
                  const Spacer(),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), color: AppColors.surface),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('+1', style: TextStyle(color: AppColors.textFaint, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Container(width: 1, height: 20, color: AppColors.border),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: AppColors.text, fontSize: 14),
                            decoration: const InputDecoration(hintText: 'Phone number', hintStyle: TextStyle(color: AppColors.textFaint), border: InputBorder.none, isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _continue,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: AppGradients.brand),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 14))],
                      ),
                      alignment: Alignment.center,
                      child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, height: 1.5),
                        children: [
                          const TextSpan(text: 'By continuing you agree to our '),
                          TextSpan(text: 'Terms', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                          const TextSpan(text: ' and '),
                          TextSpan(text: 'Privacy Policy', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(double height, Gradient gradient, {bool badge = false}) {
    return Container(
      width: badge ? 110 : 96,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(badge ? 22 : 20),
        gradient: gradient,
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 26, offset: const Offset(0, 16))],
      ),
      alignment: Alignment.bottomCenter,
      padding: badge ? const EdgeInsets.all(10) : EdgeInsets.zero,
      child: badge
          ? Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: AppGradients.brand))),
                  const SizedBox(width: 6),
                  Expanded(child: Container(height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)))),
                ],
              ),
            )
          : null,
    );
  }
}
