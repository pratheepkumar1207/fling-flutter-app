import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_board_view.dart';
import '../../widgets/game_seat.dart';
import 'tournament_live.dart';

const _lilac = Color(0xFFE0E0E0);
const _purple = Color(0xFFFFFFFF);
const _gold = Color(0xFFFAC775);
const _goldLine = Color(0xFFBA7517);

/// Watch every table: the pinned one big, the rest small underneath (or
/// on the right when the phone is sideways). Tap a small one to swap it
/// in; long-press for more. Your pin is yours alone — the host's pick is
/// only used until you choose.
class TournamentWatchView extends StatefulWidget {
  final TournamentLive live;
  const TournamentWatchView({super.key, required this.live});

  @override
  State<TournamentWatchView> createState() => _TournamentWatchViewState();
}

class _TournamentWatchViewState extends State<TournamentWatchView> {
  String? _pinned;
  String? _second; // "show 2 big side by side"
  final Set<String> _hidden = {};
  final Set<String> _bell = {};
  final Map<String, String?> _lastAlert = {};
  ({String matchId, String text})? _alert;
  Timer? _alertTimer;

  TournamentLive get live => widget.live;

  @override
  void initState() {
    super.initState();
    live.addListener(_checkAlerts);
  }

  @override
  void dispose() {
    live.removeListener(_checkAlerts);
    _alertTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _matches =>
      live.currentMatches.where((m) => m['bye'] != true).toList();

  String? get _bigId {
    final ids = _matches.map((m) => m['id'] as String).toList();
    if (_pinned != null && ids.contains(_pinned)) return _pinned;
    final host = live.data?['pinnedMatchId'] as String?;
    if (host != null && ids.contains(host)) return host;
    for (final m in _matches) {
      if (m['status'] == 'playing') return m['id'] as String;
    }
    return ids.isEmpty ? null : ids.first;
  }

  void _checkAlerts() {
    final big = _bigId;
    for (final m in _matches) {
      final id = m['id'] as String;
      final text = tourExcitement(live.gameType, live.games[id], m, live.nameOf);
      final before = _lastAlert[id];
      _lastAlert[id] = text;
      if (text == null || text == before || id == big || id == _second) continue;
      if (_hidden.contains(id) && !_bell.contains(id)) continue;
      _alertTimer?.cancel();
      setState(() => _alert = (matchId: id, text: '${m['label']}: $text'));
      _alertTimer = Timer(Duration(seconds: _bell.contains(id) ? 12 : 6), () {
        if (mounted) setState(() => _alert = null);
      });
    }
  }

  void _makeBig(String id) => setState(() {
        if (_second == id) _second = null;
        _pinned = id;
        _alert = null;
      });

  void _swipe(int dir) {
    final ids = _matches.map((m) => m['id'] as String).where((id) => !_hidden.contains(id)).toList();
    if (ids.isEmpty) return;
    final i = ids.indexOf(_bigId ?? ids.first);
    _makeBig(ids[(i + dir + ids.length) % ids.length]);
  }

  Future<void> _menu(Map<String, dynamic> m) async {
    final id = m['id'] as String;
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF181818),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(m['label'] as String? ?? 'Table',
              style: const TextStyle(fontWeight: FontWeight.w700))),
          for (final (key, label) in [
            ('big', '📌  Make big'),
            ('two', _second == id ? '⇄  Stop showing side by side' : '⇄  Show 2 big side by side'),
            ('bell', _bell.contains(id) ? '🔕  Stop telling me' : '🔔  Tell me when it’s close'),
            ('hide', _hidden.contains(id) ? '🙉  Show this table' : '🙈  Hide this table'),
          ])
            ListTile(title: Text(label), onTap: () => Navigator.of(sheet).pop(key)),
        ]),
      ),
    );
    if (!mounted || pick == null) return;
    setState(() {
      switch (pick) {
        case 'big':
          _makeBig(id);
        case 'two':
          _second = _second == id ? null : id;
          if (_second == _bigId) _second = null;
        case 'bell':
          _bell.contains(id) ? _bell.remove(id) : _bell.add(id);
        case 'hide':
          _hidden.contains(id) ? _hidden.remove(id) : _hidden.add(id);
          if (_pinned == id) _pinned = null;
          if (_second == id) _second = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final matches = _matches;
        if (matches.isEmpty) {
          return const Center(
              child: Text('Tables appear here when the round starts',
                  style: TextStyle(color: AppColors.textDim)));
        }
        final big = _bigId!;
        final small = matches
            .where((m) => m['id'] != big && m['id'] != _second && !_hidden.contains(m['id']))
            .toList();
        return LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight && box.maxWidth > 560;
          final bigBoards = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _BigBoard(live: live, matchId: big, onSwipe: _swipe)),
            if (_second != null) ...[
              const SizedBox(width: 6),
              Expanded(child: _BigBoard(live: live, matchId: _second!, onSwipe: (_) {})),
            ],
          ]);
          final tiles = [
            for (final m in small)
              _SmallTile(
                live: live,
                match: m,
                bell: _bell.contains(m['id']),
                onTap: () => _makeBig(m['id'] as String),
                onLongPress: () => _menu(m),
              ),
          ];
          final alert = _alert == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Material(
                    color: const Color(0xFF1E1A10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _goldLine)),
                    child: ListTile(
                      dense: true,
                      leading: const Text('⚡', style: TextStyle(fontSize: 18)),
                      title: Text(_alert!.text, style: const TextStyle(fontSize: 13)),
                      trailing: TextButton(
                          onPressed: () => _makeBig(_alert!.matchId),
                          child: const Text('Switch', style: TextStyle(color: _lilac))),
                    ),
                  ),
                );
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 7, child: SingleChildScrollView(child: Column(children: [bigBoards, alert]))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: ListView(children: [
                    for (final t in tiles)
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: SizedBox(height: 110, child: t)),
                  ]),
                ),
              ]),
            );
          }
          return ListView(padding: const EdgeInsets.fromLTRB(10, 8, 10, 16), children: [
            bigBoards,
            alert,
            if (tiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Other tables · tap to make big, hold for more',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.95,
                children: tiles,
              ),
            ],
            if (_hidden.isNotEmpty)
              TextButton(
                  onPressed: () => setState(_hidden.clear),
                  child: Text('Show ${_hidden.length} hidden table${_hidden.length == 1 ? '' : 's'}')),
          ]);
        });
      },
    );
  }
}

class _BigBoard extends StatelessWidget {
  final TournamentLive live;
  final String matchId;
  final void Function(int dir) onSwipe;
  const _BigBoard({required this.live, required this.matchId, required this.onSwipe});

  @override
  Widget build(BuildContext context) {
    final m = live.matchById(matchId) ?? const {};
    final game = live.games[matchId];
    final done = m['status'] == 'done';
    final pinnedByHost = live.data?['pinnedMatchId'] == matchId;
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 300) onSwipe(v < 0 ? 1 : -1);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: done ? _goldLine : _purple, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(m['label'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (pinnedByHost)
              const Text('Host pick  ', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF8B8B8B),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _purple)),
              child: const Text('📌', style: TextStyle(fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 4),
          _ScoreLine(live: live, match: m, game: game),
          const SizedBox(height: 6),
          if (done)
            _DoneBox(live: live, match: m)
          else if (game == null)
            const SizedBox(
                height: 120,
                child: Center(
                    child: Text('Waiting for players…',
                        style: TextStyle(color: AppColors.textDim))))
          else
            GameSeatScope(
              isHost: false,
              requested: false,
              invited: false,
              spectator: true,
              onSit: () {},
              onRequest: () {},
              onCancelRequest: () {},
              onInvite: null,
              avatarFor: live.avatarOf,
              // Boards are laid out at phone size, then scaled to fit.
              child: IgnorePointer(
                child: AspectRatio(
                  aspectRatio: 360 / 440,
                  child: FittedBox(
                    child: SizedBox(
                      width: 360,
                      height: 440,
                      child: GameBoardView(
                        gameType: live.gameType,
                        game: game,
                        myUserId: null,
                        isHost: false,
                        onJoin: () {},
                        onMove: (_) {},
                        onReset: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final TournamentLive live;
  final Map<String, dynamic> match;
  final Map<String, dynamic>? game;
  const _ScoreLine({required this.live, required this.match, required this.game});

  @override
  Widget build(BuildContext context) {
    final players = (match['players'] as List? ?? []).cast<String>();
    final dropped = (match['dropped'] as List? ?? []).cast<String>();
    final score = (match['score'] as Map?) ?? {};
    final clock = live.clocks[match['id']];
    String detail(String uid) {
      switch (live.gameType) {
        case 'uno':
          for (final p in (game?['players'] as List? ?? [])) {
            if (p is Map && p['userId'] == uid) return '${p['handCount']}';
          }
          return '';
        case 'ludo':
          for (final p in (game?['players'] as List? ?? [])) {
            if (p is Map && p['userId'] == uid) {
              final t = ((game?['tokens'] as Map?)?[p['color']] as List?) ?? [];
              return '${t.where((x) => x == 62).length}/4';
            }
          }
          return '';
        case 'chess':
          final ms = (clock?['ms'] as Map?)?[uid];
          if (ms is! num) return '';
          var left = ms.toInt();
          if (clock?['turn'] == uid && clock?['since'] is num) {
            left -= DateTime.now().millisecondsSinceEpoch - (clock!['since'] as num).toInt();
          }
          left = left.clamp(0, 1 << 31);
          final m = left ~/ 60000;
          final s = (left % 60000) ~/ 1000;
          return '$m:${s.toString().padLeft(2, '0')}';
        default:
          return '${score[uid] ?? 0}';
      }
    }

    final turn = game?['turn'] ??
        ((game?['players'] as List?)?.elementAtOrNull((game?['currentPlayerIndex'] as int?) ?? 0) as Map?)?['userId'];
    return Wrap(spacing: 10, runSpacing: 2, children: [
      for (final uid in players)
        Text(
          '${live.nameOf(uid).split(' ').first}${detail(uid).isEmpty ? '' : ' · ${detail(uid)}'}${dropped.contains(uid) ? ' · out' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: dropped.contains(uid)
                ? AppColors.textFaint
                : turn == uid
                    ? AppColors.accent
                    : AppColors.text,
          ),
        ),
    ]);
  }
}

class _DoneBox extends StatelessWidget {
  final TournamentLive live;
  final Map<String, dynamic> match;
  const _DoneBox({required this.live, required this.match});

  @override
  Widget build(BuildContext context) {
    final ranking = (match['ranking'] as List? ?? []).cast<String>();
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          Text(ranking.isEmpty ? 'Finished' : '${live.nameOf(ranking.first)} won',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.w700)),
          if (match['note'] != null)
            Text(match['note'] as String, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  final TournamentLive live;
  final Map<String, dynamic> match;
  final bool bell;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _SmallTile(
      {required this.live, required this.match, required this.bell, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final id = match['id'] as String;
    final game = live.games[id];
    final done = match['status'] == 'done';
    final hot = tourExcitement(live.gameType, game, match, live.nameOf);
    final players = (match['players'] as List? ?? []).cast<String>();
    String summary() {
      if (done) {
        final r = (match['ranking'] as List? ?? []).cast<String>();
        return r.isEmpty ? 'Done' : '${live.nameOf(r.first).split(' ').first} won';
      }
      if (game == null) return 'Starting…';
      switch (live.gameType) {
        case 'uno':
          return (game['players'] as List? ?? []).map((p) => '${(p as Map)['handCount']}').join(' · ');
        case 'ludo':
          final tokens = (game['tokens'] as Map?) ?? {};
          return (game['players'] as List? ?? [])
              .map((p) => '${((tokens[(p as Map)['color']] as List?) ?? []).where((x) => x == 62).length}')
              .join(' · ');
        case 'tictactoe':
          final s = (match['score'] as Map?) ?? {};
          return players.map((u) => '${s[u] ?? 0}').join(' – ');
        case 'chess':
          return game['check'] == true ? 'Check!' : (game['lastMove'] == null ? 'Opening' : 'Playing');
      }
      return '';
    }

    return Material(
      color: const Color(0xFF161616),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: done ? _goldLine : (hot != null ? _purple : AppColors.border)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF222222), borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: Text(done ? '🏆' : (kTourGames[live.gameType]?.$1 ?? '🎮'),
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text('${(match['label'] as String? ?? '').replaceFirst('Table ', 'T').replaceFirst('Match ', 'M')}${done ? ' ✓' : ' ●'}',
                    style: TextStyle(fontSize: 11.5, color: done ? _gold : AppColors.text)),
              ),
              if (bell) const Text('🔔', style: TextStyle(fontSize: 10)),
            ]),
            Text(hot ?? summary(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: hot != null ? _gold : AppColors.textDim)),
          ]),
        ),
      ),
    );
  }
}
