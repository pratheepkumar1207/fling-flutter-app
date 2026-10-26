import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';

const _kRules = [
  (
    icon: InIcons.verified,
    color: AppColors.blue,
    tile: Color(0xFF122046),
    title: 'Be who you say you are',
    body: 'Use real photos and your real age. Fake profiles get suspended.',
  ),
  (
    icon: InIcons.heart,
    color: AppColors.pink,
    tile: Color(0xFF2A1028),
    title: 'Keep it respectful',
    body: 'No hate, harassment or unwanted explicit content.',
  ),
  (
    icon: InIcons.lock,
    color: AppColors.gold,
    tile: Color(0xFF2A2310),
    title: 'Never share money or passwords',
    body: 'Insync will never ask for your OTP or bank details in chat.',
  ),
  (
    icon: InIcons.flame,
    color: Color(0xFFFF9F5A),
    tile: Color(0xFF2A1A10),
    title: 'Report anything that feels off',
    body:
        'Tap ••• on any profile, message, room or post. We review every case.',
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
  /// Opened from Sign in before an account exists: just read and go back.
  final bool previewOnly;
  const SafetyGuidelinesScreen({super.key, this.previewOnly = false});

  @override
  State<SafetyGuidelinesScreen> createState() => _SafetyGuidelinesScreenState();
}

class _SafetyGuidelinesScreenState extends State<SafetyGuidelinesScreen> {
  bool _continuing = false;

  Future<void> _continue() async {
    if (widget.previewOnly) {
      Navigator.of(context).pop();
      return;
    }
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
                    if (widget.previewOnly)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InIconButton(InIcons.back,
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop()),
                      ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                          color: const Color(0xFF0F2216),
                          borderRadius: BorderRadius.circular(20)),
                      alignment: Alignment.center,
                      child: const InIcon(InIcons.shield,
                          size: 32, color: AppColors.success),
                    ),
                    const SizedBox(height: 16),
                    const Text('Keep Insync a good time',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            letterSpacing: -0.5)),
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
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: _kRules[i].tile,
                                  borderRadius: BorderRadius.circular(13)),
                              alignment: Alignment.center,
                              child: InIcon(_kRules[i].icon,
                                  size: 22, color: _kRules[i].color),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_kRules[i].title,
                                      style: const TextStyle(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
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
              child: FilledButton(
                onPressed: _continuing ? null : _continue,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Text(_continuing
                    ? 'Saving…'
                    : (widget.previewOnly
                        ? 'Got it'
                        : 'I understand, continue')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
