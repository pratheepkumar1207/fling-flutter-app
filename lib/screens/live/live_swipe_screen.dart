import 'package:flutter/material.dart';

import '../party/party_screen.dart';
import 'live_feed_screen.dart';

/// Opens [room] full screen; swiping up goes to the next live in [rooms],
/// down to the one before (the order of the list it was opened from).
Future<void> openLiveSwipe(BuildContext context,
    List<Map<String, dynamic>> rooms, Map<String, dynamic> room) {
  final i = rooms.indexWhere((r) => r['id'] == room['id']);
  return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiveSwipeScreen(
          rooms: i < 0 ? [room] : rooms, initialIndex: i < 0 ? 0 : i)));
}

/// Live streams one above the other. Only the stream on screen is joined
/// (PartyScreen); its neighbours show their cover until you land on them,
/// so swiping never keeps two rooms open — joining the next one closes
/// the last (see party_engine_impl.dart's join).
class LiveSwipeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> rooms;
  final int initialIndex;
  const LiveSwipeScreen(
      {super.key, required this.rooms, this.initialIndex = 0});

  @override
  State<LiveSwipeScreen> createState() => _LiveSwipeScreenState();
}

class _LiveSwipeScreenState extends State<LiveSwipeScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rooms.length == 1) {
      return PartyScreen(roomId: widget.rooms.first['id'] as String);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pages,
        scrollDirection: Axis.vertical,
        itemCount: widget.rooms.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final room = widget.rooms[i];
          if (i == _current) {
            return PartyScreen(
                key: ValueKey('live-${room['id']}'),
                roomId: room['id'] as String);
          }
          return IgnorePointer(child: LiveCover(room: room, onTap: () {}));
        },
      ),
    );
  }
}
