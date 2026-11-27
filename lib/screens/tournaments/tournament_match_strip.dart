import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import 'tournament_live.dart';
import 'tournament_screen.dart';

/// Above the board in a tournament match: the other tables as chips (tap
/// to peek — scores only, no live boards, so you stay on your game), your
/// chess clock, and when your match ends, whether you go through.
class TournamentMatchStrip extends StatefulWidget {
  final String tournamentId;
  final String roomId;
  final String? myId;
  const TournamentMatchStrip({super.key, required this.tournamentId, required this.roomId, required this.myId});

  @override
  State<TournamentMatchStrip> createState() => _TournamentMatchStripState();
}

class _TournamentMatchStripState extends State<TournamentMatchStrip> {
  late final TournamentLive live;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    live = TournamentLive(widget.tournamentId, context.read<SocketService>().socket);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && live.clocks.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    live.dispose();
    super.dispose();
  }

  void _backToTournament() {
    final nav = Navigator.of(context);
    var found = false;
    nav.popUntil((route) {
      if (route.settings.name == 'tournament:${widget.tournamentId}') found = true;
      return found || route.isFirst;
    });
    if (!found) {
      nav.push(MaterialPageRoute(
          settings: RouteSettings(name: 'tournament:${widget.tournamentId}'),
          builder: (_) => TournamentScreen(tournamentId: widget.tournamentId)));
    }
  }

  void _peek() {
    final others = live.currentMatches.where((m) => m['roomId'] != widget.roomId && m['bye'] != true).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF000000),
      builder: (sheet) => SafeArea(
        child: ListenableBuilder(
          listenable: live,
          builder: (context, _) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
            const Text('Other tables', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final m in others)
              ListTile(
                dense: true,
                title: Text(m['label'] as String),
                subtitle: Text(_status(m),
                    style: TextStyle(
                        color: tourExcitement(live.gameType, live.games[m['id']], m, live.nameOf) != null
                            ? const Color(0xFFFAC775)
                            : AppColors.textDim)),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Playing? You get scores only, so you stay on your game.',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
            ),
          ]),
        ),
      ),
    );
  }

  String _status(Map<String, dynamic> m) {
    if (m['status'] == 'done') {
      final r = (m['ranking'] as List).cast<String>();
      return r.isEmpty ? 'Done' : 'Done · ${live.nameOf(r.first)} won';
    }
    final hot = tourExcitement(live.gameType, live.games[m['id']], m, live.nameOf);
    if (hot != null) return hot;
    final g = live.games[m['id']];
    if (live.gameType == 'uno' && g != null) {
      return (g['players'] as List)
          .map((p) => '${live.nameOf((p as Map)['userId'] as String?).split(' ').first} ${p['handCount']}')
          .join(' · ');
    }
    if (live.isPairs) {
      final s = (m['score'] as Map?) ?? {};
      return (m['players'] as List).map((u) => '${live.nameOf(u as String).split(' ').first} ${s[u] ?? 0}').join(' – ');
    }
    return 'Playing';
  }

  String _clockText(Map<String, dynamic> clock, String uid) {
    var left = ((clock['ms'] as Map?)?[uid] as num?)?.toInt() ?? 0;
    if (clock['turn'] == uid && clock['since'] is num) {
      left -= DateTime.now().millisecondsSinceEpoch - (clock['since'] as num).toInt();
    }
    if (left < 0) left = 0;
    return '${left ~/ 60000}:${((left % 60000) ~/ 1000).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final mine = live.matchByRoom(widget.roomId);
        final done = live.matchDone;
        final others = live.currentMatches.where((m) => m['roomId'] != widget.roomId && m['bye'] != true).toList();
        final clock = mine == null ? null : live.clocks[mine['id']];
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('🏆 ${mine?['label'] ?? 'Tournament'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final m in others)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          onPressed: _peek,
                          backgroundColor: const Color(0xFF000000),
                          side: BorderSide(
                              color: m['status'] == 'done' ? const Color(0xFFBA7517) : AppColors.border),
                          label: Text(
                              '${(m['label'] as String).replaceFirst('Table ', 'T').replaceFirst('Match ', 'M')} ${m['status'] == 'done' ? '✓' : '●'}',
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
            if (clock != null && mine != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (final uid in (mine['players'] as List).cast<String>())
                    Text('⏱ ${uid == widget.myId ? 'You' : live.nameOf(uid).split(' ').first} ${_clockText(clock, uid)}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: clock['turn'] == uid ? AppColors.accent : AppColors.textDim)),
                ]),
              ),
            if (done != null && done['roomId'] == widget.roomId)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Material(
                  color: done['through'] == true ? const Color(0xFF1E1A10) : const Color(0xFF000000),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: done['through'] == true ? const Color(0xFFBA7517) : AppColors.border)),
                  child: ListTile(
                    dense: true,
                    title: Text(done['through'] == true
                        ? (done['final'] == true ? '🏆 You won the tournament!' : '🎉 You go through!')
                        : 'You’re out · thanks for playing'),
                    subtitle: Text(done['final'] == true ? 'See the podium' : 'Wait in the Hall for the next round',
                        style: const TextStyle(color: AppColors.textDim)),
                    trailing: TextButton(onPressed: _backToTournament, child: const Text('Hall')),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}
