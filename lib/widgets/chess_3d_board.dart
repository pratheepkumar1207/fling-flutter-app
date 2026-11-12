import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/api_client.dart';
import '../theme/app_colors.dart';
import 'chess_board.dart';
import 'game_seat.dart';

/// Room chess on the 3D board (public/chess on the backend, adapted from
/// Cliff Pyles' MIT-licensed CodePen). The server still owns every rule:
/// this page only shows the room's position and sends the player's move,
/// exactly like the flat [ChessBoard], which takes over if the page fails.
class Chess3DBoard extends StatefulWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final bool isHost;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;
  final VoidCallback onReset;

  const Chess3DBoard({
    super.key,
    required this.game,
    required this.myUserId,
    required this.isHost,
    required this.onJoin,
    required this.onMove,
    required this.onReset,
  });

  @override
  State<Chess3DBoard> createState() => _Chess3DBoardState();
}

/// The room's board (board[row][col], row 0 = rank 1, col 0 = file a) as FEN.
@visibleForTesting
String chessFenOf(Map<String, dynamic> game) {
  final board = game['board'] as List;
  final ranks = <String>[];
  for (var r = 7; r >= 0; r--) {
    final row = board[r] as List;
    var line = '';
    var empty = 0;
    for (var c = 0; c < 8; c++) {
      final p = row[c] as Map?;
      if (p == null) {
        empty++;
        continue;
      }
      if (empty > 0) line += '$empty';
      empty = 0;
      final t = p['type'] as String;
      line += p['color'] == 'white' ? t.toUpperCase() : t;
    }
    if (empty > 0) line += '$empty';
    ranks.add(line);
  }
  final turn = game['turnColor'] == 'black' ? 'b' : 'w';
  final rights = game['castlingRights'] as Map?;
  bool can(String color, String side) => (rights?[color] as Map?)?[side] == true;
  bool at(int r, int c, String type, String color) {
    final p = (board[r] as List)[c] as Map?;
    return p != null && p['type'] == type && p['color'] == color;
  }

  var castling = '';
  if (can('white', 'k') && at(0, 4, 'k', 'white') && at(0, 7, 'r', 'white')) castling += 'K';
  if (can('white', 'q') && at(0, 4, 'k', 'white') && at(0, 0, 'r', 'white')) castling += 'Q';
  if (can('black', 'k') && at(7, 4, 'k', 'black') && at(7, 7, 'r', 'black')) castling += 'k';
  if (can('black', 'q') && at(7, 4, 'k', 'black') && at(7, 0, 'r', 'black')) castling += 'q';
  if (castling.isEmpty) castling = '-';
  final ep = (game['enPassantTarget'] as List?)?.cast<num>();
  final epText = ep == null ? '-' : '${'abcdefgh'[ep[1].toInt()]}${ep[0].toInt() + 1}';
  final half = (game['halfMoveClock'] as num?)?.toInt() ?? 0;
  return '${ranks.join('/')} $turn $castling $epText $half 1';
}

String _square(List sq) => '${'abcdefgh'[(sq[1] as num).toInt()]}${(sq[0] as num).toInt() + 1}';

/// The room's last move as UCI (from and to only; the board works out a
/// promotion from the position it leads to).
@visibleForTesting
String? chessLastMoveUci(Map<String, dynamic> game) {
  final last = game['lastMove'] as Map?;
  final from = last?['from'] as List?;
  final to = last?['to'] as List?;
  if (from == null || to == null) return null;
  return '${_square(from)}${_square(to)}';
}

List<int> _rowCol(String sq) => [int.parse(sq[1]) - 1, 'abcdefgh'.indexOf(sq[0])];

class _Chess3DBoardState extends State<Chess3DBoard> {
  InAppWebViewController? _controller;
  bool _ready = false;
  // Widget tests have no web view: they get the flat board.
  bool _failed = Platform.environment.containsKey('FLUTTER_TEST');
  String? _sent;

  Map? get _me => (widget.game['players'] as List? ?? [])
      .cast<Map?>()
      .firstWhere((p) => p?['userId'] == widget.myUserId, orElse: () => null);

  Map<String, dynamic> _roomData() {
    final game = widget.game;
    final players = (game['players'] as List? ?? []).cast<Map>();
    final me = _me;
    final you = (me?['color'] as String?) ?? 'white';
    final them = you == 'white' ? 'black' : 'white';
    final other = players.cast<Map?>().firstWhere((p) => p?['color'] == them, orElse: () => null);
    final mine = players.cast<Map?>().firstWhere((p) => p?['color'] == you, orElse: () => null);
    final uci = chessLastMoveUci(game);
    return {
      'fen': chessFenOf(game),
      if (uci != null) 'lastMove': uci,
      'you': you,
      'spectator': me == null || game['status'] != 'playing',
      'opponentName': other?['name'],
      'opponentDetail': 'In this room',
      'youName': me == null ? (mine?['name'] ?? 'White') : 'You',
      // A new game (host's reset) starts a new table.
      'key': players.map((p) => p['userId']).join(','),
    };
  }

  Future<void> _push() async {
    final c = _controller;
    if (c == null || !_ready) return;
    final json = jsonEncode(_roomData());
    if (json == _sent) return;
    _sent = json;
    try {
      await c.evaluateJavascript(source: 'window.insyncRoom && window.insyncRoom.sync($json);');
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant Chess3DBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  void _onMessage(List<dynamic> args) {
    final data = args.isNotEmpty && args.first is Map ? args.first as Map : const {};
    switch (data['type']) {
      case 'ready':
        _ready = true;
        _sent = null;
        _push();
      case 'move':
        final uci = data['uci'] as String? ?? '';
        if (uci.length < 4) return;
        widget.onMove({
          'from': _rowCol(uci.substring(0, 2)),
          'to': _rowCol(uci.substring(2, 4)),
          if (uci.length > 4) 'promotion': uci[4],
        });
        // If the server turns it down, its unchanged state puts the board back.
        _sent = null;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _push();
        });
      case 'rematch':
        if (widget.isHost) {
          widget.onReset();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('The host can start a new game')));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return ChessBoard(
          game: widget.game,
          myUserId: widget.myUserId,
          isHost: widget.isHost,
          onJoin: widget.onJoin,
          onMove: widget.onMove,
          onReset: widget.onReset);
    }
    final players = (widget.game['players'] as List? ?? []);
    final status = widget.game['status'] as String? ?? 'waiting';
    final isPlayer = _me != null;
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 1.3).clamp(320.0, MediaQuery.sizeOf(context).height * 0.62);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == 'waiting')
          GameStatusLine(
              players.isEmpty ? 'Waiting for players' : 'Waiting for a second player',
              highlight: false),
        if (!isPlayer)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GameJoinButton(
                seated: isPlayer, full: players.length >= 2, fallbackJoin: widget.onJoin),
          ),
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: const Color(0xFF15100C),
              child: InAppWebView(
                // Drags belong to the pieces, not the room's swipes.
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
                initialUrlRequest: URLRequest(url: WebUri('${ApiClient.baseUrl}/chess/#/room')),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  mediaPlaybackRequiresUserGesture: false,
                  supportZoom: false,
                  disableHorizontalScroll: true,
                  disableVerticalScroll: true,
                ),
                onWebViewCreated: (c) {
                  _controller = c;
                  c.addJavaScriptHandler(handlerName: 'insyncChess', callback: (args) {
                    _onMessage(args);
                    return null;
                  });
                },
                onReceivedError: (c, request, error) {
                  if (request.isForMainFrame == true && mounted) {
                    setState(() => _failed = true);
                  }
                },
                onReceivedHttpError: (c, request, response) {
                  if (request.isForMainFrame == true && mounted) {
                    setState(() => _failed = true);
                  }
                },
              ),
            ),
          ),
        ),
        if (widget.isHost && (status == 'won' || status == 'draw'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(onPressed: widget.onReset, child: const Text('Play again')),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('3D board by Cliff Pyles (MIT)',
              style: TextStyle(color: AppColors.textFaint, fontSize: 9)),
        ),
      ],
    );
  }
}
