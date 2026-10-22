import 'package:flutter/material.dart';

/// A Reels Blend — a shared feed of the reels its 2-8 members liked, that
/// they can watch together in sync. See the backend's routes/blends.js.
class BlendMember {
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  const BlendMember(
      {required this.id, required this.name, this.username, this.avatarUrl});

  factory BlendMember.fromJson(Map<String, dynamic> j) => BlendMember(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Someone',
        username: j['username'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );

  String get firstName => name.split(' ').first;
}

class Blend {
  final String id;
  final String? name;
  final bool isGroup;
  final String createdBy;
  final bool isCreator;
  final bool swipeSync;
  final String whoCanSwipe; // 'everyone' | 'creator'
  final bool micEnabled;
  final bool showOwnerTag;
  final List<BlendMember> members;
  final List<String> watching;

  const Blend({
    required this.id,
    this.name,
    required this.isGroup,
    required this.createdBy,
    required this.isCreator,
    required this.swipeSync,
    required this.whoCanSwipe,
    required this.micEnabled,
    required this.showOwnerTag,
    required this.members,
    required this.watching,
  });

  factory Blend.fromJson(Map<String, dynamic> j) => Blend(
        id: j['id'] as String,
        name: j['name'] as String?,
        isGroup: j['isGroup'] == true,
        createdBy: j['createdBy'] as String,
        isCreator: j['isCreator'] == true,
        swipeSync: j['swipeSync'] != false,
        whoCanSwipe: j['whoCanSwipe'] as String? ?? 'everyone',
        micEnabled: j['micEnabled'] == true,
        showOwnerTag: j['showOwnerTag'] != false,
        members: [
          for (final m in (j['members'] as List? ?? const []))
            BlendMember.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        watching: [
          for (final w in (j['watching'] as List? ?? const [])) w as String
        ],
      );

  List<BlendMember> others(String? myId) =>
      members.where((m) => m.id != myId).toList();

  BlendMember? member(String? id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  BlendMember? get creator => member(createdBy);

  /// "Bala", "Bala and Chitra", "Bala, Chitra and 2 more" — or the
  /// group's own name.
  String title(String? myId) {
    if (name != null && name!.isNotEmpty) return name!;
    final o = others(myId).map((m) => m.firstName).toList();
    if (o.isEmpty) return 'Blend';
    if (o.length == 1) return o.first;
    if (o.length == 2) return '${o[0]} and ${o[1]}';
    return '${o[0]}, ${o[1]} and ${o.length - 2} more';
  }

  /// Whether [myId] may swipe/pause for everyone.
  bool canDrive(String? myId) =>
      swipeSync && (whoCanSwipe == 'everyone' || createdBy == myId);
}

/// One colour per member, in member order — the mix bar, reel tags and
/// avatars use the same one for the same person.
const blendMemberColors = [
  Color(0xFF1D9E75),
  Color(0xFFD4537E),
  Color(0xFF7F77DD),
  Color(0xFFEF9F27),
  Color(0xFF378ADD),
  Color(0xFFD85A30),
  Color(0xFF97C459),
  Color(0xFFED93B1),
];

Color blendColorFor(Blend blend, String? userId) {
  final i = blend.members.indexWhere((m) => m.id == userId);
  return blendMemberColors[(i < 0 ? 0 : i) % blendMemberColors.length];
}
