import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/creator_gate.dart';
import '../live/live_feed_screen.dart';
import '../lobby/lobby_create_screen.dart';

/// Popcorn's live row: a Go live card first, then everyone live right now
/// (swipe sideways), and "View more live" under it for the full Live page.
class PopcornLiveRow extends StatelessWidget {
  final List<Map<String, dynamic>> lives;
  final void Function(Map<String, dynamic> room) onOpen;
  final VoidCallback onChanged;
  const PopcornLiveRow(
      {super.key,
      required this.lives,
      required this.onOpen,
      required this.onChanged});

  static const _w = 108.0;
  static const _h = 148.0;

  Future<void> _goLive(BuildContext context) async {
    if (!await canGoLive(context) || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const LobbyCreateScreen(initialRoomType: 'live')));
    onChanged();
  }

  void _viewMore(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(
          builder: (_) => Scaffold(
                backgroundColor: AppColors.bg,
                appBar: AppBar(toolbarHeight: 44),
                body: const LiveFeedScreen(),
              )))
      .then((_) => onChanged());

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: _h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: lives.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i == 0) {
              return Semantics(
                button: true,
                label: 'Go live',
                child: GestureDetector(
                  onTap: () => _goLive(context),
                  child: Container(
                    width: _w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1B24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.lilac, width: 1.5),
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(clipBehavior: Clip.none, children: [
                            Avatar(
                                src: me?.avatarUrl,
                                name: me?.name,
                                size: AvatarSize.md),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF1D1B24),
                                        width: 2)),
                                child: const Center(
                                    child: InIcon(InIcons.live,
                                        size: 11, color: Colors.white)),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          const Text('Go live',
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Start your own stream',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.textFaint, fontSize: 10)),
                          ),
                        ]),
                  ),
                ),
              );
            }
            final room = lives[i - 1];
            return SizedBox(
              width: _w,
              child: LiveCover(room: room, onTap: () => onOpen(room)),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => _viewMore(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lilac,
          side: const BorderSide(color: AppColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(lives.isEmpty ? 'See the Live page' : 'View more live'),
          const SizedBox(width: 4),
          const InIcon(InIcons.right, size: 16, color: AppColors.lilac),
        ]),
      ),
    ]);
  }
}
