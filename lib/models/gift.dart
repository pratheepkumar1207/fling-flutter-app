/// One entry in the admin-managed gift catalog (GET /wallet/gifts) — the
/// price is decided server-side by `type`, the client only ever sends the
/// type back.
class Gift {
  final String id;
  final String type;
  final String emoji;
  final String name;
  final int coins;

  /// Gift sheet tab: popular | lucky | love | fan (fan club members only).
  final String category;

  /// Optional corner tag: HOT, NEW or LUCKY.
  final String? tag;

  Gift(
      {required this.id,
      required this.type,
      required this.emoji,
      required this.name,
      required this.coins,
      this.category = 'popular',
      this.tag});

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🎁',
      name: json['name'] as String? ?? '',
      coins: json['coins'] as int? ?? 0,
      category: json['category'] as String? ?? 'popular',
      tag: json['tag'] as String?,
    );
  }
}
