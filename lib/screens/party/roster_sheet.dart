import 'package:flutter/material.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';

class RosterSheet extends StatelessWidget {
  final List<RosterEntry> roster;
  final String? hostId;
  final bool isHost;
  final String? myUserId;
  final void Function(String userId) onKick;
  final void Function(String userId) onMakeHost;
  final String? roomType;
  final List<String>? activeMics;
  final void Function(String userId)? onInviteMic;

  const RosterSheet({
    super.key,
    required this.roster,
    required this.hostId,
    required this.isHost,
    required this.myUserId,
    required this.onKick,
    required this.onMakeHost,
    this.roomType,
    this.activeMics,
    this.onInviteMic,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('In this room', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.textFaint)),
              ],
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: roster.length,
                itemBuilder: (context, i) {
                  final r = roster[i];
                  final isRowHost = r.userId == hostId;
                  final isMe = r.userId == myUserId;
                  final canInviteMic = isHost && roomType == 'voice' && onInviteMic != null && !(activeMics?.contains(r.userId) ?? false);
                  return ListTile(
                    leading: Avatar(src: r.avatarUrl, name: r.name, size: AvatarSize.sm),
                    title: Text('${r.name}${isRowHost ? ' 👑' : ''}${isMe ? ' (you)' : ''}', style: const TextStyle(color: AppColors.text)),
                    trailing: (isHost && !isMe)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canInviteMic)
                                TextButton(onPressed: () => onInviteMic!(r.userId), child: const Text('🎙️ Invite', style: TextStyle(color: AppColors.gold, fontSize: 12))),
                              TextButton(onPressed: () => onMakeHost(r.userId), child: const Text('Make host', style: TextStyle(color: AppColors.primary, fontSize: 12))),
                              TextButton(onPressed: () => onKick(r.userId), child: const Text('Kick', style: TextStyle(color: AppColors.danger, fontSize: 12))),
                            ],
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
