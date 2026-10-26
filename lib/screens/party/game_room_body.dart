import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/room_themes.dart';

/// Game rooms: the game owns the screen. A slim song bar sits on top (the
/// room's music keeps playing while people play), the board fills the
/// middle, and chat waits behind it as a one-line bar at the bottom —
/// tap or swipe it up to slide the full chat over the game, swipe down
/// (or tap the handle) to put it back. The board never unmounts, so a
/// game in progress isn't disturbed by opening chat.
class GameRoomBody extends StatefulWidget {
  final Widget? songPlayer;
  final VoidCallback onAddSong;
  final Widget board;
  final List<Widget> banners;
  final Widget chat;
  final List<Map<String, dynamic>> messages;

  const GameRoomBody({
    super.key,
    required this.songPlayer,
    required this.onAddSong,
    required this.board,
    required this.banners,
    required this.chat,
    required this.messages,
  });

  @override
  State<GameRoomBody> createState() => _GameRoomBodyState();
}

class _GameRoomBodyState extends State<GameRoomBody> {
  bool _chatOpen = false;
  // Messages already seen — everything past this counts as "new" on the
  // collapsed bar.
  late int _seenCount = widget.messages.length;

  void _setChatOpen(bool open) {
    if (open == _chatOpen) return;
    setState(() {
      _chatOpen = open;
      _seenCount = widget.messages.length;
    });
    if (!open) FocusScope.of(context).unfocus();
  }

  @override
  void didUpdateWidget(covariant GameRoomBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_chatOpen) _seenCount = widget.messages.length;
  }

  Widget _songBar() {
    final add = Semantics(
      button: true,
      label: 'Add a song',
      child: GestureDetector(
        onTap: widget.onAddSong,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
          child: const InIcon(InIcons.plus, color: AppColors.ink, size: 22),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: widget.songPlayer ??
                GestureDetector(
                  onTap: widget.onAddSong,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: RoomTheme.of(context)
                            .surface
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        InIcon(InIcons.music,
                            size: 18, color: AppColors.textFaint),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text('Add music while you play',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textDim, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
          const SizedBox(width: 8),
          add,
        ],
      ),
    );
  }

  Widget _chatBar() {
    final last = widget.messages.isEmpty ? null : widget.messages.last;
    final unread = widget.messages.length - _seenCount;
    final preview = last == null
        ? 'Say something to the room'
        : last['system'] == true
            ? '${last['text']}'
            : '${last['name'] ?? 'Someone'}: ${last['text'] ?? ''}';
    return GestureDetector(
      onTap: () => _setChatOpen(true),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -150) _setChatOpen(true);
      },
      child: Semantics(
        button: true,
        label: 'Open chat',
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          decoration: BoxDecoration(
            color: RoomTheme.of(context).surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RoomTheme.of(context).border),
          ),
          child: Row(
            children: [
              const InIcon(InIcons.chat, size: 18, color: AppColors.textDim),
              const SizedBox(width: 8),
              Expanded(
                child: Text(preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 12.5)),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 4),
              const InIcon(InIcons.arrowup, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final panelHeight = constraints.maxHeight * 0.62;
      return Stack(
        children: [
          Column(
            children: [
              _songBar(),
              ...widget.banners,
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 70),
                  child: widget.board,
                ),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _chatBar()),
          // Chat slides over the game; the game stays visible above it.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            height: panelHeight,
            bottom: _chatOpen ? 0 : -panelHeight - 20,
            child: Offstage(
              offstage: !_chatOpen,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg.withValues(alpha: 0.96),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(color: RoomTheme.of(context).border),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setChatOpen(false),
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) > 150) {
                          _setChatOpen(false);
                        }
                      },
                      child: Semantics(
                        button: true,
                        label: 'Back to the game',
                        child: SizedBox(
                          height: 26,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(999))),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: widget.chat,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
