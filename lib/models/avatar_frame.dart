/// Mirrors AvatarFrame.js / GET /store/avatar-frames.
class AvatarFrame {
  final String id;
  final String name;
  final String imageUrl;
  final int coinCost;
  final bool owned;
  final bool equipped;

  AvatarFrame({required this.id, required this.name, required this.imageUrl, required this.coinCost, this.owned = false, this.equipped = false});

  factory AvatarFrame.fromJson(Map<String, dynamic> json) {
    return AvatarFrame(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      coinCost: json['coinCost'] as int? ?? 0,
      owned: json['owned'] as bool? ?? false,
      equipped: json['equipped'] as bool? ?? false,
    );
  }
}
