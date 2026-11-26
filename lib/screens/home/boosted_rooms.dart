import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../widgets/app_image.dart';
import '../party/party_screen.dart';
import 'popcorn_cards.dart';

/// Boosted rooms shown outside Popcorn: as post cards in the Home feed and
/// as a page of cards in Reels, at random spots.
class BoostedRooms {
  BoostedRooms._();

  static final _rand = Random();

  /// Boosted rooms with people in them, shuffled.
  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final data = await ApiClient.get('/rooms/browse');
      final rooms = [
        for (final r in (data is Map ? data['rooms'] : data) as List? ?? const [])
          if (r is Map &&
              r['isBoosted'] == true &&
              asNum(r['memberCount']) > 0)
            Map<String, dynamic>.from(r),
      ]..shuffle(_rand);
      return rooms;
    } catch (_) {
      return const [];
    }
  }

  /// Random positions in a list of [length] items: the first after
  /// [min]–[max] items, then every [min]–[max] after that.
  static List<int> slots(int length, {required int min, required int max}) {
    final out = <int>[];
    var at = min + _rand.nextInt(max - min + 1);
    while (at <= length) {
      out.add(at);
      at += min + _rand.nextInt(max - min + 1);
    }
    return out;
  }

  static void open(BuildContext context, Map<String, dynamic> room) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
}

/// A boosted room in the Home feed: the host line with the Boosted tag on
/// top of the room's post card.
class BoostedRoomPost extends StatelessWidget {
  final Map<String, dynamic> room;
  const BoostedRoomPost({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final type = room['roomType'] as String? ?? 'watch';
    final doing = switch (type) {
      'voice' => 'Hosting a talk',
      'game' => 'Hosting a game',
      'live' => 'Live now',
      _ => 'Hosting a watch party',
    };
    final avatar = room['hostAvatarUrl'] as String?;
    final name = room['hostName'] as String? ?? 'Someone';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: PopcornPostCard(
        room: room,
        onTap: () => BoostedRooms.open(context, room),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF424242),
                border: type == 'live'
                    ? Border.all(color: const Color(0xFFE83247), width: 2)
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar != null && avatar.isNotEmpty
                  ? AppImage(source: avatar, fit: BoxFit.cover)
                  : Center(
                      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF7B21A),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('Boosted',
                            style: TextStyle(
                                color: Color(0xFF3A2300),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    Text(doing,
                        style: const TextStyle(
                            color: Color(0xFF939393), fontSize: 11)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A page in Reels: up to four boosted rooms as tall cards.
class BoostedRoomsReelPage extends StatelessWidget {
  final List<Map<String, dynamic>> rooms;
  const BoostedRoomsReelPage({super.key, required this.rooms});

  @override
  Widget build(BuildContext context) {
    final shown = rooms.take(4).toList();
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 56, 12, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Boosted rooms',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.62,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final r in shown)
                    PopcornBoostedCard(
                        room: r, onTap: () => BoostedRooms.open(context, r)),
                ],
              ),
            ),
            const Center(
              child: Text('Swipe up for more reels',
                  style: TextStyle(color: Color(0xFF939393), fontSize: 11.5)),
            ),
          ]),
        ),
      ),
    );
  }
}
