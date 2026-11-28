import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/insync_icons.dart';

/// The insync brand (brand pack, Nov 2026): the vibe bars (white, red,
/// red, red, white) and the "insync" wordmark ("in" white, "sync" red, with
/// a red live dot). Red #E8112D, white, black #0B0B0B.
class InsyncBrand {
  InsyncBrand._();

  static const red = Color(0xFFE8112D);
  // Kept names, now inside the brand's red / white / black.
  static const violet = Color(0xFFFF3B52);
  static const pink = Color(0xFFE8112D);
  static const orange = Color(0xFFB00D22);
  static const ink = Color(0xFF0B0B0B);
  static const night = Color(0xFF0B0B0B);
  static const muted = Color(0xFFFFFFFF);

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

/// Paints the vibe bars on a 100-unit grid, as in the brand pack:
/// x, top, height of each bar; the outer two white, the middle three red.
/// [phase] 0..1 makes them move like a sound meter (the loader); null
/// draws them still. [color] paints all five in one colour.
class _BarsPainter extends CustomPainter {
  final double? phase;
  final Color? color;
  // 1 = full bounce, 0 = still (the reveal settles from 1 to 0).
  final double amount;
  const _BarsPainter({this.phase, this.color, this.amount = 1});

  static const _bars = [
    (21.5, 38.0, 24.0),
    (33.5, 28.0, 44.0),
    (45.5, 19.0, 62.0),
    (57.5, 28.0, 44.0),
    (69.5, 38.0, 24.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    for (var i = 0; i < _bars.length; i++) {
      final (x, top, h) = _bars[i];
      var height = h;
      if (phase != null) {
        // Each bar bounces a little out of step with the next.
        final w = math.sin((phase! * 2 + i * 0.22) * math.pi).abs();
        height = h * (1 - amount * 0.55 * (1 - w));
      }
      final mid = top + h / 2;
      final paint = Paint()
        ..color = color ??
            (i == 0 || i == _bars.length - 1 ? Colors.white : InsyncBrand.red);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, mid - height / 2, 9, height),
              const Radius.circular(4.5)),
          paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.phase != phase || old.color != color || old.amount != amount;
}

/// The vibe bars, still. [color] null draws them in brand red and white.
class InsyncSymbol extends StatelessWidget {
  final double size;
  final Color? color;
  const InsyncSymbol({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Insync',
        image: true,
        child: CustomPaint(
            size: Size.square(size), painter: _BarsPainter(color: color)),
      );
}

/// The brand loader: the vibe bars moving like a sound meter. Use anywhere
/// something is loading.
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _BarsPainter(phase: _c.value, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// "insync": the brand wordmark ("in" white, "sync" red, live dot), from
/// the brand pack. [size] is about the letter height of the old text one.
/// [inColor] dark draws the version for light backgrounds.
class InsyncWordmarkText extends StatelessWidget {
  final double size;
  final Color inColor;
  const InsyncWordmarkText(
      {super.key, this.size = 20, this.inColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    final onLight = inColor.computeLuminance() < 0.4;
    // Cropped to the letters (live dot to the tail of the y).
    return Semantics(
      label: 'Insync',
      excludeSemantics: true,
      child: Image.asset(
        onLight
            ? 'assets/brand/wordmark-light.png'
            : 'assets/brand/wordmark-dark.png',
        height: size * 1.25,
        filterQuality: FilterQuality.medium,
      ),
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
    return SizedBox(
      width: width,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // The lockup's square artwork has its content in the middle 80%;
        // the empty top and bottom are trimmed so the logo centres right.
        ClipRect(
          child: Align(
            heightFactor: 0.8,
            child: SvgPicture.asset('assets/brand/lockup-dark.svg',
                width: width, semanticsLabel: 'Insync'),
          ),
        ),
        if (tagline) ...[
          SizedBox(height: width * 0.04),
          // Shrinks to fit instead of being cut off.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('PLAY \u00b7 WATCH \u00b7 LISTEN \u00b7 CONNECT',
                maxLines: 1,
                style: _poppins(
                    fontSize: width * 0.052,
                    fontWeight: FontWeight.w500,
                    letterSpacing: width * 0.012,
                    color: InsyncBrand.muted)),
          ),
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

/// The logo reveal: the vibe bars bounce like a sound meter and settle,
/// then "insync" with the live dot fades up underneath. Drawn, not a video,
/// so it starts on the first frame and is sharp on any screen. The bars sit
/// exactly where the system launch screen draws them ([size] square,
/// centred), so the launch screen flows straight into it.
class InsyncLogoReveal extends StatefulWidget {
  final double size;
  final VoidCallback? onDone;
  const InsyncLogoReveal({super.key, this.size = 144, this.onDone});

  @override
  State<InsyncLogoReveal> createState() => _InsyncLogoRevealState();
}

class _InsyncLogoRevealState extends State<InsyncLogoReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      label: 'Insync',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size * 1.3,
        height: size * 1.6,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Bars: bounce for the first half, fading to still.
            final bounce = t < 0.55 ? 1 - t / 0.55 : 0.0;
            final phase = bounce > 0 ? (t * 3.2) % 1.0 : null;
            // Wordmark: fades and rises in from 45% to 80%.
            final w = ((t - 0.45) / 0.35).clamp(0.0, 1.0);
            final word = Curves.easeOut.transform(w);
            return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Bars: centred in the square, like the launch screen.
                  Positioned(
                    left: size * 0.15,
                    top: (size * 1.6 - size) / 2,
                    width: size,
                    height: size,
                    child: CustomPaint(
                      painter: _BarsPainter(phase: phase, amount: bounce),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (size * 1.6 - size) / 2 +
                        size * 0.86 +
                        (1 - word) * size * 0.08,
                    child: Opacity(
                      opacity: word,
                      child:
                          Center(child: InsyncWordmarkText(size: size * 0.2)),
                    ),
                  ),
                ]);
          },
        ),
      ),
    );
  }
}

/// The start-up screen: the logo reveal on brand black, then [onDone].
class InsyncSplash extends StatelessWidget {
  final VoidCallback? onDone;
  const InsyncSplash({super.key, this.onDone});

  /// Matches the bars on the system launch screen (288 dp icon, bars
  /// scaled to half: a 144 dp square).
  static const barsSize = 144.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: InsyncBrand.night,
      child: Center(
        child: InsyncLogoReveal(size: barsSize, onDone: onDone),
      ),
    );
  }
}

/// Buffering: a soft white light sweeping along the video's bottom line,
/// again and again, until it plays. Covers nothing.
class BufferingSweep extends StatefulWidget {
  final double height;
  const BufferingSweep({super.key, this.height = 3});

  @override
  State<BufferingSweep> createState() => _BufferingSweepState();
}

class _BufferingSweepState extends State<BufferingSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Buffering',
        child: SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final w = box.maxWidth * 0.4;
                return ClipRect(
                  child: Stack(children: [
                    Positioned(
                      left: -w + (box.maxWidth + w) * _c.value,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0x00FFFFFF),
                            Color(0xEEFFFFFF),
                            Color(0x00FFFFFF),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ),
      );
}
