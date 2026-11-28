class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  /// Who it's from (name and photo), when the server knows.
  final String? actorName;
  final String? actorAvatarUrl;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.actorName,
    this.actorAvatarUrl,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      actorName: (json['actor'] as Map?)?['name'] as String?,
      actorAvatarUrl: (json['actor'] as Map?)?['avatarUrl'] as String?,
    );
  }
}
