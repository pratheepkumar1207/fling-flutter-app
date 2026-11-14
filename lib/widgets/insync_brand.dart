import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/insync_icons.dart';

/// The insync brand (brand guide 1.0): the symbol — two sync arrows around
/// a play button — the wordmark ("in" solid, "sync" in the gradient), and
/// the loaders built from them.
class InsyncBrand {
  InsyncBrand._();

  static const violet = Color(0xFF6A2CFF);
  static const pink = Color(0xFFE5179B);
  static const orange = Color(0xFFFF8A1F);
  static const ink = Color(0xFF17112B);
  static const night = Color(0xFF0E0A1C);
  static const muted = Color(0xFF8F86AE);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, pink, orange],
    stops: [0, 0.55, 1],
  );
}

// Poppins (the brand font) in the app; the platform font in widget tests,
// which can't download fonts.
final bool _inTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

TextStyle _poppins(
    {double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color}) {
  final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color);
  return _inTest ? base : GoogleFonts.poppins(textStyle: base);
}

/// Paints the symbol on a 200-unit grid. [spin] turns the arrows (0..1 is a
/// full turn); [beat] scales the play button.
class _SymbolPainter extends CustomPainter {
  final double spin;
  final double beat;
  final Color? color;
  final bool showPlay;
  const _SymbolPainter(
      {this.spin = 0, this.beat = 1, this.color, this.showPlay = true});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 200;
    canvas.save();
    canvas.translate((size.width - 200 * s) / 2, (size.height - 200 * s) / 2);
    canvas.scale(s);
    final shader = color == null
        ? InsyncBrand.gradient
            .createShader(const Rect.fromLTRB(20, 20, 180, 180))
        : null;
    Paint stroke(double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color ?? Colors.white
      ..shader = shader;
    Paint fill() => Paint()
      ..style = PaintingStyle.fill
      ..color = color ?? Colors.white
      ..shader = shader;

    // Arrows, turned around the centre.
    canvas.save();
    canvas.translate(100, 100);
    canvas.rotate(spin * 2 * math.pi);
    canvas.translate(-100, -100);
    const rect = Rect.fromLTRB(32, 32, 168, 168);
    double rad(double d) => d * math.pi / 180;
    canvas.drawArc(rect, rad(200), rad(130), false, stroke(15));
    canvas.drawArc(rect, rad(20), rad(130), false, stroke(15));
    Path tri(List<Offset> p) => Path()
      ..moveTo(p[0].dx, p[0].dy)
      ..lineTo(p[1].dx, p[1].dy)
      ..lineTo(p[2].dx, p[2].dy)
      ..close();
    for (final head in [
      tri(const [Offset(146.8, 73), Offset(171, 59), Offset(167.9, 81.6)]),
      tri(const [Offset(53.2, 127), Offset(29, 141), Offset(32.1, 118.4)]),
    ]) {
      canvas.drawPath(head, fill());
      canvas.drawPath(head, stroke(6));
    }
    canvas.restore();

    if (showPlay) {
      canvas.save();
      canvas.translate(108, 100);
      canvas.scale(beat);
      canvas.translate(-108, -100);
      final play =
          tri(const [Offset(87, 75), Offset(87, 125), Offset(130, 100)]);
      canvas.drawPath(play, fill());
      canvas.drawPath(play, stroke(11));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) =>
      old.spin != spin ||
      old.beat != beat ||
      old.color != color ||
      old.showPlay != showPlay;
}

/// The symbol, still. [color] null draws it in the brand gradient.
class InsyncSymbol extends StatelessWidget {
  final double size;
  final Color? color;
  const InsyncSymbol({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Insync',
        image: true,
        child: CustomPaint(
            size: Size.square(size), painter: _SymbolPainter(color: color)),
      );
}

/// The brand loader: the arrows turn once and rest (the "sync" beat) while
/// the play button pulses. Use anywhere something is loading.
class InsyncSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final bool showPlay;
  final Duration period;
  const InsyncSpinner(
      {super.key,
      this.size = 28,
      this.color,
      this.showPlay = true,
      this.period = const Duration(milliseconds: 1600)});

  @override
  State<InsyncSpinner> createState() => _InsyncSpinnerState();
}

class _InsyncSpinnerState extends State<InsyncSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _beat(double t) {
    if (t < 0.6) return 1;
    if (t < 0.75) return 1 - 0.18 * ((t - 0.6) / 0.15);
    if (t < 0.88) return 0.82 + 0.26 * ((t - 0.75) / 0.13);
    return 1.08 - 0.08 * ((t - 0.88) / 0.12);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final spin = _c.value < 0.7
                ? Curves.easeInOut.transform(_c.value / 0.7)
                : 1.0;
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _SymbolPainter(
                  spin: spin,
                  beat: _beat(_c.value),
                  color: widget.color,
                  showPlay: widget.showPlay),
            );
          },
        ),
      ),
    );
  }
}

/// "insync": "in" in solid ink (white on dark), "sync" in the gradient.
class InsyncWordmarkText extends StatelessWidget {
  final double size;
  final Color inColor;
  const InsyncWordmarkText(
      {super.key, this.size = 20, this.inColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    final style = _poppins(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -size * 0.025,
        height: 1);
    return Semantics(
      label: 'Insync',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('in', style: style.copyWith(color: inColor)),
        ShaderMask(
          shaderCallback: (r) => InsyncBrand.gradient.createShader(r),
          blendMode: BlendMode.srcIn,
          child: Text('sync', style: style.copyWith(color: Colors.white)),
        ),
      ]),
    );
  }
}

/// The stacked logo: symbol, wordmark and (optionally) the tagline.
class InsyncLogo extends StatelessWidget {
  final double width;
  final bool tagline;
  const InsyncLogo({super.key, this.width = 200, this.tagline = true});

  @override
  Widget build(BuildContext context) {
    // Large system text shrinks the words to fit rather than overflowing.
    return SizedBox(
      width: width,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InsyncSymbol(size: width * 0.36),
        SizedBox(height: width * 0.05),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: InsyncWordmarkText(size: width * 0.24)),
        if (tagline) ...[
          SizedBox(height: width * 0.05),
          Text('PLAY · WATCH · LISTEN · CONNECT',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: _poppins(
                  fontSize: width * 0.052,
                  fontWeight: FontWeight.w500,
                  letterSpacing: width * 0.016,
                  color: InsyncBrand.muted)),
        ],
      ]),
    );
  }
}

/// Three gradient dots bouncing in turn: chat typing / sending.
class InsyncDots extends StatefulWidget {
  final double size;
  const InsyncDots({super.key, this.size = 10});

  @override
  State<InsyncDots> createState() => _InsyncDotsState();
}

class _InsyncDotsState extends State<InsyncDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Typing',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) _dot((_c.value - i * 0.15) % 1),
          ]),
        ),
      );

  Widget _dot(double t) {
    final up = t < 0.3
        ? t / 0.3
        : t < 0.6
            ? 1 - (t - 0.3) / 0.3
            : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.size * 0.33),
      child: Transform.translate(
        offset: Offset(0, -up * widget.size),
        child: Opacity(
          opacity: 0.6 + 0.4 * up,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, gradient: InsyncBrand.gradient),
          ),
        ),
      ),
    );
  }
}

/// Five gradient bars bouncing: music and voice rooms loading.
class InsyncEqualizer extends StatefulWidget {
  final double height;
  const InsyncEqualizer({super.key, this.height = 32});

  @override
  State<InsyncEqualizer> createState() => _InsyncEqualizerState();
}

class _InsyncEqualizerState extends State<InsyncEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();
  static const _delays = [0.2, 0.5, 0.1, 0.7, 0.35];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading audio',
        child: SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in _delays)
                  Container(
                    width: widget.height * 0.18,
                    height: widget.height *
                        (0.2 +
                            0.8 *
                                (0.5 -
                                    0.5 *
                                        math.cos(2 *
                                            math.pi *
                                            ((_c.value + d) % 1)))),
                    margin:
                        EdgeInsets.symmetric(horizontal: widget.height * 0.06),
                    decoration: BoxDecoration(
                        gradient: InsyncBrand.gradient,
                        borderRadius: BorderRadius.circular(4)),
                  ),
              ],
            ),
          ),
        ),
      );
}

/// A gradient heart beating twice: finding matches.
class InsyncHeartbeat extends StatefulWidget {
  final double size;
  const InsyncHeartbeat({super.key, this.size = 48});

  @override
  State<InsyncHeartbeat> createState() => _InsyncHeartbeatState();
}

class _InsyncHeartbeatState extends State<InsyncHeartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _scale(double t) {
    const keys = [
      [0.0, 1.0],
      [0.15, 1.18],
      [0.30, 0.96],
      [0.45, 1.12],
      [0.60, 1.0],
      [1.0, 1.0],
    ];
    for (var i = 1; i < keys.length; i++) {
      if (t <= keys[i][0]) {
        final a = keys[i - 1], b = keys[i];
        final f = (t - a[0]) / (b[0] - a[0]);
        return a[1] + (b[1] - a[1]) * Curves.easeInOut.transform(f);
      }
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Finding matches',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) =>
              Transform.scale(scale: _scale(_c.value), child: child),
          child: ShaderMask(
            shaderCallback: (r) => InsyncBrand.gradient.createShader(r),
            blendMode: BlendMode.srcIn,
            child: InIcon(InIcons.heart,
                size: widget.size, color: Colors.white, filled: true),
          ),
        ),
      );
}

/// The shimmering placeholder used while posts, reels and lists load.
class InsyncShimmer extends StatefulWidget {
  final Widget child;
  const InsyncShimmer({super.key, required this.child});

  @override
  State<InsyncShimmer> createState() => _InsyncShimmerState();
}

class _InsyncShimmerState extends State<InsyncShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment(-1 - 2 + 4 * _c.value, 0),
            end: Alignment(1 - 2 + 4 * _c.value, 0),
            colors: const [
              Color(0xFF241A44),
              Color(0xFF3A2A66),
              Color(0xFF241A44)
            ],
            stops: const [0, 0.5, 1],
          ).createShader(r),
          child: child,
        ),
        child: widget.child,
      );
}

/// The start-up screen: glowing orbit with the features circling the
/// turning symbol, the wordmark, tagline and a gradient progress bar with
/// what's loading. Calls [onDone] once the bar is full (about 2.4 s).
class InsyncSplash extends StatefulWidget {
  final VoidCallback? onDone;
  const InsyncSplash({super.key, this.onDone});

  @override
  State<InsyncSplash> createState() => _InsyncSplashState();
}

class _InsyncSplashState extends State<InsyncSplash>
    with TickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();
  late final AnimationController _breathe = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);
  late final AnimationController _progress = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    })
    ..forward();

  static const _steps = [
    (0.0, 'Starting up…'),
    (0.15, 'Warming up games…'),
    (0.32, 'Syncing your chats…'),
    (0.48, 'Loading reels & posts…'),
    (0.64, 'Tuning voice rooms…'),
    (0.80, 'Finding new matches…'),
    (0.94, 'Almost in sync…'),
  ];

  static const _features = [
    InIcons.game,
    InIcons.tv,
    InIcons.mic,
    InIcons.chat,
    InIcons.reels,
    InIcons.video,
    InIcons.heart,
  ];

  @override
  void dispose() {
    _loop.dispose();
    _breathe.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.9,
          colors: [Color(0xFF2A1150), Color(0xFF170D2E), InsyncBrand.night],
          stops: [0, 0.35, 0.7],
        ),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: Listenable.merge([_loop, _breathe]),
              builder: (context, _) {
                final b = _breathe.value;
                return Stack(alignment: Alignment.center, children: [
                  // Glow
                  Transform.scale(
                    scale: 0.95 + 0.1 * b,
                    child: Opacity(
                      opacity: 0.6 + 0.4 * b,
                      child: Container(
                        width: 270,
                        height: 270,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Color(0x666A2CFF),
                            Color(0x22E5179B),
                            Color(0x00000000)
                          ], stops: [
                            0,
                            0.45,
                            0.7
                          ]),
                        ),
                      ),
                    ),
                  ),
                  // Features circling the symbol
                  for (var i = 0; i < _features.length; i++)
                    Builder(builder: (context) {
                      final a = -math.pi / 2 +
                          i * 2 * math.pi / _features.length +
                          _loop.value * 2 * math.pi;
                      return Transform.translate(
                        offset: Offset(110 * math.cos(a), 110 * math.sin(a)),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: InsyncBrand.gradient,
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0x55E5179B), blurRadius: 16)
                            ],
                          ),
                          child: Center(
                              child: InIcon(_features[i],
                                  size: 18, color: Colors.white)),
                        ),
                      );
                    }),
                  const InsyncSpinner(size: 120),
                ]);
              },
            ),
          ),
          const SizedBox(height: 24),
          const InsyncWordmarkText(size: 42),
          const SizedBox(height: 8),
          Text('PLAY · WATCH · LISTEN · CONNECT',
              style: _poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3.5,
                  color: InsyncBrand.muted)),
          const SizedBox(height: 28),
          SizedBox(
            width: 260,
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                final v = Curves.easeOut.transform(_progress.value);
                final msg = _progress.isCompleted
                    ? 'Ready!'
                    : _steps.lastWhere((s) => v >= s.$1).$2;
                return Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 6,
                      color: const Color(0x14FFFFFF),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                            InsyncBrand.violet,
                            InsyncBrand.pink,
                            InsyncBrand.orange
                          ], stops: [
                            0,
                            0.55,
                            1
                          ])),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: Text(msg,
                          style:
                              _poppins(fontSize: 13, color: InsyncBrand.muted)),
                    ),
                    Text('${(v * 100).round()}%',
                        style: _poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE9E4F7))),
                  ]),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
