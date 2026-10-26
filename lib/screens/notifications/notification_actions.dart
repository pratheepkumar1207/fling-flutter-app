import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';
import '../feed/post_detail_screen.dart';
import '../blend/blend_screen.dart';
import '../friends/friends_screen.dart';
import '../messages/message_thread_screen.dart';
import '../party/party_screen.dart';
import '../profile/creator_profile_screen.dart';

/// Where tapping a notification goes, shared by the bell dropdown and the
/// full Notifications screen. Types come from the backend's
/// services/notifications.js; unknown types (and 'broadcast') just mark read.
void openNotificationTarget(BuildContext context, NotificationItem n) {
  final data = n.data ?? const {};
  Widget? target;
  switch (n.type) {
    case 'room_invite':
      final roomId = data['roomId'] as String?;
      if (roomId != null) target = PartyScreen(roomId: roomId);
    case 'mention' || 'like' || 'comment':
      final postId = data['postId'] as String?;
      if (postId != null) target = PostDetailScreen(postId: postId);
    case 'follow':
      final userId = data['fromUserId'] as String?;
      if (userId != null) target = CreatorProfileScreen(userId: userId);
    case 'friend_request' || 'friend_accept':
      target = const FriendsScreen();
    case 'blend_invite' || 'blend_watch':
      final blendId = data['blendId'] as String?;
      if (blendId != null) target = BlendScreen(blendId: blendId);
    case 'match':
      final userId = data['userId'] as String?;
      if (userId != null) {
        target = MessageThreadScreen(
            userId: userId, name: (data['name'] as String?) ?? 'Your match');
      }
  }
  if (target != null) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => target!));
  }
}

InIconData notificationIcon(String type) => switch (type) {
      'room_invite' => InIcons.tv,
      'mention' => InIcons.mail,
      'like' => InIcons.heart,
      'comment' => InIcons.chat,
      'follow' => InIcons.useradd,
      'friend_request' || 'friend_accept' => InIcons.users,
      'match' => InIcons.flame,
      'blend_invite' || 'blend_watch' => InIcons.blend,
      'broadcast' => InIcons.bell,
      _ => InIcons.bell,
    };

List<Color> notificationColors(String type) => switch (type) {
      'room_invite' => const [AppColors.accent2, AppColors.primary],
      'mention' => const [AppColors.gold, Color(0xFFC98F3A)],
      'like' || 'match' => const [AppColors.danger, Color(0xFFE0567A)],
      'friend_request' || 'friend_accept' || 'follow' => const [
          AppColors.success,
          AppColors.primary
        ],
      _ => const [AppColors.accent, AppColors.primaryDim],
    };
