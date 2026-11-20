import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../lobby/choose_game_screen.dart';
import '../lobby/source_picker_screen.dart';
import '../party/party_screen.dart';
import '../tournaments/tournament_create_screen.dart';

/// Popcorn's centre + and the Create room card: pick a room type, then
/// Continue into the usual flow for it. Going live has its own card on
/// Popcorn's live row.
Future<void> openCreateRoom(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const CreateRoomTypeScreen()));

class _RoomType {
  final String id;
  final InIconData icon;
  final String title;
  final String sub;
  final List<Color> colors;
  const _RoomType(this.id, this.icon, this.title, this.sub, this.colors);
}

const _types = [
  _RoomType('watch', InIcons.tv, 'Watch', 'Videos together',
      [Color(0xFF4A5BD6), Color(0xFF2F3A8A)]),
  _RoomType('voice', InIcons.mic, 'Talk', 'Voice room',
      [Color(0xFF2FA37A), Color(0xFF1D6650)]),
  _RoomType('game', InIcons.game, 'Game', 'Ludo, UNO, Chess',
      [Color(0xFFE07A3A), Color(0xFF9A4A1D)]),
  _RoomType('tournament', InIcons.trophy, 'Tournament', 'Host a cup',
      [Color(0xFF9B6BFF), Color(0xFF5A33B8)]),
];

class CreateRoomTypeScreen extends StatefulWidget {
  const CreateRoomTypeScreen({super.key});

  @override
  State<CreateRoomTypeScreen> createState() => _CreateRoomTypeScreenState();
}

class _CreateRoomTypeScreenState extends State<CreateRoomTypeScreen> {
  String? _picked;
  bool _busy = false;

  Future<void> _continue() async {
    final nav = Navigator.of(context);
    switch (_picked) {
      case 'watch':
        // Usual defaults: public, the host asked about privacy in the room.
        nav.push(MaterialPageRoute(
            builder: (_) => const SourcePickerScreen(visibility: 'public')));
      case 'voice':
        setState(() => _busy = true);
        try {
          final room = await ApiClient.post('/rooms', body: {
            'roomType': 'voice',
            'visibility': 'public',
            'askPrivacy': true,
          }) as Map<String, dynamic>;
          if (!mounted) return;
          nav.pushReplacement(MaterialPageRoute(
              builder: (_) => PartyScreen(roomId: room['id'] as String)));
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Couldn’t create the room. Try again.')));
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case 'game':
        nav.push(MaterialPageRoute(builder: (_) => const ChooseGameScreen()));
      case 'tournament':
        nav.push(MaterialPageRoute(
            builder: (_) => const TournamentCreateScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _types.where((t) => t.id == _picked).firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Create a room'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('What do you want to do?',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                  children: [for (final t in _types) _tile(t)],
                ),
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: picked == null || _busy
                          ? null
                          : AppGradients.brandDiagonal,
                      color: picked == null || _busy
                          ? const Color(0xFF26232F)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: picked == null || _busy ? null : _continue,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white38,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: Text(
                          _busy
                              ? 'Creating…'
                              : picked == null
                                  ? 'Pick a room type'
                                  : 'Continue · ${picked.title}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _tile(_RoomType t) {
    final on = _picked == t.id;
    final faded = _picked != null && !on;
    return Semantics(
      button: true,
      selected: on,
      label: '${t.title}, ${t.sub}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _busy ? null : () => setState(() => _picked = t.id),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: faded ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: t.colors),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: on ? Colors.white : Colors.transparent, width: 3),
            ),
            child: Stack(children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14)),
                      child: Center(
                          child:
                              InIcon(t.icon, size: 24, color: Colors.white)),
                    ),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(t.sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xCCFFFFFF), fontSize: 11.5)),
                        ]),
                  ]),
              if (on)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.check_rounded,
                        size: 16, color: Color(0xFF2F3A8A)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
