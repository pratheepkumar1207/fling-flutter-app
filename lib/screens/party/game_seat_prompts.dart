import 'package:flutter/material.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/vola_party_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/glass.dart';

/// The banner over the game for a seat request (host: "X wants to play")
/// or an invite (guest: "X invited you to play"). Two actions, one line.
class GameSeatBanner extends StatelessWidget {
  final RosterEntry? person;
  final String text;
  final String acceptLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final int more;

  const GameSeatBanner({
    super.key,
    required this.person,
    required this.text,
    required this.acceptLabel,
    required this.onAccept,
    required this.onDecline,
    this.more = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2A12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Avatar(
                src: person?.avatarUrl,
                name: person?.name,
                size: AvatarSize.sm),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                more > 0 ? '$text  ·  +$more more' : text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.ink,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              child: Text(acceptLabel),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onDecline,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textDim,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Host picks who to invite to the game — everyone in the room who isn't
/// already playing (and isn't the host).
Future<void> showGameInvitePicker(
  BuildContext context, {
  required List<RosterEntry> roster,
  required Set<String> playerIds,
  required Set<String> invitedIds,
  required String? myUserId,
  required void Function(String userId) onInvite,
}) {
  final candidates = [
    for (final r in roster)
      if (r.userId != myUserId && !playerIds.contains(r.userId)) r
  ];
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (sheetContext) => SafeArea(
      child: GlassPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        tintAlpha: 0.85,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999))),
                ),
                const Text('Invite to play',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Everyone here is already playing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VolaPartyColors.textDim)),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in candidates)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Avatar(
                                src: r.avatarUrl,
                                name: r.name,
                                size: AvatarSize.sm),
                            title: Text(r.name,
                                style: const TextStyle(
                                    color: AppColors.text, fontSize: 14)),
                            trailing: invitedIds.contains(r.userId)
                                ? const Text('Invited',
                                    style: TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 12.5))
                                : FilledButton(
                                    onPressed: () {
                                      onInvite(r.userId);
                                      Navigator.of(sheetContext).pop();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: AppColors.ink,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Invite'),
                                  ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
