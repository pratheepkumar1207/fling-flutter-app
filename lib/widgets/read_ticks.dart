import 'package:flutter/material.dart';

/// The double tick for a seen message (a single tick for sent), drawn to
/// the same 24×24 shape the design uses.
class ReadTicks extends StatelessWidget {
  final bool seen;
  final Color color;
  final double size;
  const ReadTicks(
      {super.key, required this.seen, required this.color, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: seen ? 'Seen' : 'Sent',
      child: CustomPaint(
          size: Size.square(size), painter: _TicksPainter(seen, color)),
    );
  }
}

class _TicksPainter extends CustomPainter {
  final bool seen;
  final Color color;
  _TicksPainter(this.seen, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path tick(double x, double y, double a, double b) => Path()
      ..moveTo(x * s, y * s)
      ..relativeLineTo(a * s, a * s)
      ..relativeLineTo(b * s, -(b + 1) * s);
    if (seen) {
      canvas.drawPath(tick(2, 13, 4, 8), paint);
      canvas.drawPath(tick(10, 15, 2, 8), paint);
    } else {
      canvas.drawPath(tick(5, 13, 4, 10), paint);
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.seen != seen || old.color != color;
}
