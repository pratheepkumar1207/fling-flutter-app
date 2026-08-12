/// Mirrors Gift.js — an admin-managed gift catalog entry. `type` is the
/// stable key sent to POST /wallet/gift; coin cost is enforced server-side
/// from this catalog, not trusted from the client.
class Gift {
  final String id;
  final String type;
  final String emoji;
  final String name;
  final int coins;

  Gift({required this.id, required this.type, required this.emoji, required this.name, required this.coins});

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🎁',
      name: json['name'] as String? ?? '',
      coins: json['coins'] as int? ?? 0,
    );
  }
}
