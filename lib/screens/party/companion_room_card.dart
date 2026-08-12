import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';

/// Netflix/Prime rooms are companion-only: chat/voice/roster stay fully in
/// the app, but there's no embedded player and nothing to sign into here at
/// all. Netflix's own bot detection blocks third-party embedded logins
/// outright (confirmed live — see the room-type-switch/Netflix work this
/// session), and there's no legitimate way around that from inside a
/// WebView. So instead: everyone taps this to open their own native
/// Netflix/Prime app (or its website, if the app isn't installed — the OS
/// handles that fallback via universal links) on their own device, signed
/// into their own account, same as if they'd tapped the app icon directly.
/// The room's only job is the social layer running alongside it.
class CompanionRoomCard extends StatelessWidget {
  final String platform; // 'netflix' | 'amazon'
  final bool compact;

  const CompanionRoomCard({super.key, required this.platform, this.compact = false});

  String get _label => platform == 'netflix' ? 'Netflix' : 'Prime Video';
  String get _emoji => platform == 'netflix' ? '🎬' : '📦';
  String get _url => platform == 'netflix' ? 'https://www.netflix.com' : 'https://www.primevideo.com';

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $_label')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Text(_emoji, style: TextStyle(fontSize: compact ? 24 : 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_label party', style: TextStyle(color: AppColors.text, fontSize: compact ? 13 : 15, fontWeight: FontWeight.w700)),
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Everyone opens their own $_label app and presses play together — chat and vibe here while you watch.',
                      style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _open(context),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            child: Text('Open $_label', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
