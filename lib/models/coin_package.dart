/// Mirrors CoinPackage.js — an admin-managed purchasable coin bundle.
class CoinPackage {
  final String id;
  final String name;
  final int coins;
  final double priceRupees;

  /// The Google Play / App Store product id for this pack.
  final String? storeProductId;

  CoinPackage(
      {required this.id,
      required this.name,
      required this.coins,
      required this.priceRupees,
      this.storeProductId});

  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    return CoinPackage(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      coins: json['coins'] as int? ?? 0,
      priceRupees: _parseDouble(json['priceRupees']),
      storeProductId: json['storeProductId'] as String?,
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
