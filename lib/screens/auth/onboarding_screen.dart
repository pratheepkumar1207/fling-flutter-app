import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../settings/legal_screen.dart';
import 'login_screen.dart';

const _kSeenKey = 'onboarding_seen';

/// Front page from the approved design: logo, floating tiles for what you
/// can do together, the headline and one "Get started" button. Sign-in
/// itself lives in LoginScreen.
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
  static Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }

  Future<void> _continue() async {
    await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _openLegal(String kind) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => kind == 'terms'
          ? const LegalScreen(
              title: 'Terms of Service', sections: kTermsOfServiceSections)
          : const LegalScreen(
              title: 'Privacy Policy', sections: kPrivacyPolicySections)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.6, -0.9),
            radius: 0.9,
            colors: [Color(0xFF3A1430), Colors.transparent],
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8, 0),
              radius: 0.9,
              colors: [Color(0xFF14204A), Colors.transparent],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 44),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Image.asset('assets/icon/insync-symbol.png',
                              height: 30, semanticLabel: 'Insync'),
                          const SizedBox(width: 8),
                          const Text('insync',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5)),
                        ]),
                        const Expanded(child: _Tiles()),
                        const Text('Your people.\nYour kind of moment.',
                            style: TextStyle(
                                fontSize: 32,
                                height: 1.12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1)),
                        const SizedBox(height: 12),
                        const Text(
                            'Watch together, talk, play games and meet new people.',
                            style: TextStyle(
                                color: AppColors.textDim,
                                fontSize: 15,
                                height: 1.45)),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          child: const Text('Get started'),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('By continuing you agree to our ',
                                style: TextStyle(
                                    color: AppColors.textFaint, fontSize: 12)),
                            _Link('Terms', () => _openLegal('terms')),
                            const Text(' and ',
                                style: TextStyle(
                                    color: AppColors.textFaint, fontSize: 12)),
                            _Link(
                                'Privacy Policy', () => _openLegal('privacy')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Link(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.lilac,
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.lilac)),
      ),
    );
  }
}

/// Floating tiles: Watch, Talk, Play, Match, Blend.
class _Tiles extends StatelessWidget {
  const _Tiles();

  static const _tiles = <(Alignment, double, Color, InIconData, Color, String)>[
    (
      Alignment(-1, -0.75),
      116,
      Color(0xFF2A1028),
      InIcons.tv,
      AppColors.pink,
      'Watch'
    ),
    (
      Alignment(1, -1),
      104,
      Color(0xFF1C1638),
      InIcons.mic,
      Color(0xFFB97CF8),
      'Talk'
    ),
    (
      Alignment(-0.15, 0.2),
      116,
      Color(0xFF122046),
      InIcons.game,
      Color(0xFF6E95FD),
      'Play'
    ),
    (
      Alignment(0.95, 0.05),
      88,
      Color(0xFF2A1028),
      InIcons.flame,
      AppColors.pink,
      'Match'
    ),
    (
      Alignment(-0.92, 1),
      92,
      Color(0xFF1C1638),
      InIcons.blend,
      Color(0xFFB97CF8),
      'Blend'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Stack(children: [
            for (final t in _tiles)
              Align(
                alignment: t.$1,
                child: Container(
                  width: t.$2,
                  height: t.$2,
                  decoration: BoxDecoration(
                    color: t.$3,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InIcon(t.$4, size: 26, color: t.$5),
                        const SizedBox(height: 6),
                        Text(t.$6, style: const TextStyle(fontSize: 12)),
                      ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
