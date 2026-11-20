import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../party/party_screen.dart';

/// Create a room → Game → Continue: pick a game (each card shows its
/// board), then Start game opens a game room with it ready. Public, with
/// the privacy question inside the room, like other quick rooms.
class ChooseGameScreen extends StatefulWidget {
  const ChooseGameScreen({super.key});

  @override
  State<ChooseGameScreen> createState() => _ChooseGameScreenState();
}

class _Game {
  final String id;
  final String name;
  final String sub;
  final Color bg;
  const _Game(this.id, this.name, this.sub, this.bg);
}

const _games = [
  _Game('chess', 'Chess', '1 vs 1 · classic', Color(0xFF14213D)),
  _Game('ludo', 'Ludo', '2–4 players', Color(0xFF123824)),
  _Game('tictactoe', 'Tic Tac Toe', '1 vs 1 · quick', Color(0xFF3A1610)),
  _Game('uno', 'UNO', '2–6 players', Color(0xFF3A2A0D)),
  _Game('truth_or_dare', 'Truth or Dare', 'Group · party', Color(0xFF3A1430)),
];

class _ChooseGameScreenState extends State<ChooseGameScreen>
    with SingleTickerProviderStateMixin {
  String? _picked;
  bool _busy = false;
  // The bottle spins once when the screen opens and again on tap.
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _pick(String id) {
    setState(() => _picked = id);
    if (id == 'truth_or_dare' &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _spin.forward(from: 0);
    }
  }

  Future<void> _start() async {
    final game = _picked;
    if (game == null) return;
    setState(() => _busy = true);
    try {
      final room = await ApiClient.post('/rooms', body: {
        'roomType': 'game',
        'gameType': game,
        'visibility': 'public',
        'askPrivacy': true,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t start the game. Try again.')));
        setState(() => _busy = false);
      }
    }
  }

  Widget _art(String id) => switch (id) {
        'chess' =>
          const CustomPaint(size: Size(80, 80), painter: ChessBoardPainter()),
        'ludo' =>
          const CustomPaint(size: Size(80, 80), painter: LudoBoardPainter()),
        'tictactoe' => const _TicTacToeArt(),
        'uno' =>
          const CustomPaint(size: Size(150, 96), painter: ColourCardsPainter()),
        _ => AnimatedBuilder(
            animation: _spin,
            builder: (_, __) => CustomPaint(
                size: const Size(84, 84),
                painter: BottleSpinnerPainter(
                    turn: Curves.easeOutCubic.transform(_spin.value) * 3)),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final picked = _games.where((g) => g.id == _picked).firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Choose a game')),
      body: SafeArea(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Your room opens with this game ready',
                style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
              children: [
                for (final g in _games)
                  Semantics(
                    button: true,
                    selected: _picked == g.id,
                    label: '${g.name}, ${g.sub}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _busy ? null : () => _pick(g.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFF17141F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _picked == g.id
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2),
                        ),
                        child: Stack(children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ColoredBox(
                                    color: g.bg,
                                    child: Center(
                                        child: FittedBox(child: _art(g.id))),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 7, 10, 9),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(g.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                        Text(g.sub,
                                            style: const TextStyle(
                                                color: AppColors.textFaint,
                                                fontSize: 11)),
                                      ]),
                                ),
                              ]),
                          if (_picked == g.id)
                            const Positioned(
                              right: 8,
                              top: 8,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.check_rounded,
                                    size: 15, color: Color(0xFF2E9B5F)),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: picked == null || _busy
                      ? null
                      : AppGradients.brandDiagonal,
                  color:
                      picked == null || _busy ? const Color(0xFF26232F) : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextButton(
                  onPressed: picked == null || _busy ? null : _start,
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text(
                      _busy
                          ? 'Starting…'
                          : picked == null
                              ? 'Pick a game'
                              : 'Start game · ${picked.name}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TicTacToeArt extends StatelessWidget {
  const _TicTacToeArt();

  @override
  Widget build(BuildContext context) {
    const marks = ['X', '', 'O', '', 'X', '', 'O', '', 'X'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: const Color(0xFFB8422C),
          borderRadius: BorderRadius.circular(6)),
      child: SizedBox(
        width: 72,
        height: 72,
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final m in marks)
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EF),
                    borderRadius: BorderRadius.circular(3)),
                alignment: Alignment.center,
                child: Text(m,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: m == 'X'
                            ? const Color(0xFFB8422C)
                            : const Color(0xFF2E4B9B))),
              ),
          ],
        ),
      ),
    );
  }
}

/// A chessboard set up for a new game, in a wooden frame.
class ChessBoardPainter extends CustomPainter {
  const ChessBoardPainter();

  static const _back = ['♜', '♞', '♝', '♛', '♚', '♝', '♞', '♜'];

  @override
  void paint(Canvas canvas, Size size) {
    final frame = size.shortestSide * 0.04;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(frame)),
        Paint()..color = const Color(0xFF6B4A2E));
    final sq = (size.shortestSide - 2 * frame) / 8;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final rect = Rect.fromLTWH(frame + c * sq, frame + r * sq, sq, sq);
        canvas.drawRect(
            rect,
            Paint()
              ..color = (r + c).isEven
                  ? const Color(0xFFE8EEF7)
                  : const Color(0xFF4A7BD9));
        String? piece;
        var white = false;
        if (r == 0) piece = _back[c];
        if (r == 1) piece = '♟';
        if (r == 6) {
          piece = '♟';
          white = true;
        }
        if (r == 7) {
          piece = _back[c];
          white = true;
        }
        if (piece == null) continue;
        for (final outline in [true, false]) {
          final tp = TextPainter(
            text: TextSpan(
              text: piece,
              style: TextStyle(
                fontSize: sq * 0.9,
                height: 1,
                foreground: outline
                    ? (Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = sq * 0.08
                      ..color = white ? const Color(0xFF1B1B22) : Colors.white)
                    : (Paint()
                      ..color = white ? Colors.white : const Color(0xFF1B1B22)),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas,
              rect.center - Offset(tp.width / 2, tp.height / 2 + sq * 0.02));
        }
      }
    }
  }

  @override
  bool shouldRepaint(ChessBoardPainter old) => false;
}

/// A Ludo board: four homes with tokens, the cross-shaped track with home
/// columns, and the four-colour centre.
class LudoBoardPainter extends CustomPainter {
  const LudoBoardPainter();

  static const red = Color(0xFFE53935),
      green = Color(0xFF43A047),
      blue = Color(0xFF1E88E5),
      yellow = Color(0xFFFBC02D);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 15;
    Rect cell(double x, double y, double w, double h) =>
        Rect.fromLTWH(x * u, y * u, w * u, h * u);
    final fill = Paint();
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Offset.zero & Size(15 * u, 15 * u), Radius.circular(u * 0.4)),
        fill..color = Colors.white);
    // Track lines.
    final line = Paint()
      ..color = const Color(0xFFC9C4BA)
      ..strokeWidth = u * 0.05;
    for (var i = 0; i <= 15; i++) {
      canvas.drawLine(Offset(6 * u, i * u), Offset(9 * u, i * u), line);
      canvas.drawLine(Offset(i * u, 6 * u), Offset(i * u, 9 * u), line);
    }
    for (final x in [6.0, 7.0, 8.0, 9.0]) {
      canvas.drawLine(Offset(x * u, 0), Offset(x * u, 15 * u), line);
      canvas.drawLine(Offset(0, x * u), Offset(15 * u, x * u), line);
    }
    // Homes with tokens.
    for (final (x, y, c) in [
      (0.0, 0.0, red),
      (9.0, 0.0, green),
      (0.0, 9.0, blue),
      (9.0, 9.0, yellow),
    ]) {
      canvas.drawRect(cell(x, y, 6, 6), fill..color = c);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              cell(x + 1, y + 1, 4, 4), Radius.circular(u * 0.4)),
          fill..color = Colors.white);
      for (final (dx, dy) in [(2.2, 2.2), (3.8, 2.2), (2.2, 3.8), (3.8, 3.8)]) {
        final o = Offset((x + dx) * u, (y + dy) * u);
        canvas.drawCircle(o, 0.62 * u, fill..color = Colors.white);
        canvas.drawCircle(o, 0.5 * u, fill..color = c);
      }
    }
    // Home columns and start squares.
    canvas.drawRect(cell(1, 7, 5, 1), fill..color = red);
    canvas.drawRect(cell(1, 6, 1, 1), fill..color = red);
    canvas.drawRect(cell(7, 1, 1, 5), fill..color = green);
    canvas.drawRect(cell(8, 1, 1, 1), fill..color = green);
    canvas.drawRect(cell(9, 7, 5, 1), fill..color = yellow);
    canvas.drawRect(cell(13, 8, 1, 1), fill..color = yellow);
    canvas.drawRect(cell(7, 9, 1, 5), fill..color = blue);
    canvas.drawRect(cell(6, 13, 1, 1), fill..color = blue);
    // Centre triangles.
    final mid = Offset(7.5 * u, 7.5 * u);
    void tri(Offset a, Offset b, Color c) => canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(mid.dx, mid.dy)
          ..close(),
        fill..color = c);
    tri(Offset(6 * u, 6 * u), Offset(6 * u, 9 * u), red);
    tri(Offset(6 * u, 6 * u), Offset(9 * u, 6 * u), green);
    tri(Offset(9 * u, 6 * u), Offset(9 * u, 9 * u), yellow);
    tri(Offset(6 * u, 9 * u), Offset(9 * u, 9 * u), blue);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Offset.zero & Size(15 * u, 15 * u), Radius.circular(u * 0.4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.15
          ..color = const Color(0xFF3A3A3A));
  }

  @override
  bool shouldRepaint(LudoBoardPainter old) => false;
}

/// A fan of five colour cards: red 7, yellow skip, green 5, blue +2 and a
/// four-colour wild.
class ColourCardsPainter extends CustomPainter {
  const ColourCardsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 100;
    const cards = [
      (Color(0xFFE53935), '7', false),
      (Color(0xFFFBC02D), '⊘', false),
      (Color(0xFF43A047), '5', false),
      (Color(0xFF1E88E5), '+2', false),
      (Color(0xFF1B1B22), '', true),
    ];
    final w = 56 * s, h = 84 * s;
    for (var i = 0; i < cards.length; i++) {
      final (color, label, wild) = cards[i];
      final k = i - 2;
      canvas.save();
      canvas.translate(
          size.width / 2 + k * 24 * s, size.height * 0.58 + k.abs() * 4 * s);
      canvas.rotate(k * 13 * math.pi / 180);
      final outer = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawRRect(RRect.fromRectAndRadius(outer, Radius.circular(7 * s)),
          Paint()..color = Colors.white);
      canvas.drawRRect(
          RRect.fromRectAndRadius(outer.deflate(3 * s), Radius.circular(5 * s)),
          Paint()..color = color);
      canvas.save();
      canvas.rotate(30 * math.pi / 180);
      final oval =
          Rect.fromCenter(center: Offset.zero, width: 34 * s, height: 54 * s);
      if (wild) {
        canvas.clipPath(Path()..addOval(oval));
        final q = oval.size / 2;
        canvas.drawRect(Rect.fromLTWH(oval.left, oval.top, q.width, q.height),
            Paint()..color = const Color(0xFFE53935));
        canvas.drawRect(Rect.fromLTWH(0, oval.top, q.width, q.height),
            Paint()..color = const Color(0xFF1E88E5));
        canvas.drawRect(Rect.fromLTWH(oval.left, 0, q.width, q.height),
            Paint()..color = const Color(0xFFFBC02D));
        canvas.drawRect(Rect.fromLTWH(0, 0, q.width, q.height),
            Paint()..color = const Color(0xFF43A047));
      } else {
        canvas.drawOval(oval, Paint()..color = Colors.white);
      }
      canvas.restore();
      if (!wild) {
        final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                  fontSize: 24 * s,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: color)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ColourCardsPainter old) => false;
}

/// Truth or Dare: a circle split Truth / Dare with a water bottle in the
/// middle, turned by [turn] full rotations.
class BottleSpinnerPainter extends CustomPainter {
  final double turn;
  const BottleSpinnerPainter({this.turn = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    final c = Offset(50 * s, 50 * s);
    final r = 48 * s;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF7C5CFF));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi / 2, math.pi,
        true, Paint()..color = const Color(0xFFD96BB0));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s
          ..color = Colors.white);
    for (final (text, x) in [('T', 22.0), ('D', 78.0)]) {
      final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: 11 * s,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x * s - tp.width / 2, 50 * s - tp.height / 2));
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn * 2 * math.pi + 0.6);
    canvas.translate(-c.dx, -c.dy);
    // Cap.
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(46 * s, 17 * s, 8 * s, 5 * s),
            Radius.circular(1.2 * s)),
        Paint()..color = const Color(0xFF1E5FD9));
    // Clear plastic body.
    final body = Path()
      ..moveTo(47 * s, 22 * s)
      ..lineTo(53 * s, 22 * s)
      ..lineTo(53 * s, 25 * s)
      ..quadraticBezierTo(57 * s, 28 * s, 57 * s, 33 * s)
      ..lineTo(57 * s, 71 * s)
      ..quadraticBezierTo(57 * s, 77 * s, 51 * s, 77 * s)
      ..lineTo(49 * s, 77 * s)
      ..quadraticBezierTo(43 * s, 77 * s, 43 * s, 71 * s)
      ..lineTo(43 * s, 33 * s)
      ..quadraticBezierTo(43 * s, 28 * s, 47 * s, 25 * s)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFD9F3FF));
    // Water.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(Rect.fromLTWH(43 * s, 48 * s, 14 * s, 30 * s),
        Paint()..color = const Color(0xD95CC3F0));
    canvas.restore();
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * s
          ..color = const Color(0xFF8CCBE8));
    // Label.
    canvas.drawRect(Rect.fromLTWH(43.4 * s, 37 * s, 13.2 * s, 6 * s),
        Paint()..color = const Color(0xFF1E88E5));
    canvas.restore();
  }

  @override
  bool shouldRepaint(BottleSpinnerPainter old) => old.turn != turn;
}
