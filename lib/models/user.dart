/// Mirrors serializeUser() in the backend's src/routes/auth.js.
class User {
  final String id;
  final String name;
  final String? username;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final List<String> interests;
  final String? city;
  final int? age;
  final String? gender;
  final bool hideOnlineStatus;
  final bool safeModeEnabled;
  final DateTime? usernameChangedAt;
  final int xp;
  final int level;
  final bool isVip;
  final DateTime? vipExpiresAt;
  final bool isVerified;
  final double coinBalance;

  User({
    required this.id,
    required this.name,
    this.username,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.interests = const [],
    this.city,
    this.age,
    this.gender,
    this.hideOnlineStatus = false,
    this.safeModeEnabled = false,
    this.usernameChangedAt,
    this.xp = 0,
    this.level = 1,
    this.isVip = false,
    this.vipExpiresAt,
    this.isVerified = false,
    this.coinBalance = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      interests: (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      city: json['city'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      hideOnlineStatus: json['hideOnlineStatus'] as bool? ?? false,
      safeModeEnabled: json['safeModeEnabled'] as bool? ?? false,
      usernameChangedAt: json['usernameChangedAt'] != null ? DateTime.tryParse(json['usernameChangedAt'] as String) : null,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      isVip: json['isVip'] as bool? ?? false,
      vipExpiresAt: json['vipExpiresAt'] != null ? DateTime.tryParse(json['vipExpiresAt']) : null,
      isVerified: json['isVerified'] as bool? ?? false,
      coinBalance: _parseDouble(json['coinBalance']),
    );
  }

  // Postgres DECIMAL columns (coinBalance is DECIMAL(12,2)) come back from
  // Sequelize/pg as JSON strings (e.g. "10.00"), not numbers — a well-known
  // driver quirk to avoid floating-point precision loss. A plain `as num?`
  // cast throws on that shape, so parse defensively from either.
  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

/// A candidate profile as returned by GET /discover — a narrower, public
/// shape than User (see src/routes/discover.js — isVerified/isVip are
/// deliberately excluded from this endpoint, so don't add them here).
class DiscoverProfile {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final List<String> interests;
  final String? city;
  final int? age;
  final String? gender;
  final bool online;
  final int sharedInterests;

  DiscoverProfile({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    this.interests = const [],
    this.city,
    this.age,
    this.gender,
    this.online = false,
    this.sharedInterests = 0,
  });

  factory DiscoverProfile.fromJson(Map<String, dynamic> json) {
    return DiscoverProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      interests: (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      city: json['city'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      online: json['online'] as bool? ?? false,
      sharedInterests: json['sharedInterests'] as int? ?? 0,
    );
  }
}
