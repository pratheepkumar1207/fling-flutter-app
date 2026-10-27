class DirectMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final String messageType; // 'text' | 'sticker' | 'gif' | 'image' | 'voice'
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    this.messageType = 'text',
    this.mediaUrl,
    required this.createdAt,
    this.readAt,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String,
      text: json['text'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'text',
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
    );
  }
}

/// Mirrors GET /messages/conversations — one row per participant.
class ConversationSummary {
  final String userId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastMessageIsMine;
  final int unreadCount;
  final bool online;

  /// Someone who isn't a friend or match started this and you haven't
  /// replied yet — shown under Requests.
  final bool isRequest;

  /// 'text' | 'image' | 'voice' | 'sticker' | 'gif'.
  final String lastMessageType;

  /// My last message has been read by them.
  final bool lastMessageSeen;

  /// The room they're in right now, when their privacy settings allow.
  final ConversationActivity? activity;

  ConversationSummary({
    required this.userId,
    required this.name,
    this.username,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    this.unreadCount = 0,
    this.online = false,
    this.isRequest = false,
    this.lastMessageType = 'text',
    this.lastMessageSeen = false,
    this.activity,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Unknown',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ??
              DateTime.now(),
      lastMessageIsMine: json['lastMessageIsMine'] as bool? ?? false,
      online: json['online'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isRequest: json['isRequest'] as bool? ?? false,
      lastMessageType: json['lastMessageType'] as String? ?? 'text',
      lastMessageSeen: json['lastMessageSeen'] as bool? ?? false,
      activity: json['activity'] is Map
          ? ConversationActivity.fromJson(
              Map<String, dynamic>.from(json['activity'] as Map))
          : null,
    );
  }
}

/// What someone in your inbox is doing now: the public room they're in.
class ConversationActivity {
  final String roomId;
  final String title;
  final String roomType; // watch | voice | live | game
  final String? gameType;
  final int memberCount;
  final String? nowPlayingTitle;
  final bool canJoin;

  const ConversationActivity({
    required this.roomId,
    required this.title,
    required this.roomType,
    this.gameType,
    this.memberCount = 0,
    this.nowPlayingTitle,
    this.canJoin = true,
  });

  factory ConversationActivity.fromJson(Map<String, dynamic> json) =>
      ConversationActivity(
        roomId: json['roomId'] as String,
        title: json['title'] as String? ?? 'a room',
        roomType: json['roomType'] as String? ?? 'voice',
        gameType: json['gameType'] as String?,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        nowPlayingTitle: json['nowPlayingTitle'] as String?,
        canJoin: json['canJoin'] as bool? ?? true,
      );
}
