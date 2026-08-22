import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';

const _kRules = [
  (
    icon: Icons.person_rounded,
    colors: [Color(0xFFE0836B), Color(0xFFB8422C)],
    title: 'Be who you say you are',
    body: 'Fake profiles get suspended — verification keeps the room honest.',
  ),
  (
    icon: Icons.sentiment_satisfied_alt_rounded,
    colors: [Color(0xFF7FA8D9), Color(0xFF4272D9)],
    title: 'Keep it respectful',
    body: "Harassment, hate speech, and unwanted contact aren't tolerated.",
  ),
  (
    icon: Icons.lock_rounded,
    colors: [Color(0xFFDBB155), Color(0xFFB98A3D)],
    title: 'Never share money or passwords',
    body: "We'll never ask off-platform. Report anyone who does.",
  ),
  (
    icon: Icons.warning_rounded,
    colors: [Color(0xFFED8B6B), Color(0xFFED4B43)],
    title: "Report, don't retaliate",
    body: 'Block and report from any profile — our team reviews every case.',
  ),
];

/// Shown once, right after CompleteProfileScreen — see SplashScreen, which
/// routes here whenever profileComplete is true but safetyGuidelinesSeenAt
/// is still null. Matches SafetyGuidelinesDark.dc.html: a shield icon,
/// title/subtitle, 4 divided rule rows, and a pinned CTA. Drops the old
/// "turn on notifications" prompt this screen used to carry inline — not
/// in the mockup, and not a unique capability: Settings already has its
/// own notifications toggle, so nothing is lost by not duplicating it here.
class SafetyGuidelinesScreen extends StatefulWidget {
  const SafetyGuidelinesScreen({super.key});

  @override
  State<SafetyGuidelinesScreen> createState() => _SafetyGuidelinesScreenState();
}

class _SafetyGuidelinesScreenState extends State<SafetyGuidelinesScreen> {
  bool _continuing = false;

  Future<void> _continue() async {
    setState(() => _continuing = true);
    try {
      await ApiClient.post('/auth/safety-seen');
    } catch (_) {
      // non-critical — worst case the screen shows again next login
    } finally {
      if (mounted) await context.read<AuthProvider>().refreshUser();
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6ED9A0), Color(0xFF2E9B5F)]),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.verified_user_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text('Keep it a good time',
                        style: GoogleFonts.bricolageGrotesque(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 23)),
                    const SizedBox(height: 6),
                    const Text('A few ground rules before you jump in.',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 13,
                            height: 1.5)),
                    const SizedBox(height: 20),
                    for (var i = 0; i < _kRules.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: i == _kRules.length - 1
                                        ? Colors.transparent
                                        : AppColors.border))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _kRules[i].colors),
                              ),
                              alignment: Alignment.center,
                              child: Icon(_kRules[i].icon,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_kRules[i].title,
                                      style: const TextStyle(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text(_kRules[i].body,
                                      style: const TextStyle(
                                          color: AppColors.textFaint,
                                          fontSize: 12,
                                          height: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: GestureDetector(
                onTap: _continuing ? null : _continue,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: _continuing
                        ? null
                        : const LinearGradient(colors: AppGradients.brand),
                    color: _continuing ? AppColors.surface2 : null,
                    boxShadow: _continuing
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
                    _continuing ? 'Saving…' : 'I understand, continue',
                    style: TextStyle(
                        color: _continuing ? AppColors.textFaint : Colors.white,
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
}
