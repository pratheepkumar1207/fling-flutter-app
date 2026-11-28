import 'dart:math' as math;
import '../../widgets/insync_brand.dart';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../settings/legal_screen.dart';

/// The sign-in page when Google is the only way in: the splash logo with
/// icons floating around it, the headline and one button.
class GoogleSignInView extends StatelessWidget {
  final bool loading;
  final String error;
  final VoidCallback onGoogle;
  final Widget googleMark;

  /// iPhone: Sign in with Apple, shown first (Apple's rule).
  final VoidCallback? onApple;

  const GoogleSignInView({
    super.key,
    required this.loading,
    required this.error,
    required this.onGoogle,
    required this.googleMark,
    this.onApple,
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
      const _Glow(Alignment(0, -0.35), Color(0x66E8112D)),
      const _Glow(Alignment(0.9, -0.9), Color(0x33E8112D)),
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
                        const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
              ],
              if (onApple != null) ...[
                AppleSignInButton(onPressed: loading ? null : onApple),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                onPressed: loading ? null : onGoogle,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF000000),
                    // While signing in the button is disabled: keep
                    // "Signing in…" readable (it was white on white).
                    disabledForegroundColor: const Color(0xFF000000)),
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
        child: Center(
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, child) => Transform.translate(
                offset: Offset(0, math.sin(_clock.value * 2 * math.pi * 6) * 6),
                child: child),
            child: const InsyncLogoReveal(size: 170),
          ),
        ),
      ),
    );
  }
}

/// Apple's standard black "Sign in with Apple" button.
class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const AppleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            backgroundColor: Colors.black,
            disabledBackgroundColor: Colors.black54,
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white)),
        icon: const Icon(Icons.apple, size: 22),
        label: const Text('Sign in with Apple'),
      );
}
