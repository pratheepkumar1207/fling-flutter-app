class DirectMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final String messageType; // 'text' | 'sticker' | 'gif'
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
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
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

  ConversationSummary({
    required this.userId,
    required this.name,
    this.username,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageIsMine,
    this.unreadCount = 0,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Unknown',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ?? DateTime.now(),
      lastMessageIsMine: json['lastMessageIsMine'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
