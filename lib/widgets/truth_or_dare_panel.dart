import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'game_seat.dart';

const _kSeatColors = [
  Color(0xFFFF3D78),
  Color(0xFFFFC93C),
  Color(0xFF38E6C5),
  Color(0xFF8B7BFF),
  Color(0xFFFF8A3D),
  Color(0xFF4DC4FF)
];
const _kSpinDuration = Duration(milliseconds: 3200);

/// Presentational only — turn selection (the "spin the bottle" random pick)
/// and prompt selection both happen server-side in src/games/truthOrDare.js;
/// this just renders whatever `game` state the server last broadcast, and
/// plays a local bottle-spin animation toward the new turn whenever it
/// changes so the reveal feels like an actual spin rather than a jump-cut.
class TruthOrDarePanel extends StatefulWidget {
  final Map<String, dynamic> game;
  final String? myUserId;
  final VoidCallback onJoin;
  final void Function(Map<String, dynamic> move) onMove;

  const TruthOrDarePanel(
      {super.key,
      required this.game,
      required this.myUserId,
      required this.onJoin,
      required this.onMove});

  @override
  State<TruthOrDarePanel> createState() => _TruthOrDarePanelState();
}

class _TruthOrDarePanelState extends State<TruthOrDarePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _fromAngle = 0;
  double _toAngle = 0;
  String? _prevTurn;
  String? _displayTurn;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _prevTurn = widget.game['turn'] as String?;
    _displayTurn = _prevTurn;
    _controller = AnimationController(vsync: this, duration: _kSpinDuration)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _spinning = false;
            _displayTurn = widget.game['turn'] as String?;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant TruthOrDarePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTurn = widget.game['turn'] as String?;
    if (newTurn == _prevTurn) return;
    _prevTurn = newTurn;
    final players = (widget.game['players'] as List? ?? []).cast<Map>();
    final idx = players.indexWhere((p) => p['userId'] == newTurn);
    if (newTurn == null || players.isEmpty || idx == -1) {
      setState(() => _displayTurn = newTurn);
      return;
    }
    final n = players.length;
    final seatAngle = (360 / n) * idx - 90;
    final targetRotation = seatAngle + 90;
    final extraSpins = 4 + Random().nextInt(3);
    _fromAngle = _toAngle;
    _toAngle =
        _fromAngle + extraSpins * 360 + (targetRotation - (_fromAngle % 360));
    setState(() => _spinning = true);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final players = (game['players'] as List? ?? []).cast<Map>();
    final status = game['status'] as String? ?? 'waiting';
    final prompt = game['currentPrompt'] as Map?;
    final isPlayer = players.any((p) => p['userId'] == widget.myUserId);
    final isMyTurn = isPlayer &&
        status == 'playing' &&
        _displayTurn == widget.myUserId &&
        !_spinning;
    final currentPlayer = players
        .cast<Map?>()
        .firstWhere((p) => p?['userId'] == _displayTurn, orElse: () => null);
    final n = players.length;

    final eased = Curves.easeOutCubic.transform(_controller.value);
    final currentAngle = _fromAngle + (_toAngle - _fromAngle) * eased;

    // Seats around a round table, the bottle in the middle — it spins
    // toward whoever the server picked (see didUpdateWidget).
    final table = LayoutBuilder(builder: (context, constraints) {
      final side = min(constraints.maxWidth, 320.0);
      final radius = side / 2 - 38;
      final seatCount = status == 'waiting' ? max(n + 1, 2) : n;
      return SizedBox(
        width: side,
        height: side,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: radius * 2 - 30,
              height: radius * 2 - 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                color: AppColors.surface.withValues(alpha: 0.55),
              ),
            ),
            for (var i = 0; i < seatCount; i++)
              Builder(builder: (context) {
                final rad = ((360 / seatCount) * i - 90) * pi / 180;
                final offset = Offset(cos(rad) * radius, sin(rad) * radius);
                if (i >= n) {
                  return Transform.translate(
                      offset: offset, child: const GameOpenSeat(size: 28));
                }
                final p = players[i];
                return Transform.translate(
                  offset: offset,
                  child: GameSeat(
                    userId: p['userId'] as String?,
                    name: p['name'] as String?,
                    isMe: p['userId'] == widget.myUserId,
                    isTurn: !_spinning &&
                        status == 'playing' &&
                        p['userId'] == _displayTurn,
                    color: _kSeatColors[i % _kSeatColors.length]
                        .withValues(alpha: 0.6),
                    size: 28,
                  ),
                );
              }),
            Transform.rotate(
              angle: currentAngle * pi / 180,
              child: const _Bottle(),
            ),
          ],
        ),
      );
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameStatusLine(
          status == 'waiting'
              ? (n < 2 ? 'Waiting for players' : '')
              : _spinning
                  ? 'Spinning…'
                  : isMyTurn
                      ? 'Your turn'
                      : "${currentPlayer?['name'] ?? 'Their'}'s turn",
          highlight: status != 'waiting',
        ),
        Center(child: table),
        if (status != 'waiting' && !_spinning)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: prompt == null
                ? (isMyTurn
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () => widget.onMove(
                                {'action': 'choose', 'choice': 'truth'}),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary),
                            child: const Text('🤔 Truth'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => widget
                                .onMove({'action': 'choose', 'choice': 'dare'}),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent),
                            child: const Text('🔥 Dare'),
                          ),
                        ],
                      )
                    : Text(
                        'Waiting for ${currentPlayer?['name'] ?? 'them'} to choose…',
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 13)))
                // Matches TruthOrDareDark.dc.html's big gradient reveal
                // card — the mockup's "Round N", "🔥 streak", and
                // Skip(−10)/Done(+20) coin-stakes aren't shown here:
                // src/games/truthOrDare.js has no round counter, streak,
                // or scoring/penalty system at all, so there's nothing
                // real to back them with.
                : Column(
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 260),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppGradients.brand),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.accent2.withValues(alpha: 0.45),
                                blurRadius: 30,
                                offset: const Offset(0, 14))
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withValues(alpha: 0.18)),
                              alignment: Alignment.center,
                              child: Icon(
                                  prompt['type'] == 'truth'
                                      ? Icons.help_outline_rounded
                                      : Icons.local_fire_department_rounded,
                                  color: Colors.white,
                                  size: 19),
                            ),
                            const SizedBox(height: 12),
                            Text(
                                (prompt['type'] as String? ?? '').toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Text(prompt['text'] as String? ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                      if (isMyTurn)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: GestureDetector(
                            onTap: () => widget.onMove({'action': 'next'}),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 11),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                    colors: AppGradients.brand),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.accent2
                                          .withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8))
                                ],
                              ),
                              child: const Text('Done — spin for next',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        const SizedBox(height: 10),
        GameJoinButton(
            seated: isPlayer, full: false, fallbackJoin: widget.onJoin),
      ],
    );
  }
}

/// A glass bottle seen from above, neck pointing up — rotated about its
/// middle so the neck lands on the chosen player.
class _Bottle extends StatelessWidget {
  const _Bottle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 96,
      child: CustomPaint(painter: _BottlePainter()),
    );
  }
}

class _BottlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.42, w, h * 0.58), Radius.circular(w * 0.45));
    final neck = Path()
      ..moveTo(w * 0.12, h * 0.48)
      ..quadraticBezierTo(w * 0.32, h * 0.36, w * 0.36, h * 0.14)
      ..lineTo(w * 0.64, h * 0.14)
      ..quadraticBezierTo(w * 0.68, h * 0.36, w * 0.88, h * 0.48)
      ..close();
    final glass = Paint()..color = const Color(0xFF2F8A5C);
    canvas.drawRRect(body, glass);
    canvas.drawPath(neck, glass);
    // Cap — the end that points at the chosen player.
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.33, 0, w * 0.34, h * 0.15),
            const Radius.circular(3)),
        Paint()..color = AppColors.accent);
    // Highlight down the side so it reads as glass.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.2, h * 0.52, w * 0.14, h * 0.38),
            Radius.circular(w * 0.07)),
        Paint()..color = Colors.white.withValues(alpha: 0.28));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
