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

IconData notificationIcon(String type) => switch (type) {
      'room_invite' => Icons.meeting_room_rounded,
      'mention' => Icons.alternate_email_rounded,
      'like' => Icons.favorite_rounded,
      'comment' => Icons.chat_bubble_rounded,
      'follow' => Icons.person_add_alt_1_rounded,
      'friend_request' || 'friend_accept' => Icons.people_alt_rounded,
      'match' => Icons.local_fire_department_rounded,
      'blend_invite' || 'blend_watch' => Icons.movie_filter_rounded,
      'broadcast' => Icons.campaign_rounded,
      _ => Icons.notifications_rounded,
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
