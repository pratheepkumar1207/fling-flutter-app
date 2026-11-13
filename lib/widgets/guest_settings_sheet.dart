import 'package:flutter/material.dart';

import '../core/room_prefs.dart';
import '../theme/insync_icons.dart';
import 'room_sheet.dart';

/// Room settings in someone else's room: the voices/video balance, this
/// person's own switches and Report room. Personal — nothing here changes
/// the room for anyone else (that's the host's room settings sheet, which
/// shows the same personal part under the room's own options).
Future<void> showGuestSettingsSheet(
  BuildContext context, {
  // Kept for callers; leaving the mic is on the mic button now.
  bool onStage = false,
  VoidCallback? onLeaveMic,
  bool hasVideo = true,
  String? roomTitle,
  String? hostName,
  VoidCallback? onReport,
  double halfFraction = 0.62,
}) {
  RoomPrefs.instance.load();
  return showRoomSheet(
    context,
    halfFraction: halfFraction,
    builder: (sheetContext, scroll) => ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(sheetContext).padding.bottom),
      children: [
        const RoomSheetHandle(),
        RoomPersonalSettings(hasVideo: hasVideo, topLabel: false),
        if (onReport != null) ...[
          const SizedBox(height: 18),
          RoomSheetButton(
            icon: InIcons.shield,
            label: 'Report room',
            onTap: () {
              Navigator.of(sheetContext).pop();
              onReport();
            },
          ),
        ],
      ],
    ),
  );
}

/// The personal part of a room's settings: the voices/video bar and a grid
/// of this person's own switches. Saved on this phone only (RoomPrefs).
class RoomPersonalSettings extends StatelessWidget {
  final bool hasVideo;
  // The sound bar's label sits flush at the top of the guest sheet.
  final bool topLabel;
  const RoomPersonalSettings(
      {super.key, this.hasVideo = true, this.topLabel = true});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: RoomPrefs.instance,
      builder: (context, _) {
        final p = RoomPrefs.instance;
        final cards = <Widget>[
          RoomToggleCard(
              icon: InIcons.mic,
              label: 'Hold mic button to talk',
              on: p.pushToTalk,
              onChanged: p.setPushToTalk),
          RoomToggleCard(
              icon: InIcons.bell,
              label: 'Sound for new messages',
              on: !p.muteAlerts,
              onChanged: (v) => p.setMuteAlerts(!v)),
          RoomToggleCard(
              icon: InIcons.gift,
              label: 'Show gift animations',
              on: p.giftAnimations,
              onChanged: p.setGiftAnimations),
          if (hasVideo) ...[
            RoomToggleCard(
                icon: InIcons.pip,
                label: 'Small video when I leave',
                on: p.autoPip,
                onChanged: p.setAutoPip),
            RoomToggleCard(
                icon: InIcons.chat,
                label: 'Chat over full-screen video',
                on: p.chatOverVideo,
                onChanged: p.setChatOverVideo),
          ],
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasVideo) ...[
              topLabel
                  ? const RoomSheetLabel('SOUND')
                  : const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('SOUND',
                          style: TextStyle(
                              color: kSheetDim,
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600)),
                    ),
              const Row(children: [
                InIcon(InIcons.users, size: 15, color: Color(0xFFBBBBBB)),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Voices louder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12)),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Video louder',
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12)),
                ),
                SizedBox(width: 6),
                InIcon(InIcons.film, size: 15, color: Color(0xFFBBBBBB)),
              ]),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: kSheetOnBorder,
                  inactiveTrackColor: const Color(0xFF333333),
                  thumbColor: Colors.white,
                  overlayShape: SliderComponentShape.noOverlay,
                  trackHeight: 4,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Slider(
                    value: p.balance,
                    divisions: 20,
                    semanticFormatterCallback: (v) => v < 0.45
                        ? 'Voices louder'
                        : v > 0.55
                            ? 'Video louder'
                            : 'Both at full volume',
                    onChanged: p.setBalance,
                  ),
                ),
              ),
            ],
            SizedBox(height: hasVideo ? 6 : 0),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - 12) / 3;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in cards) SizedBox(width: w, child: c)],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
