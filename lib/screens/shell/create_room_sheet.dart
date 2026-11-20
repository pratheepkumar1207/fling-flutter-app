import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../lobby/lobby_create_screen.dart';

/// Popcorn's centre + (and the Create room card): just room types. Picking
/// one opens the lobby with it chosen. Going live has its own card.
Future<void> showCreateRoomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF15121D),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheet) {
      Widget option(InIconData icon, Color tile, String title, String sub,
              String type) =>
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: const Color(0xFF1D1B24),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.of(sheet).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LobbyCreateScreen(initialRoomType: type)));
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: tile, borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: InIcon(icon, size: 21, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(sub,
                                style: const TextStyle(
                                    color: AppColors.textFaint, fontSize: 12)),
                          ]),
                    ),
                    const InIcon(InIcons.right,
                        size: 18, color: AppColors.textFaint),
                  ]),
                ),
              ),
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Create a room',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            option(InIcons.tv, const Color(0xFF2F3A6B), 'Watch',
                'YouTube, Drive, Browser, streaming apps', 'watch'),
            option(InIcons.mic, const Color(0xFF2F5A4A), 'Talk',
                'Voice room with seats', 'voice'),
            option(InIcons.game, const Color(0xFF5A3A2F), 'Game',
                'Ludo, UNO, Chess, Tic tac toe', 'game'),
          ]),
        ),
      );
    },
  );
}
