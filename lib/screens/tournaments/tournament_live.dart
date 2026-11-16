import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api_client.dart';

/// Live view of one tournament (server: src/lib/tournaments.js): the
/// tournament itself, every table's game state, chess clocks and the Hall
/// chat. Several screens can watch the same tournament on the one app
/// socket, so watching is reference-counted.
class TournamentLive extends ChangeNotifier {
  final String id;
  final io.Socket? socket;

  Map<String, dynamic>? data;
  final Map<String, Map<String, dynamic>> games = {}; // matchId -> game state
  final Map<String, Map<String, dynamic>> clocks = {}; // matchId -> clock
  final List<Map<String, dynamic>> chat = [];
  // One-shot events for screens to react to (then clear).
  Map<String, dynamic>? yourMatch;
  Map<String, dynamic>? matchDone;
  Map<String, dynamic>? finished;
  String? error;

  static final Map<String, int> _watchers = {};

  TournamentLive(this.id, this.socket) {
    final s = socket;
    if (s != null) {
      s.on('tour:state', _onState);
      s.on('tour:match', _onMatch);
      s.on('tour:clock', _onClock);
      s.on('tour:chat', _onChat);
      s.on('tour:chatAll', _onChatAll);
      s.on('tour:yourMatch', _onYourMatch);
      s.on('tour:matchDone', _onMatchDone);
      s.on('tour:finished', _onFinished);
      s.onConnect(_onConnect);
      _watchers[id] = (_watchers[id] ?? 0) + 1;
      s.emit('tour:watch', {'tournamentId': id});
    }
    refresh();
  }

  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _mine(dynamic d) => d is Map && d['tournamentId'] == id;

  void _onConnect(dynamic _) => socket?.emit('tour:watch', {'tournamentId': id});

  void _onState(dynamic d) {
    if (d is! Map || d['id'] != id) return;
    final host = data?['host'];
    data = Map<String, dynamic>.from(d);
    if (host != null) data!['host'] = host;
    _notify();
  }

  // tour:match / tour:clock carry a matchId, unique to this tournament's
  // current rounds; ignore ones for matches we don't have.
  bool _hasMatch(String? matchId) =>
      matchId != null && matchById(matchId) != null;

  void _onMatch(dynamic d) {
    if (d is! Map || !_hasMatch(d['matchId'] as String?)) return;
    games[d['matchId'] as String] = Map<String, dynamic>.from(d['game'] as Map);
    if (d['clock'] is Map) {
      clocks[d['matchId'] as String] = Map<String, dynamic>.from(d['clock'] as Map);
    }
    _notify();
  }

  void _onClock(dynamic d) {
    if (d is! Map || !_hasMatch(d['matchId'] as String?)) return;
    clocks[d['matchId'] as String] = Map<String, dynamic>.from(d['clock'] as Map);
    _notify();
  }

  void _onChat(dynamic d) {
    if (d is! Map) return;
    chat.add(Map<String, dynamic>.from(d));
    if (chat.length > 80) chat.removeAt(0);
    _notify();
  }

  void _onChatAll(dynamic d) {
    if (d is! List) return;
    chat
      ..clear()
      ..addAll(d.whereType<Map>().map(Map<String, dynamic>.from));
    _notify();
  }

  void _onYourMatch(dynamic d) {
    if (!_mine(d)) return;
    yourMatch = Map<String, dynamic>.from(d as Map);
    _notify();
  }

  void _onMatchDone(dynamic d) {
    if (!_mine(d)) return;
    matchDone = Map<String, dynamic>.from(d as Map);
    _notify();
  }

  void _onFinished(dynamic d) {
    if (!_mine(d)) return;
    finished = Map<String, dynamic>.from(d as Map);
    refresh();
  }

  Future<void> refresh() async {
    try {
      final d = await ApiClient.get('/tournaments/$id');
      data = Map<String, dynamic>.from(d as Map);
      error = null;
    } catch (e) {
      error = 'Couldn’t load this tournament';
    }
    _notify();
  }

  void sendChat(String text) {
    if (text.trim().isEmpty) return;
    socket?.emit('tour:chat', {'tournamentId': id, 'text': text.trim()});
  }

  // ---- helpers over the data ----
  String get status => data?['status'] as String? ?? 'open';
  String get gameType => data?['gameType'] as String? ?? '';
  bool get isPairs => data?['format'] == 'pairs';
  List<Map<String, dynamic>> get players =>
      ((data?['players'] as List?) ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
  List<Map<String, dynamic>> get rounds =>
      ((data?['rounds'] as List?) ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();
  Map<String, dynamic>? get currentRound => rounds.isEmpty ? null : rounds.last;
  List<Map<String, dynamic>> get currentMatches =>
      ((currentRound?['matches'] as List?) ?? []).whereType<Map>().map(Map<String, dynamic>.from).toList();

  Map<String, dynamic>? matchById(String id) {
    for (final r in rounds) {
      for (final m in (r['matches'] as List? ?? [])) {
        if (m is Map && m['id'] == id) return Map<String, dynamic>.from(m);
      }
    }
    return null;
  }

  Map<String, dynamic>? matchByRoom(String roomId) {
    for (final m in currentMatches) {
      if (m['roomId'] == roomId) return m;
    }
    return null;
  }

  String nameOf(String? uid) {
    for (final p in players) {
      if (p['id'] == uid) return p['name'] as String? ?? 'Player';
    }
    return 'Player';
  }

  String? avatarOf(String? uid) {
    for (final p in players) {
      if (p['id'] == uid) return p['avatarUrl'] as String?;
    }
    return null;
  }

  /// My live match in the current round, if any.
  Map<String, dynamic>? myMatch(String? me) {
    if (me == null || status != 'running') return null;
    for (final m in currentMatches) {
      final ps = (m['players'] as List).cast<String>();
      if (m['status'] == 'playing' && ps.contains(me) &&
          !(m['dropped'] as List).contains(me)) {
        return m;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    final s = socket;
    if (s != null) {
      s.off('tour:state', _onState);
      s.off('tour:match', _onMatch);
      s.off('tour:clock', _onClock);
      s.off('tour:chat', _onChat);
      s.off('tour:chatAll', _onChatAll);
      s.off('tour:yourMatch', _onYourMatch);
      s.off('tour:matchDone', _onMatchDone);
      s.off('tour:finished', _onFinished);
      s.off('connect', _onConnect);
      final left = (_watchers[id] ?? 1) - 1;
      if (left <= 0) {
        _watchers.remove(id);
        s.emit('tour:unwatch', {'tournamentId': id});
      } else {
        _watchers[id] = left;
      }
    }
    super.dispose();
  }
}

const kTourGames = {
  'chess': ('♟️', 'Chess'),
  'tictactoe': ('❌', 'Tic tac toe'),
  'uno': ('🃏', 'UNO'),
  'ludo': ('🎲', 'Ludo'),
};

String tourGameLabel(String type) {
  final g = kTourGames[type];
  return g == null ? type : '${g.$1} ${g.$2}';
}

/// "Starts in 1:42:10" style countdown text.
String tourCountdown(DateTime at) {
  var d = at.difference(DateTime.now());
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inDays >= 1) return '${d.inDays}d ${h.remainder(24)}h';
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// One line that makes a table worth switching to, or null.
String? tourExcitement(String gameType, Map<String, dynamic>? game,
    Map<String, dynamic>? match, String Function(String?) nameOf) {
  if (game == null || game['status'] != 'playing') return null;
  final players = (game['players'] as List? ?? []).whereType<Map>().toList();
  switch (gameType) {
    case 'uno':
      for (final p in players) {
        if (p['handCount'] == 1) return '${nameOf(p['userId'] as String?)} has 1 card';
      }
      return null;
    case 'ludo':
      final tokens = (game['tokens'] as Map?) ?? {};
      for (final p in players) {
        final t = (tokens[p['color']] as List? ?? []);
        if (t.where((x) => x == 62).length == 3) {
          return '${nameOf(p['userId'] as String?)} is 1 token from winning';
        }
      }
      return null;
    case 'chess':
      if (game['check'] == true) return 'Check!';
      return null;
    case 'tictactoe':
      final score = (match?['score'] as Map?) ?? {};
      final v = score.values.toList();
      if (v.length == 2 && v[0] == 1 && v[1] == 1) return 'Deciding game';
      return null;
  }
  return null;
}
