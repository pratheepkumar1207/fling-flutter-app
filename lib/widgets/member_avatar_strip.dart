import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Small horizontal strip of framed circular avatars for "who's in this
/// room right now" on a Lobby room card — Dart port of the avatar row in
/// LobbyRoomCard.jsx. Expects the room map's `members` list (each with
/// userId/name/avatarUrl), same shape /rooms/browse already returns
/// (a preview of up to 5). Genuinely scrollable (not just a fixed row) so
/// it still works if a caller passes more than fits on screen; pass
/// [totalCount] (the room's real member count) to show a trailing "+N"
/// bubble for everyone not included in the preview list.
class MemberAvatarStrip extends StatelessWidget {
  final List<dynamic> members;
  final int? totalCount;
  const MemberAvatarStrip({super.key, required this.members, this.totalCount});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final overflow = (totalCount ?? members.length) - members.length;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length + (overflow > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i >= members.length) {
            return Container(
              width: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.surface3),
              child: Text('+$overflow',
                  style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            );
          }
          final m = members[i] as Map;
          return GestureDetector(
            onTap: () => openProfile(context, m['userId'] as String?),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppGradients.brand),
              ),
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.bg),
                child: Avatar(
                    src: m['avatarUrl'] as String?,
                    name: m['name'] as String?,
                    size: AvatarSize.sm),
              ),
            ),
          );
        },
      ),
    );
  }
}
