import 'package:flutter/material.dart';

import '../core/room_prefs.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

/// "Your settings" for a room: push to talk, the voices-vs-video balance
/// and picture-in-picture. Personal — nothing here changes the room for
/// anyone else (that's the host's room settings sheet).
Future<void> showGuestSettingsSheet(
  BuildContext context, {
  bool onStage = false,
  VoidCallback? onLeaveMic,
  bool hasVideo = true,
}) {
  RoomPrefs.instance.load();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AnimatedBuilder(
      animation: RoomPrefs.instance,
      builder: (context, _) {
        final prefs = RoomPrefs.instance;
        final b = prefs.balance;
        final mix = b < 0.45
            ? 'Voices louder'
            : b > 0.55
                ? 'Video louder'
                : 'Both at full volume';
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                18, 10, 18, 18 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999))),
                ),
                const SizedBox(height: 14),
                Text('Your settings',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text(
                    'Only for you — the room stays the same for everyone else.',
                    style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                const SizedBox(height: 16),
                _Card(children: [
                  _SwitchRow(
                    icon: InIcons.mic,
                    title: 'Push to talk',
                    subtitle: 'On the mic, hold the mic button to speak.',
                    value: prefs.pushToTalk,
                    onChanged: prefs.setPushToTalk,
                  ),
                  if (onStage && onLeaveMic != null) ...[
                    const Divider(height: 1, color: AppColors.border),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      leading: const InIcon(InIcons.micoff,
                          size: 20, color: AppColors.pink),
                      title: const Text('Leave the mic',
                          style: TextStyle(color: AppColors.pink)),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onLeaveMic();
                      },
                    ),
                  ],
                ]),
                if (hasVideo) ...[
                  const SizedBox(height: 12),
                  _Card(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                      child: Row(children: [
                        const InIcon(InIcons.speaker,
                            size: 20, color: AppColors.lilac),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Voices and video',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Flexible(
                          child: Text(mix,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  color: AppColors.textDim, fontSize: 12.5)),
                        ),
                      ]),
                    ),
                    Slider(
                      value: b,
                      divisions: 20,
                      label: mix,
                      onChanged: prefs.setBalance,
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Row(children: [
                        InIcon(InIcons.users,
                            size: 15, color: AppColors.textFaint),
                        SizedBox(width: 6),
                        Text('Voices',
                            style: TextStyle(
                                color: AppColors.textFaint, fontSize: 12)),
                        Spacer(),
                        Text('Video',
                            style: TextStyle(
                                color: AppColors.textFaint, fontSize: 12)),
                        SizedBox(width: 6),
                        InIcon(InIcons.film,
                            size: 15, color: AppColors.textFaint),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _Card(children: [
                    _SwitchRow(
                      icon: InIcons.pip,
                      title: 'Picture-in-picture',
                      subtitle:
                          'Keep watching in a small window when you leave the app.',
                      value: prefs.autoPip,
                      onChanged: prefs.setAutoPip,
                    ),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final InIconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      secondary: InIcon(icon, size: 20, color: AppColors.lilac),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
      value: value,
      onChanged: onChanged,
    );
  }
}
