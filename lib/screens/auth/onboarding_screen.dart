import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

const _kSeenKey = 'onboarding_seen';

/// One-time welcome/value-prop screen, matches OnboardingDark.dc.html —
/// shown before LoginScreen on first launch only (SharedPreferences flag,
/// same pattern as ThemeController's persistence). The mock's own phone
/// field doubles as a login form, but that logic (dev login, Firebase OTP,
/// fake-account login) already lives in LoginScreen — duplicating it here
/// would just be two places to keep in sync, so this screen is the hero/
/// value-prop half only, handing off to the real LoginScreen via "Get
/// started".
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenKey) ?? false;
  }

  static Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }

  Future<void> _getStarted(BuildContext context) async {
    await _markSeen();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
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
                  GestureDetector(
                    onTap: () => _getStarted(context),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: AppGradients.brand),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 14))],
                      ),
                      alignment: Alignment.center,
                      child: const Text('Get started', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
