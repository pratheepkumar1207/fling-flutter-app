import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../models/room_models.dart';
import '../theme/app_colors.dart';
import '../theme/club_room_colors.dart';
import 'avatar.dart';

/// Speaker stage + listener grid for Voice rooms — matches VoiceRoomDark.dc.html:
/// plain "Speakers · N" / "Listening · N" sections directly on the room
/// background, not wrapped in a bordered card (that was old-app styling,
/// not in the mockup). Occupied speaker slots show whoever the host has
/// approved/invited onto the stage; everyone else in the roster shows in
/// the listener grid below. The host-only pending-request approval strip
/// sits above the speaker grid.
class VoiceStageView extends StatelessWidget {
  final List<RosterEntry> roster;
  final List<String> activeMics;
  final List<String> pendingRequests;
  final int maxSlots;
  final String? hostId;
  final String? myUserId;
  final bool isHost;
  final void Function(String userId) onApprove;
  final void Function(String userId) onDeny;
  final void Function(String userId) onRemove;

  const VoiceStageView({
    super.key,
    required this.roster,
    required this.activeMics,
    required this.pendingRequests,
    required this.maxSlots,
    required this.hostId,
    required this.myUserId,
    required this.isHost,
    required this.onApprove,
    required this.onDeny,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final r in roster) r.userId: r};
    final activeSet = activeMics.toSet();
    final slots = List<String?>.generate(
        maxSlots, (i) => i < activeMics.length ? activeMics[i] : null);
    final listeners =
        roster.where((r) => !activeSet.contains(r.userId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isHost && pendingRequests.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ClubRoomColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ClubRoomColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pendingRequests.length} request${pendingRequests.length == 1 ? '' : 's'} to talk',
                  style: const TextStyle(
                      color: ClubRoomColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                const SizedBox(height: 6),
                ...pendingRequests.map((uid) {
                  final p = byId[uid];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => openProfile(context, uid),
                          child: Row(
                            children: [
                              Avatar(
                                  src: p?.avatarUrl,
                                  name: p?.name,
                                  size: AvatarSize.sm),
                              const SizedBox(width: 8),
                              Text(p?.name ?? 'Someone',
                                  style: const TextStyle(
                                      color: ClubRoomColors.text,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => onApprove(uid),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: ClubRoomColors.primary,
                                    borderRadius: BorderRadius.circular(999)),
                                child: const Text('Approve',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => onDeny(uid),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: ClubRoomColors.border)),
                                child: const Text('Deny',
                                    style: TextStyle(
                                        color: ClubRoomColors.textDim,
                                        fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        Text('SPEAKERS · ${activeMics.length}',
            style: const TextStyle(
                color: ClubRoomColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 16,
          children: List.generate(maxSlots, (i) {
            final uid = slots[i];
            final p = uid != null ? byId[uid] : null;
            final isMe = uid == myUserId;
            final isHostSlot = p != null && uid == hostId;
            return SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      p != null
                          ? GestureDetector(
                              onTap: () => openProfile(context, uid),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: isHostSlot
                                      ? const LinearGradient(
                                          colors: AppGradients.brand)
                                      : null,
                                  color:
                                      isHostSlot ? null : ClubRoomColors.border,
                                ),
                                child: Avatar(
                                    src: p.avatarUrl,
                                    name: p.name,
                                    size: AvatarSize.lg),
                              ),
                            )
                          : Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: ClubRoomColors.border,
                                      width: 1.5,
                                      style: BorderStyle.solid)),
                              alignment: Alignment.center,
                              child: const Icon(Icons.add_rounded,
                                  color: ClubRoomColors.textFaint, size: 20),
                            ),
                      if (isHost && p != null && uid != hostId)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: GestureDetector(
                            onTap: () => onRemove(uid!),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: ClubRoomColors.danger,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: ClubRoomColors.surface, width: 2)),
                              alignment: Alignment.center,
                              child: const Icon(Icons.close,
                                  size: 10, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p != null ? (isMe ? 'You' : p.name) : 'Open seat',
                    style: TextStyle(
                        color: p != null
                            ? ClubRoomColors.text
                            : ClubRoomColors.textFaint,
                        fontSize: 11,
                        fontWeight:
                            p != null ? FontWeight.w600 : FontWeight.normal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isHostSlot)
                    const Text('HOST',
                        style: TextStyle(
                            color: ClubRoomColors.gold,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ),
        if (listeners.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('LISTENING · ${listeners.length}',
              style: const TextStyle(
                  color: ClubRoomColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: listeners
                .map((p) => GestureDetector(
                    onTap: () => openProfile(context, p.userId),
                    child: Avatar(
                        src: p.avatarUrl, name: p.name, size: AvatarSize.md)))
                .toList(),
          ),
        ],
      ],
    );
  }
}
