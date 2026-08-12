/// Mirrors CoinPackage.js — an admin-managed purchasable coin bundle.
class CoinPackage {
  final String id;
  final String name;
  final int coins;
  final double priceRupees;

  CoinPackage({required this.id, required this.name, required this.coins, required this.priceRupees});

  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    return CoinPackage(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      coins: json['coins'] as int? ?? 0,
      priceRupees: _parseDouble(json['priceRupees']),
    );
  }

  // Postgres DECIMAL columns come back as JSON strings — same driver quirk
  // as User.coinBalance (see lib/models/user.dart).
  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
