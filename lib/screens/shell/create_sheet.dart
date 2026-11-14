import 'package:flutter/material.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/room_sheet.dart';
import '../create/create_flow.dart';
import '../lobby/lobby_create_screen.dart';

/// The ＋ in the top bar: one sheet for everything you can make — Post,
/// Reel, Story, Room (then Watch · Talk · Game) and Go live.
Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: kSheetBorder)),
    builder: (sheet) => _CreateSheet(parent: context),
  );
}

class _CreateSheet extends StatefulWidget {
  final BuildContext parent;
  const _CreateSheet({required this.parent});

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  // Room picked: the same sheet asks how it starts.
  bool _room = false;

  void _openRoom(String type) {
    Navigator.of(context).pop();
    Navigator.of(widget.parent).push(MaterialPageRoute(
        builder: (_) => LobbyCreateScreen(initialRoomType: type)));
  }

  void _create(CreateMode mode) {
    Navigator.of(context).pop();
    openCreateFlow(widget.parent, mode: mode);
  }

  Widget _grid(List<Widget> cards) => LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cards)
              SizedBox(width: (box.maxWidth - 16) / 3, child: c),
          ],
        ),
      );

  Widget _card(InIconData icon, String label, VoidCallback onTap) =>
      RoomToggleCard(
          icon: icon, label: label, on: false, onChanged: (_) => onTap());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RoomSheetHandle(),
              if (!_room)
                _grid([
                  _card(InIcons.image, 'Post', () => _create(CreateMode.post)),
                  _card(InIcons.reel, 'Reel', () => _create(CreateMode.reel)),
                  _card(InIcons.camera, 'Story',
                      () => _create(CreateMode.story)),
                  _card(InIcons.popcorn, 'Room',
                      () => setState(() => _room = true)),
                  _card(InIcons.live, 'Go live', () => _openRoom('live')),
                ])
              else ...[
                Row(children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => setState(() => _room = false),
                    icon: const InIcon(InIcons.back,
                        size: 20, color: Colors.white),
                  ),
                  const Text('New room',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ]),
                const SizedBox(height: 6),
                _grid([
                  _card(InIcons.film, 'Watch', () => _openRoom('watch')),
                  _card(InIcons.mic, 'Talk', () => _openRoom('voice')),
                  _card(InIcons.game, 'Game', () => _openRoom('game')),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
