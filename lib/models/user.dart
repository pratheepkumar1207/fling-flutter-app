/// Mirrors serializeUser() in the backend's src/routes/auth.js.
class User {
  final String id;
  final String name;
  final String? username;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final List<String> interests;
  final List<String> languages;
  final String? city;
  final int? age;
  final String? gender;
  final String? lookingFor;
  final int? height;
  final String? orientation;
  final String? smoking;
  final String? drinking;
  final String? hasKids;
  final String? religion;
  final List<Map<String, dynamic>> prompts;
  final bool ageConfirmed18;
  final DateTime? safetyGuidelinesSeenAt;
  final String photoVerificationStatus;
  final String? verificationSelfieUrl;
  final String livestreamStatus;
  final bool hideOnlineStatus;
  final bool safeModeEnabled;
  final bool pushNotificationsEnabled;
  final bool locationSharingEnabled;
  final DateTime? usernameChangedAt;
  final int xp;
  final int level;
  final bool isVip;
  final DateTime? vipExpiresAt;
  final bool isVerified;
  final bool isFake;
  final String? equippedFrameId;
  final String? equippedCarId;
  final DateTime? carExpiresAt;
  final double coinBalance;
  final int galleryCount;
  final bool profileComplete;
  final int completenessPercent;
  final DateTime? lastSpinAt;

  User({
    required this.id,
    required this.name,
    this.username,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.interests = const [],
    this.languages = const [],
    this.city,
    this.age,
    this.gender,
    this.lookingFor,
    this.height,
    this.orientation,
    this.smoking,
    this.drinking,
    this.hasKids,
    this.religion,
    this.prompts = const [],
    this.ageConfirmed18 = false,
    this.safetyGuidelinesSeenAt,
    this.photoVerificationStatus = 'none',
    this.verificationSelfieUrl,
    this.livestreamStatus = 'none',
    this.hideOnlineStatus = false,
    this.safeModeEnabled = false,
    this.pushNotificationsEnabled = true,
    this.locationSharingEnabled = false,
    this.usernameChangedAt,
    this.xp = 0,
    this.level = 1,
    this.isVip = false,
    this.vipExpiresAt,
    this.isVerified = false,
    this.isFake = false,
    this.equippedFrameId,
    this.equippedCarId,
    this.carExpiresAt,
    this.coinBalance = 0,
    this.galleryCount = 0,
    this.profileComplete = true,
    this.completenessPercent = 100,
    this.lastSpinAt,
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
      languages: (json['languages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      city: json['city'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      lookingFor: json['lookingFor'] as String?,
      height: json['height'] as int?,
      orientation: json['orientation'] as String?,
      smoking: json['smoking'] as String?,
      drinking: json['drinking'] as String?,
      hasKids: json['hasKids'] as String?,
      religion: json['religion'] as String?,
      prompts: (json['prompts'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      ageConfirmed18: json['ageConfirmed18'] as bool? ?? false,
      safetyGuidelinesSeenAt: json['safetyGuidelinesSeenAt'] != null ? DateTime.tryParse(json['safetyGuidelinesSeenAt'] as String) : null,
      photoVerificationStatus: json['photoVerificationStatus'] as String? ?? 'none',
      verificationSelfieUrl: json['verificationSelfieUrl'] as String?,
      livestreamStatus: json['livestreamStatus'] as String? ?? 'none',
      hideOnlineStatus: json['hideOnlineStatus'] as bool? ?? false,
      safeModeEnabled: json['safeModeEnabled'] as bool? ?? false,
      pushNotificationsEnabled: json['pushNotificationsEnabled'] as bool? ?? true,
      locationSharingEnabled: json['locationSharingEnabled'] as bool? ?? false,
      usernameChangedAt: json['usernameChangedAt'] != null ? DateTime.tryParse(json['usernameChangedAt'] as String) : null,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      isVip: json['isVip'] as bool? ?? false,
      vipExpiresAt: json['vipExpiresAt'] != null ? DateTime.tryParse(json['vipExpiresAt']) : null,
      isVerified: json['isVerified'] as bool? ?? false,
      isFake: json['isFake'] as bool? ?? false,
      equippedFrameId: json['equippedFrameId'] as String?,
      equippedCarId: json['equippedCarId'] as String?,
      carExpiresAt: json['carExpiresAt'] != null ? DateTime.tryParse(json['carExpiresAt'] as String) : null,
      coinBalance: _parseDouble(json['coinBalance']),
      galleryCount: json['galleryCount'] as int? ?? 0,
      // Older cached responses (or endpoints that don't compute it) won't
      // have this field at all — default true so we don't wrongly gate an
      // existing account behind the completion screen.
      profileComplete: json['profileComplete'] as bool? ?? true,
      completenessPercent: json['completenessPercent'] as int? ?? 100,
      lastSpinAt: json['lastSpinAt'] != null ? DateTime.tryParse(json['lastSpinAt'].toString()) : null,
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
  final List<String> languages;
  final String? religion;
  final String? lookingFor;
  final String? city;
  final int? age;
  final String? gender;
  final bool online;
  final int sharedInterests;
  final String? equippedFrameId;

  DiscoverProfile({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    this.interests = const [],
    this.languages = const [],
    this.religion,
    this.lookingFor,
    this.city,
    this.age,
    this.gender,
    this.online = false,
    this.sharedInterests = 0,
    this.equippedFrameId,
  });

  factory DiscoverProfile.fromJson(Map<String, dynamic> json) {
    return DiscoverProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      interests: (json['interests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      languages: (json['languages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      religion: json['religion'] as String?,
      lookingFor: json['lookingFor'] as String?,
      city: json['city'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      online: json['online'] as bool? ?? false,
      sharedInterests: json['sharedInterests'] as int? ?? 0,
      equippedFrameId: json['equippedFrameId'] as String?,
    );
  }
}
