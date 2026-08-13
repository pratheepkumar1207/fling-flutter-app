/// Mirrors AdmissionCar.js / GET /store/admission-cars.
class AdmissionCar {
  final String id;
  final String name;
  final String imageUrl;
  final int coinCost;
  final int durationDays;
  final bool owned;
  final bool equipped;

  AdmissionCar({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.coinCost,
    required this.durationDays,
    this.owned = false,
    this.equipped = false,
  });

  factory AdmissionCar.fromJson(Map<String, dynamic> json) {
    return AdmissionCar(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      coinCost: json['coinCost'] as int? ?? 0,
      durationDays: json['durationDays'] as int? ?? 15,
      owned: json['owned'] as bool? ?? false,
      equipped: json['equipped'] as bool? ?? false,
    );
  }
}
