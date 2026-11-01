import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'face_tracker.dart';

/// A sticker that follows the face. [paint] draws it in face units: the origin
/// is between the eyes, one unit is the face's width and y points down, so the
/// eyes sit near x ±0.22, the nose at y 0.28, the mouth at y 0.52, the chin at
/// y 0.8 and the top of the head at y -0.65.
class FaceFilter {
  final String id;
  final String name;
  final String group;
  final void Function(Canvas) paint;
  const FaceFilter(this.id, this.name, this.group, this.paint);

  /// Face units covered by a saved sticker, and its size in pixels.
  /// FaceFilterChannel.kt relies on both.
  static const stickerUnits = 4.0;
  static const stickerPixels = 1024;

  /// Renders to a transparent PNG, centred on the origin, for baking.
  Future<String> renderSticker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const px = stickerPixels / stickerUnits;
    canvas.translate(stickerPixels / 2, stickerPixels / 2);
    canvas.scale(px);
    paint(canvas);
    final image =
        await recorder.endRecording().toImage(stickerPixels, stickerPixels);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/insync_sticker_$id.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file.path;
  }

  static const groups = [
    'Coolers',
    'Ribbons',
    'Hair',
    'Hats',
    'Animals',
    'Makeup',
    'Sparkle',
  ];

  static final List<FaceFilter> all = [
    ..._coolers(),
    ..._ribbons(),
    ..._hair(),
    ..._hats(),
    ..._animals(),
    ..._makeup(),
    ..._sparkle(),
  ];
}

/// Draws [filter] on the live picture. Fills the picture it sits on.
class FaceFilterOverlay extends StatelessWidget {
  final FaceFilter filter;
  final FacePose pose;
  final bool mirrored;
  const FaceFilterOverlay(
      {super.key,
      required this.filter,
      required this.pose,
      required this.mirrored});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
            painter: _OverlayPainter(filter, pose, mirrored),
            size: Size.infinite),
      );
}

class _OverlayPainter extends CustomPainter {
  final FaceFilter filter;
  final FacePose pose;
  final bool mirrored;
  _OverlayPainter(this.filter, this.pose, this.mirrored);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.translate(pose.x * size.width, pose.y * size.height);
    canvas.rotate(pose.angle);
    final unit = pose.width * size.width;
    canvas.scale(unit);
    filter.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.filter.id != filter.id || old.pose != pose;
}

/// A filter's small picture in the tray, drawn on a plain head shape.
class FaceFilterThumb extends StatelessWidget {
  final FaceFilter filter;
  const FaceFilterThumb(this.filter, {super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _ThumbPainter(filter), size: Size.infinite),
      );
}

class _ThumbPainter extends CustomPainter {
  final FaceFilter filter;
  _ThumbPainter(this.filter);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height * 0.46);
    canvas.scale(size.width * 0.42);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 0.2), width: 0.8, height: 1.25),
        _fill(const Color(0xFF3A3A46)));
    filter.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.filter.id != filter.id;
}

Paint _fill(Color c) => Paint()..color = c;
Paint _line(Color c, double width) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Color _lighter(Color c, [double by = 0.28]) => Color.lerp(c, Colors.white, by)!;
Color _darker(Color c, [double by = 0.28]) => Color.lerp(c, Colors.black, by)!;

const _pink = Color(0xFFFB3F65);
const _purple = Color(0xFF9B3BF5);
const _blue = Color(0xFF4073FC);
const _gold = Color(0xFFF5C344);
const _mint = Color(0xFF45D6A8);
const _white = Color(0xFFFAFAFA);
const _black = Color(0xFF15151A);

void _mirror(Canvas c, void Function() draw) {
  draw();
  c.save();
  c.scale(-1, 1);
  draw();
  c.restore();
}

// ---------------------------------------------------------------- Coolers

const _eyeL = Offset(-0.22, 0);

void _bridge(Canvas c, Color frame) {
  c.drawLine(const Offset(-0.07, -0.02), const Offset(0.07, -0.02),
      _line(frame, 0.028));
}

void _glassEach(Canvas c, Path lens, Color tint, Color frame, double frameW) {
  _mirror(c, () {
    c.drawPath(lens, _fill(tint));
    c.drawPath(lens, _line(frame, frameW));
    c.drawLine(const Offset(-0.33, -0.04), const Offset(-0.25, -0.1),
        _line(_lighter(tint, 0.6).withValues(alpha: 0.6), 0.016));
  });
}

Path _aviatorLens() => Path()
  ..moveTo(-0.39, -0.08)
  ..quadraticBezierTo(-0.22, -0.13, -0.08, -0.07)
  ..quadraticBezierTo(-0.05, 0.1, -0.2, 0.13)
  ..quadraticBezierTo(-0.37, 0.12, -0.39, -0.08)
  ..close();

Path _wayfarerLens() => Path()
  ..moveTo(-0.4, -0.1)
  ..lineTo(-0.07, -0.08)
  ..lineTo(-0.1, 0.09)
  ..quadraticBezierTo(-0.25, 0.13, -0.36, 0.08)
  ..close();

Path _roundLens() =>
    Path()..addOval(Rect.fromCircle(center: _eyeL, radius: 0.145));

Path _catLens() => Path()
  ..moveTo(-0.46, -0.16)
  ..quadraticBezierTo(-0.25, -0.11, -0.07, -0.06)
  ..quadraticBezierTo(-0.07, 0.1, -0.2, 0.11)
  ..quadraticBezierTo(-0.36, 0.1, -0.46, -0.16)
  ..close();

Path _squareLens() => Path()
  ..addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: _eyeL, width: 0.31, height: 0.2),
      const Radius.circular(0.03)));

Path _heartPath(Offset o, double s) => Path()
  ..moveTo(o.dx, o.dy + s * 0.9)
  ..cubicTo(o.dx - s * 1.3, o.dy + s * 0.1, o.dx - s * 0.8, o.dy - s * 0.9,
      o.dx, o.dy - s * 0.25)
  ..cubicTo(o.dx + s * 0.8, o.dy - s * 0.9, o.dx + s * 1.3, o.dy + s * 0.1,
      o.dx, o.dy + s * 0.9)
  ..close();

Path _starPath(Offset o, double r, {int points = 5, double inner = 0.45}) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? r : r * inner;
    final a = -math.pi / 2 + i * math.pi / points;
    final x = o.dx + math.cos(a) * radius;
    final y = o.dy + math.sin(a) * radius;
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p..close();
}

List<FaceFilter> _coolers() {
  FaceFilter make(String name, Path lens, Color tint, Color frame,
      [double w = 0.024]) {
    final id = 'cooler_${name.toLowerCase().replaceAll(' ', '_')}';
    return FaceFilter(id, name, 'Coolers', (c) {
      _glassEach(c, lens, tint, frame, w);
      _bridge(c, frame);
    });
  }

  const dark = Color(0xE6101018);
  return [
    make('Aviator gold', _aviatorLens(), const Color(0xCC2B2B33), _gold),
    make('Aviator pink', _aviatorLens(), const Color(0xCCFB3F65), _white),
    make('Wayfarer', _wayfarerLens(), dark, _black, 0.04),
    make('Wayfarer blue', _wayfarerLens(), const Color(0xCC4073FC), _black, 0.04),
    make('Round retro', _roundLens(), const Color(0xCC5B3A1E), _gold),
    make('Round purple', _roundLens(), const Color(0xCC9B3BF5), _white),
    make('Cat eye', _catLens(), dark, _pink, 0.03),
    make('Cat eye white', _catLens(), const Color(0xCC2B2B33), _white, 0.035),
    make('Square black', _squareLens(), dark, _black, 0.04),
    make('Square mint', _squareLens(), const Color(0xCC45D6A8), _white, 0.03),
    make('Heart red', _heartPath(_eyeL, 0.16), const Color(0xDDFB3F65), _white),
    make('Heart lilac', _heartPath(_eyeL, 0.16), const Color(0xDDB98CF7), _white),
    make('Star gold', _starPath(_eyeL, 0.19), const Color(0xDDF5C344), _white),
    make('Star blue', _starPath(_eyeL, 0.19), const Color(0xDD4073FC), _white),
    FaceFilter('cooler_shield', 'Shield', 'Coolers', (c) {
      final p = Path()
        ..moveTo(-0.42, -0.11)
        ..quadraticBezierTo(0, -0.17, 0.42, -0.11)
        ..quadraticBezierTo(0.43, 0.1, 0.25, 0.12)
        ..quadraticBezierTo(0.1, 0.13, 0, 0.05)
        ..quadraticBezierTo(-0.1, 0.13, -0.25, 0.12)
        ..quadraticBezierTo(-0.43, 0.1, -0.42, -0.11)
        ..close();
      c.drawPath(p, _fill(const Color(0xD92B2B44)));
      c.drawPath(p, _line(_white, 0.02));
    }),
    FaceFilter('cooler_pixel', 'Pixel', 'Coolers', (c) {
      final b = _fill(_black);
      c.drawRect(const Rect.fromLTWH(-0.42, -0.1, 0.84, 0.05), b);
      _mirror(c, () {
        c.drawRect(const Rect.fromLTWH(-0.37, -0.05, 0.3, 0.05), b);
        c.drawRect(const Rect.fromLTWH(-0.32, 0, 0.25, 0.05), b);
        c.drawRect(const Rect.fromLTWH(-0.27, 0.05, 0.15, 0.05), b);
        c.drawRect(const Rect.fromLTWH(-0.32, -0.05, 0.05, 0.05), _fill(_white));
        c.drawRect(const Rect.fromLTWH(-0.27, 0, 0.05, 0.05), _fill(_white));
      });
    }),
  ];
}

// ---------------------------------------------------------------- Ribbons

void _bow(Canvas c, Offset o, double s, Color color, {double tilt = 0}) {
  c.save();
  c.translate(o.dx, o.dy);
  c.rotate(tilt);
  c.scale(s);
  final dark = _darker(color, 0.22);
  // Tails sit under the loops.
  for (final side in const [-1.0, 1.0]) {
    final tail = Path()
      ..moveTo(0, 0.04)
      ..quadraticBezierTo(side * 0.14, 0.2, side * 0.2, 0.42)
      ..lineTo(side * 0.08, 0.37)
      ..lineTo(side * 0.02, 0.44)
      ..quadraticBezierTo(side * 0.02, 0.2, 0, 0.04)
      ..close();
    c.drawPath(tail, _fill(dark));
    final loop = Path()
      ..moveTo(0, 0)
      ..cubicTo(side * 0.18, -0.26, side * 0.5, -0.24, side * 0.5, -0.02)
      ..cubicTo(side * 0.5, 0.2, side * 0.18, 0.22, 0, 0)
      ..close();
    c.drawPath(loop, _fill(color));
    c.drawPath(
        Path()
          ..moveTo(side * 0.08, 0)
          ..quadraticBezierTo(side * 0.24, -0.1, side * 0.36, -0.05),
        _line(dark, 0.025));
  }
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 0.15, height: 0.17),
          const Radius.circular(0.05)),
      _fill(_lighter(color, 0.12)));
  c.restore();
}

void _headband(Canvas c, Color color) {
  c.drawPath(
      Path()
        ..moveTo(-0.45, -0.1)
        ..quadraticBezierTo(0, -0.95, 0.45, -0.1),
      _line(color, 0.075));
}

List<FaceFilter> _ribbons() {
  const colours = {
    'Pink': _pink,
    'Red': Color(0xFFE02F3B),
    'Lilac': Color(0xFFB98CF7),
    'Blue': Color(0xFF6FA8FF),
    'White': _white,
    'Black': _black,
  };
  return [
    for (final e in colours.entries.take(5))
      FaceFilter('ribbon_top_${e.key.toLowerCase()}', 'Top bow ${e.key}',
          'Ribbons', (c) => _bow(c, const Offset(0, -0.68), 0.62, e.value)),
    for (final e in colours.entries.skip(2).take(3))
      FaceFilter(
          'ribbon_side_${e.key.toLowerCase()}',
          'Side bow ${e.key}',
          'Ribbons',
          (c) => _bow(c, const Offset(0.36, -0.46), 0.5, e.value, tilt: 0.45)),
    for (final e in colours.entries.take(3))
      FaceFilter('ribbon_band_${e.key.toLowerCase()}', 'Headband ${e.key}',
          'Ribbons', (c) {
        _headband(c, e.value);
        _bow(c, const Offset(0.24, -0.56), 0.42, e.value, tilt: 0.3);
      }),
    for (final e in [
      colours.entries.first,
      colours.entries.elementAt(3),
      colours.entries.last
    ])
      FaceFilter('ribbon_two_${e.key.toLowerCase()}', 'Two bows ${e.key}',
          'Ribbons', (c) {
        _bow(c, const Offset(-0.42, -0.42), 0.42, e.value, tilt: -0.4);
        _bow(c, const Offset(0.42, -0.42), 0.42, e.value, tilt: 0.4);
      }),
  ];
}

// ------------------------------------------------------------------- Hair

Path _faceHole({double top = -0.42}) => Path()
  ..addOval(Rect.fromLTRB(-0.4, top, 0.4, 0.84));

/// [outer] minus the face, then soft strands so it doesn't read as a flat cap.
void _hairShape(Canvas c, Path outer, Color colour,
    {Path? hole, List<Path> strands = const []}) {
  final shape =
      Path.combine(PathOperation.difference, outer, hole ?? _faceHole());
  c.drawPath(shape, _fill(colour));
  c.save();
  c.clipPath(shape);
  final light = _line(_lighter(colour, 0.22).withValues(alpha: 0.75), 0.018);
  final dark = _line(_darker(colour, 0.3).withValues(alpha: 0.7), 0.018);
  for (var i = 0; i < strands.length; i++) {
    c.drawPath(strands[i], i.isEven ? light : dark);
  }
  c.restore();
}

List<Path> _fallStrands(double bottom, {double spread = 0.62}) => [
      for (var i = 0; i < 12; i++)
        () {
          final x = -spread + i * (spread * 2 / 11);
          return Path()
            ..moveTo(x * 0.3, -0.72)
            ..quadraticBezierTo(x * 1.2, -0.2, x, bottom);
        }(),
    ];

void _longHair(Canvas c, Color k) {
  final outer = Path()
    ..moveTo(-0.62, 1.45)
    ..cubicTo(-0.72, 0.5, -0.72, -0.8, 0, -0.8)
    ..cubicTo(0.72, -0.8, 0.72, 0.5, 0.62, 1.45)
    ..lineTo(0.3, 1.5)
    ..lineTo(0.34, 0.6)
    ..lineTo(-0.34, 0.6)
    ..lineTo(-0.3, 1.5)
    ..close();
  _hairShape(c, outer, k, strands: _fallStrands(1.45));
}

void _curtainBangs(Canvas c, Color k) {
  final outer = Path()
    ..moveTo(-0.58, 1.05)
    ..cubicTo(-0.7, 0.4, -0.7, -0.78, 0, -0.78)
    ..cubicTo(0.7, -0.78, 0.7, 0.4, 0.58, 1.05)
    ..lineTo(0.32, 1.05)
    ..lineTo(0.36, 0.45)
    ..lineTo(-0.36, 0.45)
    ..lineTo(-0.32, 1.05)
    ..close();
  final hole = Path()
    ..moveTo(0, -0.34)
    ..quadraticBezierTo(-0.2, -0.16, -0.38, 0.18)
    ..lineTo(-0.38, 0.5)
    ..quadraticBezierTo(0, 1.1, 0.38, 0.5)
    ..lineTo(0.38, 0.18)
    ..quadraticBezierTo(0.2, -0.16, 0, -0.34)
    ..close();
  _hairShape(c, outer, k, hole: hole, strands: _fallStrands(1.05));
}

void _wolfCut(Canvas c, Color k) {
  final outer = Path()
    ..moveTo(-0.46, 1.1)
    ..lineTo(-0.56, 0.72)
    ..lineTo(-0.72, 0.62)
    ..lineTo(-0.62, 0.3)
    ..lineTo(-0.76, 0.12)
    ..cubicTo(-0.72, -0.5, -0.45, -0.86, 0, -0.84)
    ..cubicTo(0.45, -0.86, 0.72, -0.5, 0.76, 0.12)
    ..lineTo(0.62, 0.3)
    ..lineTo(0.72, 0.62)
    ..lineTo(0.56, 0.72)
    ..lineTo(0.46, 1.1)
    ..lineTo(0.34, 0.6)
    ..lineTo(-0.34, 0.6)
    ..close();
  final hole = Path()
    ..moveTo(-0.38, -0.12)
    ..lineTo(-0.24, -0.2)
    ..lineTo(-0.14, -0.1)
    ..lineTo(-0.02, -0.2)
    ..lineTo(0.1, -0.1)
    ..lineTo(0.24, -0.2)
    ..lineTo(0.38, -0.12)
    ..lineTo(0.38, 0.5)
    ..quadraticBezierTo(0, 1.1, -0.38, 0.5)
    ..close();
  _hairShape(c, outer, k, hole: hole, strands: _fallStrands(1.1, spread: 0.7));
}

void _bob(Canvas c, Color k) {
  final outer = Path()
    ..moveTo(-0.56, 0.74)
    ..cubicTo(-0.74, 0.1, -0.68, -0.78, 0, -0.78)
    ..cubicTo(0.68, -0.78, 0.74, 0.1, 0.56, 0.74)
    ..quadraticBezierTo(0.42, 0.8, 0.32, 0.72)
    ..lineTo(0.34, 0.4)
    ..lineTo(-0.34, 0.4)
    ..lineTo(-0.32, 0.72)
    ..quadraticBezierTo(-0.42, 0.8, -0.56, 0.74)
    ..close();
  final fringe = Path()..addRect(const Rect.fromLTRB(-0.38, -0.1, 0.38, 0.9));
  _hairShape(c, outer, k, hole: fringe, strands: _fallStrands(0.78));
}

void _curls(Canvas c, Color k) {
  final dark = _darker(k, 0.18);
  final light = _lighter(k, 0.14);
  final random = math.Random(7);
  final puffs = Path();
  for (var a = 0.0; a < math.pi * 2; a += 0.3) {
    for (final r in const [0.6, 0.74]) {
      puffs.addOval(Rect.fromCircle(
          center: Offset(math.cos(a) * r, -0.08 + math.sin(a) * r * 0.98),
          radius: 0.15));
    }
  }
  final shape = Path.combine(PathOperation.difference, puffs, _faceHole(top: -0.34));
  c.drawPath(shape, _fill(k));
  c.save();
  c.clipPath(shape);
  for (var i = 0; i < 70; i++) {
    final a = random.nextDouble() * math.pi * 2;
    final r = 0.42 + random.nextDouble() * 0.42;
    c.drawArc(
        Rect.fromCircle(
            center: Offset(math.cos(a) * r, -0.08 + math.sin(a) * r),
            radius: 0.05),
        random.nextDouble() * 6,
        3.6,
        false,
        _line(i.isEven ? dark : light, 0.016));
  }
  c.restore();
}

void _spaceBuns(Canvas c, Color k) {
  _mirror(c, () {
    c.drawCircle(const Offset(-0.42, -0.72), 0.23, _fill(k));
    c.drawArc(Rect.fromCircle(center: const Offset(-0.42, -0.72), radius: 0.13),
        0.4, 4, false, _line(_lighter(k, 0.24), 0.02));
  });
  final outer = Path()
    ..moveTo(-0.5, 0.3)
    ..cubicTo(-0.6, -0.5, -0.4, -0.76, 0, -0.76)
    ..cubicTo(0.4, -0.76, 0.6, -0.5, 0.5, 0.3)
    ..lineTo(0.38, 0.3)
    ..lineTo(-0.38, 0.3)
    ..close();
  _hairShape(c, outer, k, strands: _fallStrands(0.3, spread: 0.5));
}

void _pigtails(Canvas c, Color k) {
  _mirror(c, () {
    c.drawPath(
        Path()
          ..moveTo(-0.46, -0.1)
          ..cubicTo(-0.95, -0.05, -0.9, 0.7, -0.66, 1.1)
          ..cubicTo(-0.56, 0.7, -0.5, 0.3, -0.42, 0.08)
          ..close(),
        _fill(k));
    c.drawCircle(const Offset(-0.48, -0.03), 0.055, _fill(_pink));
  });
  final outer = Path()
    ..moveTo(-0.5, 0.2)
    ..cubicTo(-0.6, -0.55, -0.36, -0.78, 0, -0.78)
    ..cubicTo(0.36, -0.78, 0.6, -0.55, 0.5, 0.2)
    ..close();
  _hairShape(c, outer, k, strands: _fallStrands(0.2, spread: 0.5));
}

void _quiff(Canvas c, Color k) {
  final outer = Path()
    ..moveTo(-0.46, 0.08)
    ..cubicTo(-0.56, -0.36, -0.44, -0.62, -0.18, -0.72)
    ..cubicTo(0.0, -1.02, 0.48, -1.0, 0.54, -0.62)
    ..cubicTo(0.56, -0.32, 0.52, -0.1, 0.46, 0.08)
    ..lineTo(0.38, 0.0)
    ..lineTo(-0.38, 0.0)
    ..close();
  _hairShape(c, outer, k, hole: _faceHole(top: -0.4), strands: [
    for (var i = 0; i < 8; i++)
      Path()
        ..moveTo(-0.4 + i * 0.1, -0.3)
        ..quadraticBezierTo(-0.2 + i * 0.1, -0.8, 0.1 + i * 0.07, -0.92),
  ]);
}

List<FaceFilter> _hair() {
  const black = Color(0xFF17131A);
  const brown = Color(0xFF4A2B1C);
  const blonde = Color(0xFFD8B26A);
  const copper = Color(0xFFB5562A);
  const pink = Color(0xFFF07CB4);
  const blue = Color(0xFF3F74D9);
  const silver = Color(0xFFC6C8D2);
  const lilac = Color(0xFFA986E8);
  const styles = <(String, void Function(Canvas, Color), List<(String, Color)>)>[
    ('Long', _longHair, [('Black', black), ('Blonde', blonde), ('Pink', pink)]),
    ('Curtain bangs', _curtainBangs,
        [('Brown', brown), ('Copper', copper), ('Lilac', lilac)]),
    ('Wolf cut', _wolfCut, [('Black', black), ('Silver', silver), ('Blue', blue)]),
    ('Bob', _bob, [('Black', black), ('Copper', copper), ('Pink', pink)]),
    ('Curls', _curls, [('Brown', brown), ('Blonde', blonde), ('Lilac', lilac)]),
    ('Space buns', _spaceBuns, [('Pink', pink), ('Blue', blue), ('Black', black)]),
    ('Pigtails', _pigtails, [('Blonde', blonde), ('Brown', brown), ('Lilac', lilac)]),
    ('Quiff', _quiff, [('Black', black), ('Silver', silver), ('Copper', copper)]),
  ];
  return [
    for (final (style, draw, shades) in styles)
      for (final (shade, colour) in shades)
        FaceFilter(
            'hair_${style.toLowerCase().replaceAll(' ', '_')}_${shade.toLowerCase()}',
            '$style $shade',
            'Hair',
            (c) => draw(c, colour)),
  ];
}

// ------------------------------------------------------------------- Hats

List<FaceFilter> _hats() {
  FaceFilter make(String name, void Function(Canvas) draw) => FaceFilter(
      'hat_${name.toLowerCase().replaceAll(' ', '_')}', name, 'Hats', draw);
  return [
    make('Crown', (c) {
      final p = Path()
        ..moveTo(-0.42, -0.42)
        ..lineTo(-0.5, -0.95)
        ..lineTo(-0.22, -0.68)
        ..lineTo(0, -1.05)
        ..lineTo(0.22, -0.68)
        ..lineTo(0.5, -0.95)
        ..lineTo(0.42, -0.42)
        ..close();
      c.drawPath(p, _fill(_gold));
      c.drawRect(const Rect.fromLTRB(-0.42, -0.52, 0.42, -0.42),
          _fill(_darker(_gold, 0.2)));
      c.drawCircle(const Offset(0, -0.47), 0.04, _fill(_pink));
      c.drawCircle(const Offset(-0.24, -0.47), 0.03, _fill(_blue));
      c.drawCircle(const Offset(0.24, -0.47), 0.03, _fill(_mint));
    }),
    make('Tiara', (c) {
      c.drawPath(
          Path()
            ..moveTo(-0.4, -0.36)
            ..quadraticBezierTo(0, -0.6, 0.4, -0.36),
          _line(const Color(0xFFE6E8F5), 0.03));
      for (final (x, h) in const [(-0.26, 0.11), (0.0, 0.2), (0.26, 0.11)]) {
        c.drawPath(_starPath(Offset(x, -0.5 - h / 2), h, points: 4, inner: 0.3),
            _fill(const Color(0xFFF2F4FF)));
      }
    }),
    make('Flower crown', (c) {
      for (var i = 0; i < 9; i++) {
        final a = math.pi + i * math.pi / 8;
        _flower(
            c,
            Offset(math.cos(a) * 0.5, -0.2 + math.sin(a) * 0.42),
            0.085,
            [_pink, _gold, _white, const Color(0xFFB98CF7)][i % 4]);
      }
    }),
    make('Cap', (c) {
      c.drawPath(
          Path()
            ..moveTo(-0.46, -0.36)
            ..cubicTo(-0.44, -0.95, 0.44, -0.95, 0.46, -0.36)
            ..close(),
          _fill(_blue));
      c.drawPath(
          Path()
            ..moveTo(-0.46, -0.38)
            ..quadraticBezierTo(0, -0.46, 0.46, -0.38)
            ..quadraticBezierTo(0.3, -0.18, 0, -0.2)
            ..quadraticBezierTo(-0.3, -0.18, -0.46, -0.38)
            ..close(),
          _fill(_darker(_blue, 0.3)));
    }),
    make('Beanie', (c) {
      c.drawPath(
          Path()
            ..moveTo(-0.46, -0.38)
            ..cubicTo(-0.46, -1.02, 0.46, -1.02, 0.46, -0.38)
            ..close(),
          _fill(_pink));
      for (var x = -0.36; x <= 0.36; x += 0.12) {
        c.drawLine(Offset(x, -0.48), Offset(x, -0.32),
            _line(_darker(_pink, 0.3), 0.016));
      }
      c.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.48, -0.48, 0.48, -0.3),
              const Radius.circular(0.05)),
          _fill(_darker(_pink, 0.12)));
    }),
    make('Cowboy', (c) {
      const brown = Color(0xFF7B4A25);
      c.drawPath(
          Path()
            ..moveTo(-0.84, -0.4)
            ..quadraticBezierTo(0, -0.22, 0.84, -0.4)
            ..quadraticBezierTo(0.45, -0.56, 0.32, -0.54)
            ..cubicTo(0.34, -1.08, 0.1, -0.98, 0, -0.92)
            ..cubicTo(-0.1, -0.98, -0.34, -1.08, -0.32, -0.54)
            ..quadraticBezierTo(-0.45, -0.56, -0.84, -0.4)
            ..close(),
          _fill(brown));
      c.drawLine(const Offset(-0.32, -0.5), const Offset(0.32, -0.5),
          _line(_darker(brown, 0.45), 0.05));
    }),
    make('Party', (c) {
      final p = Path()
        ..moveTo(-0.28, -0.42)
        ..lineTo(0.04, -1.2)
        ..lineTo(0.3, -0.46)
        ..close();
      c.drawPath(p, _fill(_purple));
      c.save();
      c.clipPath(p);
      for (var y = -1.2; y < -0.3; y += 0.18) {
        c.drawLine(Offset(-0.4, y), Offset(0.4, y + 0.1), _line(_gold, 0.04));
      }
      c.restore();
      c.drawCircle(const Offset(0.04, -1.22), 0.07, _fill(_pink));
    }),
    make('Santa', (c) {
      c.drawPath(
          Path()
            ..moveTo(-0.46, -0.4)
            ..cubicTo(-0.4, -1.1, 0.3, -1.15, 0.78, -0.72)
            ..quadraticBezierTo(0.5, -0.76, 0.46, -0.4)
            ..close(),
          _fill(const Color(0xFFD92B38)));
      c.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(-0.5, -0.52, 0.5, -0.32),
              const Radius.circular(0.1)),
          _fill(_white));
      c.drawCircle(const Offset(0.8, -0.68), 0.09, _fill(_white));
    }),
    make('Wizard', (c) {
      c.drawPath(
          Path()
            ..moveTo(-0.7, -0.38)
            ..quadraticBezierTo(0, -0.26, 0.7, -0.38)
            ..lineTo(0.34, -0.5)
            ..lineTo(0.16, -1.3)
            ..lineTo(-0.34, -0.5)
            ..close(),
          _fill(const Color(0xFF2D2470)));
      c.drawPath(_starPath(const Offset(0.02, -0.72), 0.09), _fill(_gold));
      c.drawPath(_starPath(const Offset(0.13, -0.97), 0.05), _fill(_gold));
    }),
    make('Beret', (c) {
      c.drawOval(const Rect.fromLTRB(-0.58, -0.9, 0.5, -0.4),
          _fill(const Color(0xFFC42C47)));
      c.drawLine(const Offset(-0.05, -0.9), const Offset(0, -1),
          _line(const Color(0xFFC42C47), 0.03));
    }),
    make('Halo', (c) {
      c.drawOval(const Rect.fromLTRB(-0.36, -1.02, 0.36, -0.82),
          _line(_gold, 0.05));
    }),
    make('Devil horns', (c) {
      _mirror(c, () {
        c.drawPath(
            Path()
              ..moveTo(-0.38, -0.5)
              ..quadraticBezierTo(-0.5, -0.8, -0.3, -1.02)
              ..quadraticBezierTo(-0.32, -0.76, -0.18, -0.58)
              ..close(),
            _fill(const Color(0xFFE02F3B)));
      });
    }),
  ];
}

void _flower(Canvas c, Offset o, double r, Color colour) {
  for (var i = 0; i < 5; i++) {
    final a = i * math.pi * 2 / 5;
    c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * r * 0.75, r * 0.6,
        _fill(colour));
  }
  c.drawCircle(o, r * 0.45,
      _fill(colour == _gold ? const Color(0xFFE2762B) : _gold));
}

// ---------------------------------------------------------------- Animals

void _nose(Canvas c, Color k, {double w = 0.12}) {
  c.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.3), width: w, height: w * 0.72),
      _fill(k));
}

void _whiskers(Canvas c, Color k) {
  final p = _line(k, 0.014);
  _mirror(c, () {
    for (final dy in const [-0.04, 0.03, 0.1]) {
      c.drawLine(const Offset(-0.1, 0.36), Offset(-0.46, 0.34 + dy * 1.6), p);
    }
  });
}

void _roundEars(Canvas c, Color k, Color inner, {double r = 0.2, double y = -0.56}) {
  _mirror(c, () {
    c.drawCircle(Offset(-0.38, y), r, _fill(k));
    c.drawCircle(Offset(-0.38, y), r * 0.56, _fill(inner));
  });
}

void _pointEars(Canvas c, Color k, Color inner) {
  _mirror(c, () {
    c.drawPath(
        Path()
          ..moveTo(-0.46, -0.3)
          ..lineTo(-0.48, -0.86)
          ..lineTo(-0.12, -0.52)
          ..close(),
        _fill(k));
    c.drawPath(
        Path()
          ..moveTo(-0.41, -0.4)
          ..lineTo(-0.43, -0.72)
          ..lineTo(-0.22, -0.52)
          ..close(),
        _fill(inner));
  });
}

List<FaceFilter> _animals() {
  FaceFilter make(String name, void Function(Canvas) draw) => FaceFilter(
      'animal_${name.toLowerCase().replaceAll(' ', '_')}', name, 'Animals', draw);
  const brown = Color(0xFF8A5A3C);
  const soft = Color(0xFFF2B9C4);
  const orange = Color(0xFFE8782A);
  return [
    make('Puppy', (c) {
      _mirror(c, () {
        c.drawPath(
            Path()
              ..moveTo(-0.3, -0.5)
              ..cubicTo(-0.75, -0.6, -0.78, 0.0, -0.58, 0.2)
              ..cubicTo(-0.46, 0.08, -0.42, -0.2, -0.3, -0.5)
              ..close(),
            _fill(brown));
      });
      _nose(c, _black, w: 0.16);
      c.drawPath(
          Path()
            ..moveTo(-0.08, 0.5)
            ..quadraticBezierTo(0, 0.86, 0.08, 0.5)
            ..close(),
          _fill(_pink));
    }),
    make('Cat', (c) {
      _pointEars(c, const Color(0xFF5B5B66), soft);
      _nose(c, _pink, w: 0.08);
      _whiskers(c, _black);
    }),
    make('Bunny', (c) {
      _mirror(c, () {
        c.drawOval(const Rect.fromLTRB(-0.42, -1.3, -0.14, -0.42), _fill(_white));
        c.drawOval(const Rect.fromLTRB(-0.35, -1.2, -0.21, -0.54), _fill(soft));
      });
      _nose(c, _pink, w: 0.09);
      c.drawRect(const Rect.fromLTWH(-0.05, 0.56, 0.1, 0.11), _fill(_white));
      _whiskers(c, _darker(soft, 0.3));
    }),
    make('Bear', (c) {
      _roundEars(c, brown, soft);
      c.drawOval(const Rect.fromLTRB(-0.17, 0.2, 0.17, 0.46),
          _fill(_lighter(brown, 0.5)));
      _nose(c, _black, w: 0.1);
    }),
    make('Fox', (c) {
      _pointEars(c, orange, _white);
      c.drawPath(
          Path()
            ..moveTo(-0.36, 0.24)
            ..quadraticBezierTo(0, 0.2, 0.36, 0.24)
            ..quadraticBezierTo(0.12, 0.5, 0, 0.6)
            ..quadraticBezierTo(-0.12, 0.5, -0.36, 0.24)
            ..close(),
          _fill(_white.withValues(alpha: 0.75)));
      _nose(c, _black, w: 0.09);
    }),
    make('Panda', (c) {
      _roundEars(c, _black, _black);
      _mirror(c, () {
        c.drawOval(
            Rect.fromCenter(
                center: const Offset(-0.22, 0.03), width: 0.26, height: 0.3),
            _fill(_black.withValues(alpha: 0.82)));
      });
      _nose(c, _black, w: 0.1);
    }),
    make('Deer', (c) {
      const horn = Color(0xFF9B6C3F);
      _mirror(c, () {
        final p = _line(horn, 0.04);
        c.drawLine(const Offset(-0.26, -0.56), const Offset(-0.4, -1.1), p);
        c.drawLine(const Offset(-0.33, -0.82), const Offset(-0.56, -0.94), p);
        c.drawLine(const Offset(-0.37, -1.0), const Offset(-0.2, -1.14), p);
        for (final o in const [Offset(-0.26, 0.18), Offset(-0.16, 0.26), Offset(-0.3, 0.3)]) {
          c.drawCircle(o, 0.018, _fill(_white));
        }
      });
      _nose(c, _black, w: 0.1);
    }),
    make('Tiger', (c) {
      _roundEars(c, orange, _white, r: 0.16);
      final s = _line(_black, 0.03);
      _mirror(c, () {
        c.drawLine(const Offset(-0.4, 0.2), const Offset(-0.26, 0.24), s);
        c.drawLine(const Offset(-0.4, 0.36), const Offset(-0.26, 0.36), s);
        c.drawLine(const Offset(-0.34, -0.26), const Offset(-0.24, -0.16), s);
      });
      c.drawLine(const Offset(0, -0.34), const Offset(0, -0.2), s);
      _nose(c, _pink, w: 0.09);
    }),
    make('Mouse', (c) {
      _roundEars(c, const Color(0xFF9C9CA8), soft, r: 0.26, y: -0.5);
      _nose(c, _pink, w: 0.07);
      _whiskers(c, _black);
    }),
    make('Frog', (c) {
      const green = Color(0xFF4DB84A);
      _mirror(c, () {
        c.drawCircle(const Offset(-0.25, -0.5), 0.17, _fill(green));
        c.drawCircle(const Offset(-0.25, -0.5), 0.1, _fill(_white));
        c.drawCircle(const Offset(-0.25, -0.5), 0.05, _fill(_black));
      });
      _mirror(c, () {
        c.drawCircle(const Offset(-0.3, 0.36), 0.05, _fill(soft));
      });
    }),
    make('Unicorn', (c) {
      final horn = Path()
        ..moveTo(-0.1, -0.48)
        ..lineTo(0, -1.08)
        ..lineTo(0.1, -0.48)
        ..close();
      c.drawPath(horn, _fill(_gold));
      c.save();
      c.clipPath(horn);
      for (var y = -1.1; y < -0.4; y += 0.11) {
        c.drawLine(Offset(-0.2, y + 0.08), Offset(0.2, y), _line(_white, 0.022));
      }
      c.restore();
      _flower(c, const Offset(-0.26, -0.5), 0.08, _pink);
      _flower(c, const Offset(0.26, -0.5), 0.08, const Color(0xFFB98CF7));
    }),
    make('Koala', (c) {
      const grey = Color(0xFF9AA0AC);
      _roundEars(c, grey, _white, r: 0.27, y: -0.42);
      c.drawOval(const Rect.fromLTRB(-0.09, 0.14, 0.09, 0.42), _fill(_black));
    }),
  ];
}

// ----------------------------------------------------------------- Makeup

void _blush(Canvas c, Color k) {
  _mirror(c, () {
    c.drawOval(
        Rect.fromCenter(center: const Offset(-0.28, 0.3), width: 0.24, height: 0.13),
        _fill(k.withValues(alpha: 0.42)));
  });
}

void _lips(Canvas c, Color k) {
  c.drawPath(
      Path()
        ..moveTo(-0.13, 0.52)
        ..quadraticBezierTo(-0.05, 0.45, 0, 0.48)
        ..quadraticBezierTo(0.05, 0.45, 0.13, 0.52)
        ..quadraticBezierTo(0, 0.63, -0.13, 0.52)
        ..close(),
      _fill(k.withValues(alpha: 0.82)));
}

void _liner(Canvas c, Color k) {
  _mirror(c, () {
    c.drawPath(
        Path()
          ..moveTo(-0.11, 0.02)
          ..quadraticBezierTo(-0.24, -0.06, -0.35, -0.01)
          ..lineTo(-0.42, -0.08),
        _line(k, 0.022));
  });
}

List<FaceFilter> _makeup() {
  FaceFilter make(String name, void Function(Canvas) draw) => FaceFilter(
      'makeup_${name.toLowerCase().replaceAll(' ', '_')}', name, 'Makeup', draw);
  const rose = Color(0xFFE85C7F);
  const peach = Color(0xFFF29A6B);
  const red = Color(0xFFD51F36);
  return [
    make('Rosy blush', (c) => _blush(c, rose)),
    make('Peach blush', (c) => _blush(c, peach)),
    make('Red lips', (c) => _lips(c, red)),
    make('Berry lips', (c) => _lips(c, const Color(0xFF8E1F52))),
    make('Winged liner', (c) => _liner(c, _black)),
    make('Pink liner', (c) => _liner(c, _pink)),
    make('Soft glam', (c) {
      _blush(c, rose);
      _lips(c, rose);
      _liner(c, _black);
    }),
    make('Freckles', (c) {
      final r = math.Random(11);
      for (var i = 0; i < 34; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        c.drawCircle(
            Offset(side * (0.07 + r.nextDouble() * 0.28),
                0.14 + r.nextDouble() * 0.15),
            0.008,
            _fill(const Color(0xBB6A3B23)));
      }
    }),
    make('Cheek hearts', (c) {
      _mirror(c, () => c.drawPath(_heartPath(const Offset(-0.28, 0.3), 0.05), _fill(_pink)));
    }),
    make('Cheek stars', (c) {
      _mirror(c, () => c.drawPath(_starPath(const Offset(-0.28, 0.3), 0.065), _fill(_gold)));
    }),
    make('Tears', (c) {
      _mirror(c, () {
        for (final (y, s) in const [(0.16, 0.035), (0.29, 0.03)]) {
          c.drawPath(
              Path()
                ..moveTo(-0.23, y - s * 1.3)
                ..quadraticBezierTo(-0.23 - s, y, -0.23, y + s)
                ..quadraticBezierTo(-0.23 + s, y, -0.23, y - s * 1.3)
                ..close(),
              _fill(const Color(0xCC6FC4FF)));
        }
      });
    }),
    make('Face gems', (c) {
      _mirror(c, () {
        for (final (x, y, r) in const [
          (-0.37, -0.05, 0.022),
          (-0.33, 0.06, 0.018),
          (-0.28, 0.14, 0.014),
          (-0.2, 0.18, 0.012),
        ]) {
          c.drawPath(_starPath(Offset(x, y), r * 1.5, points: 4, inner: 0.4),
              _fill(const Color(0xFFD9E8FF)));
        }
      });
    }),
  ];
}

// ---------------------------------------------------------------- Sparkle

void _butterfly(Canvas c, Offset o, double s, Color k) {
  c.save();
  c.translate(o.dx, o.dy);
  c.scale(s);
  _mirror(c, () {
    c.drawOval(const Rect.fromLTRB(-1.0, -0.8, -0.05, 0.1), _fill(k));
    c.drawOval(const Rect.fromLTRB(-0.7, 0, -0.05, 0.7), _fill(_lighter(k)));
  });
  c.drawOval(const Rect.fromLTRB(-0.07, -0.55, 0.07, 0.6), _fill(_black));
  c.restore();
}

List<FaceFilter> _sparkle() {
  FaceFilter make(String name, void Function(Canvas) draw) => FaceFilter(
      'sparkle_${name.toLowerCase().replaceAll(' ', '_')}', name, 'Sparkle', draw);
  List<Offset> ring(int seed, int n) {
    final r = math.Random(seed);
    return [
      for (var i = 0; i < n; i++)
        () {
          final a = math.pi * (0.85 + 1.3 * i / (n - 1).clamp(1, n));
          final d = 0.72 + r.nextDouble() * 0.3;
          return Offset(math.cos(a) * d, 0.1 + math.sin(a) * d);
        }(),
    ];
  }

  return [
    make('Hearts', (c) {
      final colours = [_pink, const Color(0xFFFF7FA3), const Color(0xFFE02F3B)];
      var i = 0;
      for (final o in ring(1, 8)) {
        c.drawPath(_heartPath(o, 0.06 + (i % 3) * 0.022), _fill(colours[i % 3]));
        i++;
      }
    }),
    make('Stars', (c) {
      var i = 0;
      for (final o in ring(2, 9)) {
        c.drawPath(_starPath(o, 0.05 + (i % 3) * 0.022), _fill(_gold));
        i++;
      }
    }),
    make('Glitter', (c) {
      var i = 0;
      for (final o in ring(3, 14)) {
        c.drawPath(_starPath(o, 0.03 + (i % 4) * 0.018, points: 4, inner: 0.25),
            _fill(i.isEven ? _white : const Color(0xFFCBB5FF)));
        i++;
      }
    }),
    make('Butterflies', (c) {
      _butterfly(c, const Offset(-0.52, -0.5), 0.13, _blue);
      _butterfly(c, const Offset(0.46, -0.66), 0.1, _purple);
      _butterfly(c, const Offset(0.62, -0.12), 0.08, _pink);
      _butterfly(c, const Offset(-0.1, -0.86), 0.07, _mint);
    }),
    make('Blossoms', (c) {
      var i = 0;
      for (final o in ring(5, 8)) {
        _flower(c, o, 0.06 + (i % 2) * 0.02, i.isEven ? _pink : _white);
        i++;
      }
    }),
    make('Fire', (c) {
      void flame(double x, double h, Color k) {
        c.drawPath(
            Path()
              ..moveTo(x - 0.13, -0.42)
              ..cubicTo(x - 0.2, -0.42 - h * 0.45, x - 0.02, -0.42 - h * 0.6, x,
                  -0.42 - h)
              ..cubicTo(x + 0.05, -0.42 - h * 0.6, x + 0.2, -0.42 - h * 0.45,
                  x + 0.13, -0.42)
              ..close(),
            _fill(k));
      }

      for (var i = 0; i < 7; i++) {
        final x = -0.42 + i * 0.14;
        flame(x, 0.34 + (i.isEven ? 0.2 : 0.06), const Color(0xFFF2531B));
        flame(x, 0.2 + (i.isEven ? 0.1 : 0.03), _gold);
      }
    }),
    make('Rainbow', (c) {
      const bands = [
        Color(0xFFE02F3B),
        Color(0xFFF2891B),
        Color(0xFFF5C344),
        Color(0xFF4DB84A),
        Color(0xFF4073FC),
        Color(0xFF9B3BF5),
      ];
      for (var i = 0; i < bands.length; i++) {
        final r = 0.98 - i * 0.055;
        c.drawArc(
            Rect.fromCircle(center: const Offset(0, -0.05), radius: r),
            math.pi,
            math.pi,
            false,
            _line(bands[i], 0.05)..strokeCap = StrokeCap.butt);
      }
    }),
    make('Snow', (c) {
      final r = math.Random(8);
      for (var i = 0; i < 26; i++) {
        c.drawCircle(
            Offset(-1.1 + r.nextDouble() * 2.2, -1.4 + r.nextDouble() * 1.1),
            0.012 + r.nextDouble() * 0.024,
            _fill(_white.withValues(alpha: 0.9)));
      }
    }),
    make('Bubbles', (c) {
      final r = math.Random(9);
      for (final o in ring(9, 10)) {
        final size = 0.04 + r.nextDouble() * 0.07;
        c.drawCircle(o, size, _line(const Color(0xCCBFE7FF), 0.012));
        c.drawCircle(o + Offset(-size * 0.35, -size * 0.35), size * 0.14,
            _fill(_white));
      }
    }),
    make('Clouds', (c) {
      void cloud(Offset o, double s) {
        for (final (x, y, r) in const [
          (-0.5, 0.05, 0.32),
          (0.0, -0.08, 0.44),
          (0.5, 0.05, 0.32),
        ]) {
          c.drawCircle(o + Offset(x, y) * s, r * s, _fill(_white));
        }
      }

      cloud(const Offset(-0.5, -0.8), 0.32);
      cloud(const Offset(0.5, -0.92), 0.26);
      cloud(const Offset(0, -1.14), 0.2);
    }),
  ];
}
