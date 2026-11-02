import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';
import '../settings/legal_screen.dart';

/// The sign-in page when Google is the only way in: the splash logo with
/// icons floating around it, the headline and one button.
class GoogleSignInView extends StatelessWidget {
  final bool loading;
  final String error;
  final VoidCallback onGoogle;
  final Widget googleMark;

  const GoogleSignInView({
    super.key,
    required this.loading,
    required this.error,
    required this.onGoogle,
    required this.googleMark,
  });

  void _openLegal(BuildContext context, String kind) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => kind == 'terms'
              ? const LegalScreen(
                  title: 'Terms of Service', sections: kTermsOfServiceSections)
              : const LegalScreen(
                  title: 'Privacy Policy', sections: kPrivacyPolicySections)));

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const _Glow(Alignment(0.7, -0.88), Color(0xFF5A1B44)),
      const _Glow(Alignment(-0.92, -0.12), Color(0xFF1A2A66)),
      const _Glow(Alignment(0.5, 0.56), Color(0xFF34165C)),
      SafeArea(
        child: Column(children: [
          const Expanded(child: _FloatingLogo()),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Your people.\nYour kind of moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 27,
                      height: 1.14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8)),
              const SizedBox(height: 8),
              const Text(
                  'Watch together, talk, play games and meet new people.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textDim, fontSize: 14, height: 1.45)),
              const SizedBox(height: 20),
              if (error.isNotEmpty) ...[
                Text(error,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 13)),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: loading ? null : onGoogle,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white70,
                    foregroundColor: const Color(0xFF121016)),
                icon: googleMark,
                label: Text(loading ? 'Signing in…' : 'Continue with Google'),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('By continuing you agree to our ',
                      style:
                          TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  _Link('Terms', () => _openLegal(context, 'terms')),
                  const Text(' and ',
                      style:
                          TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  _Link('Privacy Policy', () => _openLegal(context, 'privacy')),
                ],
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _Glow extends StatelessWidget {
  final Alignment center;
  final Color color;
  const _Glow(this.center, this.color);

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
              center: center,
              radius: 0.8,
              colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Link(this.text, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.lilac,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.lilac)),
        ),
      );
}

/// Laid out on a fixed canvas and scaled to fit, so the icons keep clear of
/// the logo on any phone.
class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo();

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: 308,
        height: 390,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 76,
            top: 100,
            width: 156,
            child: Image.asset('assets/icon/insync-logo.png',
                semanticLabel: 'Insync'),
          ),
          for (final icon in _icons)
            Positioned(
              left: icon.left,
              top: icon.top,
              width: icon.size,
              height: icon.size,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, child) {
                    // Whole cycles per clock turn, so the loop has no jump.
                    final wave = math.sin(2 *
                        math.pi *
                        (_clock.value * icon.cycles + icon.phase));
                    return Transform.translate(
                      offset: Offset(0, wave * 8),
                      child: Transform.rotate(
                          angle: (icon.turn + wave * 3) * math.pi / 180,
                          child: child),
                    );
                  },
                  child: SvgPicture.string(icon.svg),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _FloatingIcon {
  final double left, top, size, turn, phase;
  final int cycles;
  final String svg;
  const _FloatingIcon(this.left, this.top, this.size, this.turn, this.cycles,
      this.phase, this.svg);
}

String _svg(String defs, String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
    'viewBox="0 0 100 100"><defs>$defs</defs>$body</svg>';

String _ramp(String id, List<String> stops,
    {String x2 = '1', String y2 = '1'}) {
  final parts = [
    for (var i = 0; i < stops.length; i++)
      '<stop offset="${i / (stops.length - 1)}" stop-color="${stops[i]}"/>'
  ].join();
  return '<linearGradient id="$id" x1="0" y1="0" x2="$x2" y2="$y2">$parts</linearGradient>';
}

// A glossy ring in the logo's colours, with a symbol inside.
String _orb(String symbol) => _svg(
    '${_ramp('rim', ['#FF7A93', '#9B3BF5', '#4073FC'])}'
        '<radialGradient id="core" cx="0.4" cy="0.3" r="0.85">'
        '<stop offset="0" stop-color="#3B2069"/>'
        '<stop offset="1" stop-color="#120B24"/></radialGradient>'
        '${_ramp('sym', ['#FFFFFF', '#E2C6FF'], x2: '0')}',
    '<circle cx="50" cy="50" r="47" fill="url(#rim)"/>'
        '<circle cx="50" cy="50" r="38" fill="url(#core)"/>$symbol'
        '<path d="M22 34a32 32 0 0 1 30-20" fill="none" stroke="#fff" '
        'stroke-opacity="0.55" stroke-width="5" stroke-linecap="round"/>');

final _icons = <_FloatingIcon>[
  // Mic
  _FloatingIcon(
      8,
      24,
      88,
      -8,
      6,
      0,
      _orb(
          '<rect x="40" y="25" width="20" height="33" rx="10" fill="url(#sym)"/>'
          '<path d="M32 48a18 18 0 0 0 36 0M50 66v8M39 75h22" fill="none" '
          'stroke="#fff" stroke-width="5" stroke-linecap="round"/>')),
  // Play
  _FloatingIcon(
      214,
      12,
      80,
      8,
      5,
      0.2,
      _orb('<path d="M41 33 69 50 41 67Z" fill="url(#sym)" stroke="#F4E9FF" '
          'stroke-width="6" stroke-linejoin="round"/>')),
  // Heart
  _FloatingIcon(
      124,
      10,
      56,
      8,
      7,
      0.45,
      _svg(
          _ramp('hot', ['#FF8FA5', '#FB3F65', '#B3124A'], x2: '0'),
          '<path d="M50 88C20 66 8 50 8 33 8 18 20 9 33 9c7 0 13 3 17 10 4-7 10-10 17-10 13 0 25 9 25 24 0 17-12 33-42 55z" fill="url(#hot)"/>'
          '<ellipse cx="30" cy="30" rx="11" ry="8" fill="#fff" fill-opacity="0.6" transform="rotate(-30 30 30)"/>')),
  // Dice
  _FloatingIcon(
      246,
      184,
      54,
      14,
      5,
      0.1,
      _svg(
          _ramp('dice', ['#FFFFFF', '#CDB5F2']),
          '<rect x="14" y="14" width="72" height="72" rx="18" fill="url(#dice)" stroke="#9B3BF5" stroke-width="3"/>'
          '<g fill="#FB3F65"><circle cx="34" cy="34" r="7"/><circle cx="66" cy="34" r="7"/>'
          '<circle cx="50" cy="50" r="7"/><circle cx="34" cy="66" r="7"/><circle cx="66" cy="66" r="7"/></g>')),
  // Chat
  _FloatingIcon(
      2,
      164,
      62,
      -6,
      5,
      0.3,
      _svg(
          _ramp('cool', ['#6E9BFF', '#6A1FB0']),
          '<path d="M18 16h64a11 11 0 0 1 11 11v37a11 11 0 0 1-11 11H46L26 92V75h-8A11 11 0 0 1 7 64V27a11 11 0 0 1 11-11z" fill="url(#cool)"/>'
          '<circle cx="32" cy="46" r="6" fill="#fff"/><circle cx="50" cy="46" r="6" fill="#fff"/><circle cx="68" cy="46" r="6" fill="#fff"/>'
          '<path d="M18 30a8 8 0 0 1 8-7h22" fill="none" stroke="#fff" stroke-opacity="0.5" stroke-width="4" stroke-linecap="round"/>')),
  // Game controller
  _FloatingIcon(
      22,
      300,
      78,
      -8,
      6,
      0.6,
      _orb(
          '<path d="M35 37h30c8 0 12 6 14 16 2 11-7 16-12 9l-5-7H38l-5 7c-5 7-14 2-12-9 2-10 6-16 14-16z" fill="url(#sym)"/>'
          '<path d="M38 42v10M33 47h10" stroke="#6A1FB0" stroke-width="3.5" stroke-linecap="round"/>'
          '<circle cx="60" cy="44" r="3" fill="#FB3F65"/><circle cx="66" cy="50" r="3" fill="#4073FC"/>')),
  // Diamond
  _FloatingIcon(
      134,
      318,
      44,
      6,
      7,
      0.05,
      _svg(
          _ramp('ice', ['#C9F1FF', '#7AD7FF', '#4073FC']),
          '<path d="M28 14h44l22 26-44 50L6 40z" fill="url(#ice)"/>'
          '<path d="M6 40h88M28 14l12 26 10 50 10-50 12-26M40 40l10-26 10 26" fill="none" stroke="#fff" stroke-opacity="0.6" stroke-width="2.5" stroke-linejoin="round"/>')),
  // Music note
  _FloatingIcon(
      216,
      290,
      72,
      8,
      4,
      0.75,
      _orb(
          '<path d="M43 62V32l24-6v30" fill="none" stroke="#F4E9FF" stroke-width="5" stroke-linejoin="round"/>'
          '<ellipse cx="36" cy="63" rx="8" ry="6.5" fill="#fff"/><ellipse cx="60" cy="57" rx="8" ry="6.5" fill="#fff"/>')),
  // Flame
  _FloatingIcon(
      258,
      112,
      38,
      10,
      7,
      0.35,
      _svg(
          _ramp('fire', ['#FFC93C', '#FF6A3C', '#FB3F65'], x2: '0'),
          '<path d="M52 6c6 20 30 30 30 56a32 32 0 0 1-64 0c0-14 7-23 14-30 2 9 6 13 11 13 2-15-2-27 9-39z" fill="url(#fire)"/>'
          '<path d="M51 50c3 9 14 13 14 25a15 15 0 0 1-30 0c0-10 11-14 16-25z" fill="#FFE9A8"/>')),
];
