import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/post_composer_sheet.dart';
import '../lobby/lobby_create_screen.dart';
import '../party/party_screen.dart';

/// The centre "+" in the bottom bar: start any kind of room, go live, or
/// post. Go live is highlighted, as in the design.
Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheet) => _CreateSheet(parent: context),
  );
}

class _CreateSheet extends StatelessWidget {
  final BuildContext parent;
  const _CreateSheet({required this.parent});

  void _room(BuildContext sheet, String type) {
    Navigator.of(sheet).pop();
    Navigator.of(parent).push(MaterialPageRoute(
        builder: (_) => LobbyCreateScreen(initialRoomType: type)));
  }

  Future<void> _goLive(BuildContext sheet) async {
    Navigator.of(sheet).pop();
    try {
      final room = await ApiClient.post('/rooms', body: {
        'title': 'Live now',
        'roomType': 'live',
        'visibility': 'public'
      }) as Map<String, dynamic>;
      if (!parent.mounted) return;
      Navigator.of(parent).push(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } catch (_) {
      if (parent.mounted) {
        ScaffoldMessenger.of(parent).showSnackBar(const SnackBar(
            content: Text('Couldn’t start your live. Try again.')));
      }
    }
  }

  void _post(BuildContext sheet) {
    Navigator.of(sheet).pop();
    showPostComposerSheet(parent, onPosted: () {});
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(
          InIcons.tv,
          'Watch party',
          'Movies, YouTube, Netflix',
          AppColors.pink,
          const Color(0xFF2A1028),
          () => _room(context, 'watch')),
      _Item(InIcons.mic, 'Voice room', 'Talk and sing', const Color(0xFFB97CF8),
          const Color(0xFF1C1638), () => _room(context, 'voice')),
      _Item(
          InIcons.game,
          'Game room',
          'Ludo, UNO, Chess',
          const Color(0xFF6E95FD),
          const Color(0xFF122046),
          () => _room(context, 'game')),
      _Item(InIcons.live, 'Go live', 'Stream to everyone', Colors.white,
          Colors.white24, () => _goLive(context),
          highlight: true),
      _Item(InIcons.image, 'Post', 'Photo, poll, voice note', AppColors.lilac,
          const Color(0xFF1F1A2C), () => _post(context)),
      _Item(InIcons.reel, 'Reel', 'Short video', const Color(0xFFFF9F5A),
          const Color(0xFF2A1A10), () => _post(context)),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: items,
              ),
            ]),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final InIconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color tile;
  final VoidCallback onTap;
  final bool highlight;
  const _Item(
      this.icon, this.title, this.subtitle, this.color, this.tile, this.onTap,
      {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: highlight ? null : AppColors.surface2,
            gradient: highlight
                ? const LinearGradient(
                    colors: [AppColors.pink, AppColors.purple])
                : null,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: tile, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: InIcon(icon, size: 19, color: color)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: highlight
                              ? const Color(0xFFF4E8FF)
                              : AppColors.textDim)),
                ]),
              ]),
        ),
      ),
    );
  }
}
