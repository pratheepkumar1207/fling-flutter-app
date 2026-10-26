import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The Insync logo assembling itself from its parts — heads drop in, the
/// loop fades in left to right, chat bubble, controller and play button pop,
/// the wordmark wipes in and the tagline rises. The last frame is the
/// original logo exactly (the layers stack back into it).
class AnimatedLogo extends StatefulWidget {
  final double width;
  final VoidCallback? onDone;
  const AnimatedLogo({super.key, this.width = 250, this.onDone});

  static const total = Duration(milliseconds: 3700);

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AnimatedLogo.total)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone?.call();
        });

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final n in _layers) {
      precacheImage(AssetImage('assets/logo/$n.png'), context);
    }
  }

  static const _layers = [
    'loop',
    'head_left',
    'head_right',
    'bubble',
    'pad',
    'play',
    'word',
    'tag'
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progress 0..1 of a segment that runs from [startMs] for [lenMs].
  double _seg(int startMs, int lenMs, [Curve curve = Curves.linear]) {
    final ms = _c.value * AnimatedLogo.total.inMilliseconds;
    final t = ((ms - startMs) / lenMs).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  Widget _layer(String name) =>
      Image.asset('assets/logo/$name.png', fit: BoxFit.fill);

  Widget _pop(String name, int start, Alignment origin) {
    final t = _seg(start, 420, Curves.easeOutBack);
    return Opacity(
      opacity: _seg(start, 200),
      child: Transform.scale(
          scale: 0.3 + 0.7 * t, alignment: origin, child: _layer(name)),
    );
  }

  Widget _drop(String name, int start, double dx) {
    final t = _seg(start, 550, Curves.easeOutBack);
    return Opacity(
      opacity: _seg(start, 250),
      child: Transform.translate(
        offset: Offset(dx * (1 - t), -40 * (1 - t)),
        child: Transform.scale(
            scale: 0.5 + 0.5 * t,
            alignment: const Alignment(0, -0.85),
            child: _layer(name)),
      ),
    );
  }

  /// Soft-edged reveal that sweeps across in [dir].
  Widget _wipe(
      Widget child, double p, Alignment from, Alignment to, double feather) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        begin: from,
        end: to,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, (p - feather).clamp(0.0, 1.0), p.clamp(0.0, 1.0)],
      ).createShader(r),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Layer canvas is 868×983 px.
    final w = widget.width;
    final h = w * 983 / 868;
    return Semantics(
        label: 'Insync',
        image: true,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final loopP = _seg(600, 900, Curves.easeInOutCubic) * 1.35;
            final wordP = _seg(1850, 600, Curves.easeInOutCubic) * 1.2;
            final pulse = _seg(2700, 1000);
            final pulseK =
                1 + 0.03 * (pulse < 0.5 ? pulse * 2 : (1 - pulse) * 2);
            return Transform.scale(
              scale: pulseK,
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(fit: StackFit.expand, children: [
                  Transform.scale(
                      scale: 0.94 + 0.06 * _seg(600, 900, Curves.easeOutCubic),
                      child: _wipe(
                          _layer('loop'),
                          loopP,
                          const Alignment(-1, -0.2),
                          const Alignment(1, 0.2),
                          0.3)),
                  _drop('head_left', 200, -14),
                  _drop('head_right', 350, 14),
                  _pop('bubble', 1300, const Alignment(-0.58, -0.12)),
                  _pop('pad', 1420, const Alignment(0.74, -0.1)),
                  _pop('play', 1600, const Alignment(0.02, -0.14)),
                  _wipe(_layer('word'), wordP, Alignment.centerLeft,
                      Alignment.centerRight, 0.15),
                  Opacity(
                    opacity: _seg(2300, 450),
                    child: Transform.translate(
                        offset: Offset(
                            0, 8 * (1 - _seg(2300, 450, Curves.easeOut))),
                        child: _layer('tag')),
                  ),
                ]),
              ),
            );
          },
        ));
  }
}

/// Thin gradient loading bar under the splash logo.
class SplashLoadingBar extends StatefulWidget {
  const SplashLoadingBar({super.key});

  @override
  State<SplashLoadingBar> createState() => _SplashLoadingBarState();
}

class _SplashLoadingBarState extends State<SplashLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 120,
        height: 4,
        child: ColoredBox(
          color: AppColors.border,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: Curves.easeInOut.transform(_c.value),
              child: const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: AppGradients.brand))),
            ),
          ),
        ),
      ),
    );
  }
}
