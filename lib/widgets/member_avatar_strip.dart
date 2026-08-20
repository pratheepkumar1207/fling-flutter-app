import 'package:flutter/material.dart';
import '../core/profile_nav.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Small horizontal strip of framed circular avatars for "who's in this
/// room right now" on a Lobby room card — Dart port of the avatar row in
/// LobbyRoomCard.jsx. Expects the room map's `members` list (each with
/// userId/name/avatarUrl), same shape /rooms/browse already returns.
class MemberAvatarStrip extends StatelessWidget {
  final List<dynamic> members;
  const MemberAvatarStrip({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final m = members[i] as Map;
          return GestureDetector(
            onTap: () => openProfile(context, m['userId'] as String?),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppGradients.brand),
              ),
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
                child: Avatar(src: m['avatarUrl'] as String?, name: m['name'] as String?, size: AvatarSize.sm),
              ),
            ),
          );
        },
      ),
    );
  }
}
