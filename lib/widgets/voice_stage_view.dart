import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../models/room_models.dart';
import '../theme/club_room_colors.dart';
import 'avatar.dart';

/// 8-slot mic stage for Voice rooms — occupied slots show whoever the host
/// has approved/invited onto the stage; empty slots are just visual
/// placeholders. Everyone else in the roster (not shown here) is audience.
/// The host-only pending-request approval strip sits above the grid.
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
    final slots = List<String?>.generate(maxSlots, (i) => i < activeMics.length ? activeMics[i] : null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ClubRoomColors.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: ClubRoomColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHost && pendingRequests.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ClubRoomColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClubRoomColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pendingRequests.length} request${pendingRequests.length == 1 ? '' : 's'} to talk',
                    style: const TextStyle(color: ClubRoomColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
                                Avatar(src: p?.avatarUrl, name: p?.name, size: AvatarSize.sm),
                                const SizedBox(width: 8),
                                Text(p?.name ?? 'Someone', style: const TextStyle(color: ClubRoomColors.text, fontSize: 13)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => onApprove(uid),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: ClubRoomColors.primary, borderRadius: BorderRadius.circular(999)),
                                  child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => onDeny(uid),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: ClubRoomColors.border)),
                                  child: const Text('Deny', style: TextStyle(color: ClubRoomColors.textDim, fontSize: 11)),
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: maxSlots,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 8, childAspectRatio: 0.8),
            itemBuilder: (context, i) {
              final uid = slots[i];
              final p = uid != null ? byId[uid] : null;
              final isMe = uid == myUserId;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      p != null
                          ? GestureDetector(onTap: () => openProfile(context, uid), child: Avatar(src: p.avatarUrl, name: p.name, size: AvatarSize.md))
                          : Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ClubRoomColors.border, style: BorderStyle.solid)),
                              alignment: Alignment.center,
                              child: const Text('🎙️', style: TextStyle(fontSize: 18, color: ClubRoomColors.textFaint)),
                            ),
                      if (p != null && uid == hostId)
                        const Positioned(top: -2, right: -2, child: Text('👑', style: TextStyle(fontSize: 12))),
                      if (isHost && p != null && uid != hostId)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: GestureDetector(
                            onTap: () => onRemove(uid!),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(color: ClubRoomColors.danger, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.close, size: 10, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p != null ? (isMe ? 'You' : p.name) : '',
                    style: const TextStyle(color: ClubRoomColors.textDim, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
