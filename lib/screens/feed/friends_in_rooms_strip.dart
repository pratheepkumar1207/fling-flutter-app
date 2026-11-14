import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../party/party_screen.dart';

/// Home: a small sideways row of rooms your friends are in right now ("Movie
/// night · Priya + 5"). Tap one to join. Hidden when no friend is in a room.
class FriendsInRoomsStrip extends StatefulWidget {
  const FriendsInRoomsStrip({super.key});

  @override
  State<FriendsInRoomsStrip> createState() => _FriendsInRoomsStripState();
}

class _FriendsInRoomsStripState extends State<FriendsInRoomsStrip> {
  List<Map<String, dynamic>> _rooms = const [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/rooms/browse');
      if (!mounted || data is! List) return;
      setState(() => _rooms = [
            for (final r in data)
              if (r is Map &&
                  asNum(r['memberCount']) > 0 &&
                  asNum(r['friendsInside']) > 0)
                Map<String, dynamic>.from(r)
          ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_rooms.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Text('FRIENDS IN ROOMS NOW',
              style: TextStyle(
                  color: Color(0xFF9A9AA5),
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: _rooms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _card(_rooms[i]),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final type = r['roomType'] as String? ?? 'watch';
    final (icon, fg, bg) = switch (type) {
      'voice' => (InIcons.mic, const Color(0xFFB97CF8), const Color(0xFF1C1638)),
      'game' => (InIcons.game, const Color(0xFF6E95FD), const Color(0xFF122046)),
      'live' => (InIcons.live, const Color(0xFFFF5C6C), const Color(0xFF2A0F14)),
      _ => (InIcons.film, const Color(0xFFFF8AB4), const Color(0xFF2A1028)),
    };
    final friend = ((r['members'] as List?) ?? const [])
        .whereType<Map>()
        .where((m) => m['isFriend'] == true)
        .map((m) => (m['name'] as String? ?? '').split(' ').first)
        .firstOrNull;
    final count = asNum(r['memberCount']).toInt();
    final who = friend == null || friend.isEmpty
        ? '$count in'
        : count > 1
            ? '$friend + ${count - 1}'
            : friend;
    final thumb = r['nowPlayingThumbnail'] as String?;
    return Semantics(
      button: true,
      label: '${r['title'] ?? 'Room'}, $who',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF262626))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PartyScreen(roomId: r['id'] as String))),
          child: SizedBox(
            width: 170,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(9)),
                  child: type == 'watch' && thumb != null && thumb.isNotEmpty
                      ? AppImage(source: thumb, fit: BoxFit.cover)
                      : Center(child: InIcon(icon, size: 18, color: fg)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(r['title'] as String? ?? 'Room',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 10.5)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
