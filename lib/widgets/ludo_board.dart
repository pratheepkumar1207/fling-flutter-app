import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_seat.dart';

/// Presentational only — every rule (yard-exit-on-6, capture, safe squares,
/// exact-roll-to-finish, bonus turn on 6) is enforced server-side in
/// src/games/ludo.js; this renders the literal cross-shaped physical board
/// that backend's RING/HOME_COLUMN geometry describes — a real 15x15-cell
/// layout with yards, a 56-square ring, each color's 5-square home stretch,
/// and a rolling 3D die. Mirrors LudoBoard.jsx's geometry exactly; the two
/// must be kept in sync with each other and with ludo.js's RING_LEN/
/// START_INDEX/SAFE_INDICES.

const List<String> _colors = ['red', 'green', 'yellow', 'blue'];
const Map<String, Color> _colorHex = {
  'red': Color(0xFFE53935),
  'green': Color(0xFF2E9E4F),
  'yellow': Color(0xFFF6B21A),
  'blue': Color(0xFF1E7BE0),
};
const _kBoard = Color(0xFFFBF6EC); // cream playing surface
const _kLine = Color(0xFFE2D8C6); // square outlines
const _kFrame = Color(0xFFB9874E); // wooden frame
const Map<String, String> _colorName = {
  'red': 'Red',
  'green': 'Green',
  'yellow': 'Yellow',
  'blue': 'Blue'
};

const int _grid = 15;
const double _cellPct = 1 / _grid; // fraction of the square board's side

const List<List<int>> _ring = [
  [6, 1],
  [6, 2],
  [6, 3],
  [6, 4],
  [6, 5],
  [6, 6],
  [5, 6],
  [4, 6],
  [3, 6],
  [2, 6],
  [1, 6],
  [0, 6],
  [0, 7],
  [0, 8],
  [1, 8],
  [2, 8],
  [3, 8],
  [4, 8],
  [5, 8],
  [6, 8],
  [6, 9],
  [6, 10],
  [6, 11],
  [6, 12],
  [6, 13],
  [6, 14],
  [7, 14],
  [8, 14],
  [8, 13],
  [8, 12],
  [8, 11],
  [8, 10],
  [8, 9],
  [8, 8],
  [9, 8],
  [10, 8],
  [11, 8],
  [12, 8],
  [13, 8],
  [14, 8],
  [14, 7],
  [14, 6],
  [13, 6],
  [12, 6],
  [11, 6],
  [10, 6],
  [9, 6],
  [8, 6],
  [8, 5],
  [8, 4],
  [8, 3],
  [8, 2],
  [8, 1],
  [8, 0],
  [7, 0],
  [6, 0],
];
const int _ringLen = 56;
const Map<String, int> _startIndex = {
  'red': 0,
  'green': 14,
  'yellow': 28,
  'blue': 42
};
const Set<int> _safeIndices = {0, 8, 14, 22, 28, 36, 42, 50};

const Map<String, List<List<int>>> _homeColumn = {
  'red': [
    [7, 1],
    [7, 2],
    [7, 3],
    [7, 4],
    [7, 5]
  ],
  'green': [
    [1, 7],
    [2, 7],
    [3, 7],
    [4, 7],
    [5, 7]
  ],
  'yellow': [
    [7, 13],
    [7, 12],
    [7, 11],
    [7, 10],
    [7, 9]
  ],
  'blue': [
    [13, 7],
    [12, 7],
    [11, 7],
    [10, 7],
    [9, 7]
  ],
};
const Map<String, List<List<int>>> _baseSlots = {
  'red': [
    [1, 1],
    [1, 4],
    [4, 1],
    [4, 4]
  ],
  'green': [
    [1, 10],
    [1, 13],
    [4, 10],
    [4, 13]
  ],
  'yellow': [
    [10, 10],
    [10, 13],
    [13, 10],
    [13, 13]
  ],
  'blue': [
    [10, 1],
    [10, 4],
    [13, 1],
    [13, 4]
  ],
};

int _absRingIndex(String color, int pos) =>
    (_startIndex[color]! + pos - 1) % _ringLen;

List<int>? _cellForPos(String color, int pos) {
  if (pos >= 1 && pos <= 56) return _ring[_absRingIndex(color, pos)];
  if (pos >= 57 && pos <= 61) return _homeColumn[color]![pos - 57];
  return null;
}

Offset _cellTopLeft(int r, int c) => Offset(c * _cellPct, r * _cellPct);

// Waiting spots sit in a 2x2 inside the yard's white panel: pulled a
// third of the way in from the slot cells toward the yard's centre.
Offset _yardSlotPos(String color, int tokenIdx) {
  final rc = _baseSlots[color]![tokenIdx];
  double inward(int cell) {
    final origin = (cell ~/ 9) * 9;
    final c = cell + 0.5 - origin;
    return origin + 3 + (c - 3) * (2 / 3);
  }

  return Offset(inward(rc[1]) * _cellPct, inward(rc[0]) * _cellPct);
}

// pos === 0 (yard) falls through to the defensive fallback below too, along
// with any out-of-range value (e.g. a client briefly out of sync with a
// mid-deploy backend still on an older token encoding) — treated as "yard"
// rather than crashing the whole board on a null cell lookup.
Offset _tokenPos(String color, int pos, int tokenIdx) {
  if (pos == 62) {
    const angle = {'red': 225.0, 'green': 315.0, 'yellow': 45.0, 'blue': 135.0};
    final rad = angle[color]! * math.pi / 180;
    final spread = 0.55 + tokenIdx * 0.3;
    final cx = 7.5 + math.cos(rad) * spread;
    final cy = 7.5 + math.sin(rad) * spread;
    return Offset(cx * _cellPct, cy * _cellPct);
  }
  final cell = _cellForPos(color, pos);
  if (cell == null) return _yardSlotPos(color, tokenIdx);
  final p = _cellTopLeft(cell[0], cell[1]);
  return Offset(p.dx + _cellPct / 2, p.dy + _cellPct / 2);
}

// ---------- 3D die ----------
const Map<int, List<int>> _pipLayouts = {
  1: [4],
  2: [0, 8],
  3: [0, 4, 8],
  4: [0, 2, 6, 8],
  5: [0, 2, 4, 6, 8],
  6: [0, 2, 3, 5, 6, 8],
};
// Target cumulative rotation (radians) to land each face front-on, mirroring
// LudoBoard.jsx's FACE_ROTATION table exactly.
const Map<int, List<double>> _faceRotation = {
  1: [0, 0],
  2: [0, -math.pi / 2],
  3: [-math.pi / 2, 0],
  4: [math.pi / 2, 0],
  5: [0, math.pi / 2],
  6: [0, math.pi],
};
const List<String> _faces = ['front', 'back', 'right', 'left', 'top', 'bottom'];
const Map<String, int> _faceValue = {
  'front': 1,
  'back': 6,
  'right': 2,
  'left': 5,
  'top': 3,
  'bottom': 4
};

class _LudoDice extends StatefulWidget {
  final int? value;
  final bool canRoll;
  final VoidCallback onRoll;

  const _LudoDice(
      {required this.value, required this.canRoll, required this.onRoll});

  @override
  State<_LudoDice> createState() => _LudoDiceState();
}

class _LudoDiceState extends State<_LudoDice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _fromX = 0, _fromY = 0, _toX = 0, _toY = 0;
  int? _seenValue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didUpdateWidget(covariant _LudoDice old) {
    super.didUpdateWidget(old);
    _maybeRoll();
  }

  void _maybeRoll() {
    final value = widget.value;
    if (value == null || value == _seenValue) return;
    _seenValue = value;
    final target = _faceRotation[value]!;
    final rand = math.Random();
    final extraX = (2 + rand.nextInt(2)) * 2 * math.pi;
    final extraY = (2 + rand.nextInt(2)) * 2 * math.pi;
    _fromX = _toX;
    _fromY = _toY;
    _toX = _fromX + _normalizedDiff(_fromX, target[0]) + extraX;
    _toY = _fromY + _normalizedDiff(_fromY, target[1]) + extraY;
    _controller
      ..reset()
      ..forward();
  }

  double _normalizedDiff(double from, double target) {
    final curMod = from % (2 * math.pi);
    final curPos = curMod < 0 ? curMod + 2 * math.pi : curMod;
    var targetMod = target % (2 * math.pi);
    if (targetMod < 0) targetMod += 2 * math.pi;
    var diff = targetMod - curPos;
    if (diff < 0) diff += 2 * math.pi;
    return diff;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.canRoll ? widget.onRoll : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutBack.transform(_controller.value);
          final rx = _fromX + (_toX - _fromX) * t;
          final ry = _fromY + (_toY - _fromY) * t;
          final fall = Curves.easeOutBack.transform(_controller.value);
          final bounce = 1 - (1 - fall).abs();
          return Opacity(
            opacity: widget.canRoll || widget.value != null ? 1 : 0.55,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0025)
                    ..translateByDouble(0.0, -6.0 * (1 - bounce), 0.0, 1.0)
                    ..rotateX(rx)
                    ..rotateY(ry),
                  child: Stack(
                    alignment: Alignment.center,
                    children: _faces.map((f) => _DieFace(name: f)).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DieFace extends StatelessWidget {
  final String name;
  const _DieFace({required this.name});

  Matrix4 _transform() {
    const half = 21.0;
    final m = Matrix4.identity();
    switch (name) {
      case 'front':
        m.translateByDouble(0.0, 0.0, half, 1.0);
        break;
      case 'back':
        m.rotateY(math.pi);
        m.translateByDouble(0.0, 0.0, half, 1.0);
        break;
      case 'right':
        m.rotateY(math.pi / 2);
        m.translateByDouble(0.0, 0.0, half, 1.0);
        break;
      case 'left':
        m.rotateY(-math.pi / 2);
        m.translateByDouble(0.0, 0.0, half, 1.0);
        break;
      case 'top':
        m.rotateX(math.pi / 2);
        m.translateByDouble(0.0, 0.0, half, 1.0);
        break;
      case 'bottom':
        m.rotateX(-math.pi / 2);
        m.translateByDouble(0.0, 0.0, half, 1.0);
        break;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final value = _faceValue[name]!;
    final layout = _pipLayouts[value]!;
    return Transform(
      alignment: Alignment.center,
      transform: _transform(),
      child: Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.18)),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF6F4E9), Color(0xFFD8D5C5)]),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(9, (i) {
            final on = layout.contains(i);
            return Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? const Color(0xFF0C0C0C) : Colors.transparent,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------- Board ----------
class LudoBoard extends StatelessWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final bool isHost;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;
  final VoidCallback onReset;

  const LudoBoard({
    super.key,
    required this.game,
    required this.myUserId,
    required this.isHost,
    required this.onJoin,
    required this.onMove,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final players = (game['players'] as List? ?? []).cast<Map>();
    final tokensByColor =
        Map<String, dynamic>.from(game['tokens'] as Map? ?? {});
    final status = game['status'] as String? ?? 'waiting';
    final turn = game['turn'] as String?;
    final winner = game['winner'] as String?;
    final diceValue = game['diceValue'] as int?;
    final movableTokenIndices =
        (game['movableTokenIndices'] as List? ?? []).cast<int>();
    final me = players
        .cast<Map?>()
        .firstWhere((p) => p?['userId'] == myUserId, orElse: () => null);
    final isPlayer = me != null;
    final isMyTurn = isPlayer && status == 'playing' && turn == myUserId;
    final currentPlayer = players
        .cast<Map?>()
        .firstWhere((p) => p?['userId'] == turn, orElse: () => null);
    final winnerPlayer = winner != null
        ? players
            .cast<Map?>()
            .firstWhere((p) => p?['userId'] == winner, orElse: () => null)
        : null;
    final movableSet = isMyTurn ? movableTokenIndices.toSet() : <int>{};

    String statusText() {
      if (status == 'won') return "${winnerPlayer?['name'] ?? 'Someone'} won!";
      if (players.length < 2) return 'Waiting for players (2 to 4)';
      if (currentPlayer == null) return '';
      if (isMyTurn) {
        return diceValue == null ? 'Your turn' : 'You rolled $diceValue';
      }
      return "${currentPlayer['name']}'s turn";
    }

    // Group tokens by occupied square so tokens stacked on one cell jitter
    // apart visually — mirrors LudoBoard.jsx's `grouped` map.
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in players) {
      final color = p['color'] as String;
      final tokens =
          ((tokensByColor[color] as List?) ?? [0, 0, 0, 0]).cast<int>();
      for (var tokenIdx = 0; tokenIdx < tokens.length; tokenIdx++) {
        final pos = tokens[tokenIdx];
        final groupKey =
            (pos == 0 || pos == 62) ? '$color-$tokenIdx' : '$pos:$color';
        grouped
            .putIfAbsent(groupKey, () => [])
            .add({'color': color, 'tokenIdx': tokenIdx, 'pos': pos});
      }
    }

    // Each player sits at their own colour's corner of the board —
    // red/green above it, blue/yellow below (matches _yardBlock's layout).
    Widget seatFor(String color) {
      final p = players
          .cast<Map?>()
          .firstWhere((p) => p?['color'] == color, orElse: () => null);
      if (p == null) {
        return players.length < 4 && status != 'won'
            ? const GameOpenSeat(size: 26, direction: Axis.horizontal)
            : const SizedBox(height: 30);
      }
      final finished =
          ((tokensByColor[color] as List?) ?? []).where((t) => t == 62).length;
      return GameSeat(
        userId: p['userId'] as String?,
        name: p['name'] as String?,
        isMe: p['userId'] == myUserId,
        isTurn: status == 'playing' && turn == p['userId'],
        color: _colorHex[color],
        size: 26,
        direction: Axis.horizontal,
        detail: Text('$finished/4 home'),
      );
    }

    Widget seatRow(String left, String right) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                  child: Align(
                      alignment: Alignment.centerLeft, child: seatFor(left))),
              Expanded(
                  child: Align(
                      alignment: Alignment.centerRight, child: seatFor(right))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameStatusLine(statusText(), highlight: status != 'waiting'),
        seatRow('red', 'green'),
        // Board
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD9A867), _kFrame, Color(0xFF8E6334)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 6))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final size = constraints.maxWidth;
                    return Container(
                      color: _kBoard,
                      child: Stack(
                        children: [
                          for (final c in _colors) _yardBlock(c, size),
                          for (final c in _colors) ..._yardSlots(c, size),
                          for (var i = 0; i < _ring.length; i++)
                            _ringCell(i, size),
                          for (final c in _colors)
                            for (var i = 0; i < _homeColumn[c]!.length; i++)
                              _homeCell(c, i, size),
                          _centerPinwheel(size),
                          for (final group in grouped.values)
                            for (var stackI = 0;
                                stackI < group.length;
                                stackI++)
                              _token(group, stackI, size, movableSet, me),
                          // The die, in the middle of the board.
                          Positioned(
                            left: _cellPct * 6 * size,
                            top: _cellPct * 6 * size,
                            width: _cellPct * 3 * size,
                            height: _cellPct * 3 * size,
                            child: Center(
                              child: FittedBox(
                                child: _LudoDice(
                                    value: diceValue,
                                    canRoll: isMyTurn && diceValue == null,
                                    onRoll: () => onMove({'action': 'roll'})),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        seatRow('blue', 'yellow'),
        const SizedBox(height: 6),

        // Hint, join / invite and play again — the die itself sits in the
        // middle of the board (above), so it's always in view.
        if (isMyTurn)
          GameStatusLine(diceValue == null
              ? 'Tap the die to roll'
              : 'Tap a glowing token'),
        if (!isPlayer || isHost)
          Center(
            child: GameJoinButton(
                seated: isPlayer,
                full: players.length >= 4,
                fallbackJoin: onJoin),
          ),
        if (isHost && status == 'won')
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              onPressed: onReset,
              child: const Text('Play again', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _yardBlock(String color, double size) {
    final hex = _colorHex[color]!;
    final pos = {
      'red': const {'top': 0.0, 'left': 0.0},
      'green': const {'top': 0.0, 'right': 0.0},
      'yellow': const {'bottom': 0.0, 'right': 0.0},
      'blue': const {'bottom': 0.0, 'left': 0.0},
    }[color]!;
    final side = _cellPct * 6 * size;
    return Positioned(
      top: pos['top'],
      left: pos['left'],
      right: pos['right'],
      bottom: pos['bottom'],
      width: side,
      height: side,
      child: Container(
        margin: EdgeInsets.all(side * 0.02),
        padding: EdgeInsets.all(side * 0.14),
        decoration: BoxDecoration(
          color: hex,
          borderRadius: BorderRadius.circular(side * 0.12),
          boxShadow: [
            BoxShadow(
                color: hex.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        // White panel; the four waiting spots are drawn by _yardSlots so
        // they sit exactly where the tokens wait.
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(side * 0.09),
          ),
        ),
      ),
    );
  }

  // The four round spots in a yard, centred on the token positions.
  List<Widget> _yardSlots(String color, double size) {
    final hex = _colorHex[color]!;
    final d = _cellPct * size * 1.45;
    return [
      for (var i = 0; i < 4; i++)
        Builder(builder: (context) {
          final c = _yardSlotPos(color, i);
          return Positioned(
            left: c.dx * size - d / 2,
            top: c.dy * size - d / 2,
            width: d,
            height: d,
            child: Container(
              decoration: BoxDecoration(
                color: hex.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border:
                    Border.all(color: hex.withValues(alpha: 0.55), width: 2),
              ),
            ),
          );
        }),
    ];
  }

  Widget _ringCell(int i, double size) {
    final rc = _ring[i];
    final p = _cellTopLeft(rc[0], rc[1]);
    final cell = _cellPct * size;
    final isStart = _startIndex.values.contains(i);
    final startColor = isStart
        ? _startIndex.entries.firstWhere((e) => e.value == i).key
        : null;
    final isSafe = _safeIndices.contains(i);
    return Positioned(
      left: p.dx * size,
      top: p.dy * size,
      width: cell,
      height: cell,
      child: Container(
        decoration: BoxDecoration(
          color: isStart ? _colorHex[startColor]! : Colors.white,
          border: Border.all(color: _kLine, width: 0.8),
        ),
        alignment: Alignment.center,
        child: isSafe && !isStart
            ? Text('★',
                style: TextStyle(
                    fontSize: cell * 0.5, color: const Color(0xFFC9BCA5)))
            : isStart
                ? Icon(Icons.arrow_forward_rounded,
                    size: cell * 0.55, color: Colors.white)
                : null,
      ),
    );
  }

  Widget _homeCell(String color, int i, double size) {
    final rc = _homeColumn[color]![i];
    final p = _cellTopLeft(rc[0], rc[1]);
    final cell = _cellPct * size;
    final hex = _colorHex[color]!;
    return Positioned(
      left: p.dx * size,
      top: p.dy * size,
      width: cell,
      height: cell,
      child: Container(
        decoration: BoxDecoration(
            color: hex, border: Border.all(color: _kLine, width: 0.8)),
      ),
    );
  }

  Widget _centerPinwheel(double size) {
    final side = _cellPct * 3 * size;
    final offset = _cellPct * 6 * size;
    return Positioned(
      left: offset,
      top: offset,
      width: side,
      height: side,
      child: const CustomPaint(painter: _HomeTriangles()),
    );
  }

  Widget _token(List<Map<String, dynamic>> group, int stackI, double size,
      Set<int> movableSet, Map? me) {
    final entry = group[stackI];
    final color = entry['color'] as String;
    final tokenIdx = entry['tokenIdx'] as int;
    final pos = entry['pos'] as int;
    final base = _tokenPos(color, pos, tokenIdx);
    final jitter = (pos != 0 && pos != 62 && group.length > 1)
        ? (stackI - (group.length - 1) / 2) * (_cellPct * 0.32)
        : 0.0;
    final isMovable =
        me != null && color == me['color'] && movableSet.contains(tokenIdx);
    final hex = _colorHex[color]!;
    final cell = _cellPct * size;
    final dSize = cell * 0.62;

    return Positioned(
      left: (base.dx + jitter) * size - dSize / 2,
      top: base.dy * size - dSize / 2,
      width: dSize,
      height: dSize,
      child: GestureDetector(
        onTap: isMovable
            ? () => onMove({'action': 'move', 'tokenIndex': tokenIdx})
            : null,
        child: _TokenDot(
            hex: hex,
            isMovable: isMovable,
            label: "Move ${_colorName[color]} token ${tokenIdx + 1}"),
      ),
    );
  }
}

class _TokenDot extends StatefulWidget {
  final Color hex;
  final bool isMovable;
  final String label;
  const _TokenDot(
      {required this.hex, required this.isMovable, required this.label});

  @override
  State<_TokenDot> createState() => _TokenDotState();
}

class _TokenDotState extends State<_TokenDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    if (widget.isMovable) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TokenDot old) {
    super.didUpdateWidget(old);
    if (widget.isMovable && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isMovable) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dy = widget.isMovable ? -4.0 * _controller.value : 0.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Semantics(
            label: widget.isMovable ? widget.label : null,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.4),
                  radius: 0.9,
                  colors: [
                    Color.lerp(widget.hex, Colors.white, 0.55)!,
                    widget.hex,
                    Color.lerp(widget.hex, Colors.black, 0.25)!,
                  ],
                  stops: const [0, 0.55, 1],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: widget.isMovable
                    ? [
                        BoxShadow(
                            color: widget.hex.withValues(alpha: 0.9),
                            blurRadius: 10,
                            spreadRadius: 2),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 3,
                            offset: Offset(0, 2))
                      ],
              ),
            ),
          ),
        );
      },
    );
  }
}


/// The finish in the middle: four coloured triangles meeting at the centre,
/// each pointing from its colour's home lane.
class _HomeTriangles extends CustomPainter {
  const _HomeTriangles();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);
    void tri(Offset a, Offset b, Color color) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white
            ..strokeWidth = 1);
    }

    tri(Offset.zero, Offset(0, h), _colorHex['red']!); // left
    tri(Offset.zero, Offset(w, 0), _colorHex['green']!); // top
    tri(Offset(w, 0), Offset(w, h), _colorHex['yellow']!); // right
    tri(Offset(0, h), Offset(w, h), _colorHex['blue']!); // bottom
  }

  @override
  bool shouldRepaint(covariant _HomeTriangles old) => false;
}
