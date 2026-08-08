import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';

/// Dart port of the web app's MascotEyes.jsx — pupils track the pointer
/// (mouse hover on web/desktop; stays centered on touch-only mobile, which
/// is an acceptable no-op there) and the mascot covers its eyes while
/// [covering] is true, driven by the phone field's focus state on the
/// login screen.
class MascotEyes extends StatefulWidget {
  final bool covering;
  final double size;

  const MascotEyes({super.key, this.covering = false, this.size = 120});

  @override
  State<MascotEyes> createState() => _MascotEyesState();
}

class _MascotEyesState extends State<MascotEyes> {
  Offset _pupil = Offset.zero;
  final _key = GlobalKey();

  void _handleHover(PointerHoverEvent event) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final dx = event.position.dx - center.dx;
    final dy = event.position.dy - center.dy;
    final angle = atan2(dy, dx);
    final dist = min(4.0, sqrt(dx * dx + dy * dy) / 40);
    setState(() => _pupil = Offset(cos(angle) * dist, sin(angle) * dist));
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: _key,
      onHover: _handleHover,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: kSpringCurve,
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _MascotPainter(pupil: _pupil, covering: widget.covering),
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final Offset pupil;
  final bool covering;

  _MascotPainter({required this.pupil, required this.covering});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final head = Paint()..color = AppColors.surface3;
    canvas.drawCircle(p(60, 60), 52 * s, head);
    final headBorder = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(p(60, 60), 52 * s, headBorder);

    canvas.drawCircle(p(26, 26), 14 * s, head);
    canvas.drawCircle(p(94, 26), 14 * s, head);

    if (covering) {
      final lidPaint = Paint()
        ..color = AppColors.textDim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * s
        ..strokeCap = StrokeCap.round;
      final leftPath = Path()
        ..moveTo(32 * s, 60 * s)
        ..quadraticBezierTo(42 * s, 52 * s, 52 * s, 60 * s);
      final rightPath = Path()
        ..moveTo(68 * s, 60 * s)
        ..quadraticBezierTo(78 * s, 52 * s, 88 * s, 60 * s);
      canvas.drawPath(leftPath, lidPaint);
      canvas.drawPath(rightPath, lidPaint);
    } else {
      final eyeWhite = Paint()..color = Colors.white;
      final pupilPaint = Paint()..color = const Color(0xFF1A1A24);
      canvas.drawOval(Rect.fromCenter(center: p(42, 58), width: 24 * s, height: 28 * s), eyeWhite);
      canvas.drawOval(Rect.fromCenter(center: p(78, 58), width: 24 * s, height: 28 * s), eyeWhite);
      canvas.drawCircle(p(42, 58) + pupil, 6 * s, pupilPaint);
      canvas.drawCircle(p(78, 58) + pupil, 6 * s, pupilPaint);
    }

    final nose = Paint()..color = AppColors.primary;
    canvas.drawCircle(p(60, 76), 4 * s, nose);

    final smile = Paint()
      ..color = AppColors.textDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(50 * s, 84 * s)
      ..quadraticBezierTo(60 * s, 90 * s, 70 * s, 84 * s);
    canvas.drawPath(smilePath, smile);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.pupil != pupil || oldDelegate.covering != covering;
  }
}
