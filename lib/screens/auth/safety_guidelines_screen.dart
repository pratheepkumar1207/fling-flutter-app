import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/push_notifications.dart';
import '../../theme/app_colors.dart';

const _kTips = [
  ['🔒', "Keep personal details (address, workplace, financial info) private until you've built real trust."],
  ['📍', "Meet new people in public places first, and tell a friend where you're going."],
  ['🚩', 'Report or block anyone who pressures you, asks for money, or makes you uncomfortable — no explanation needed.'],
  ['🧑‍⚖️', 'Insync never asks for payment to "unlock" a match or conversation — that request is always a scam.'],
];

/// Shown once, right after CompleteProfileScreen — see SplashScreen, which
/// routes here whenever profileComplete is true but safetyGuidelinesSeenAt
/// is still null. Dart port of SafetyGuidelinesPage.jsx.
class SafetyGuidelinesScreen extends StatefulWidget {
  const SafetyGuidelinesScreen({super.key});

  @override
  State<SafetyGuidelinesScreen> createState() => _SafetyGuidelinesScreenState();
}

enum _NotifState { idle, requesting, granted, skipped }

class _SafetyGuidelinesScreenState extends State<SafetyGuidelinesScreen> {
  _NotifState _notifState = _NotifState.idle;
  bool _continuing = false;

  Future<void> _enableNotifications() async {
    setState(() => _notifState = _NotifState.requesting);
    final result = await requestPushPermissionAndRegister();
    if (!mounted) return;
    if (result == PushRequestResult.granted) {
      setState(() => _notifState = _NotifState.granted);
    } else {
      setState(() => _notifState = _NotifState.skipped);
      if (result == PushRequestResult.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications blocked — you can turn them on later in Settings.')),
        );
      }
    }
  }

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text('Before you jump in', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('A few quick things to keep in mind.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                const SizedBox(height: 20),
                for (final t in _kTips)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t[0], style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t[1], style: const TextStyle(color: AppColors.textDim, fontSize: 13))),
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stay in the loop', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Get notified about new matches, messages, and invites.', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                      const SizedBox(height: 10),
                      if (_notifState == _NotifState.granted)
                        const Text('🔔 Notifications enabled', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600))
                      else if (_notifState == _NotifState.skipped)
                        const Text('You can turn these on anytime in Settings.', style: TextStyle(color: AppColors.textFaint, fontSize: 11))
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _notifState == _NotifState.requesting ? null : _enableNotifications,
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                            child: Text(_notifState == _NotifState.requesting ? 'Requesting…' : 'Turn on notifications'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continuing ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_continuing ? 'Saving…' : "Got it, let's go"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
