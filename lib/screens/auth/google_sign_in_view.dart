import '../../widgets/insync_brand.dart';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../settings/legal_screen.dart';

/// The sign-in page when Google is the only way in. It is the start-up
/// screen carried on: same backdrop, same logo in the middle; the logo then
/// rises and the headline and buttons come in below.
class GoogleSignInView extends StatefulWidget {
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

  @override
  State<GoogleSignInView> createState() => _GoogleSignInViewState();
}

class _GoogleSignInViewState extends State<GoogleSignInView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _openLegal(BuildContext context, String kind) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => kind == 'terms'
              ? const LegalScreen(
                  title: 'Terms of Service', sections: kTermsOfServiceSections)
              : const LegalScreen(
                  title: 'Privacy Policy', sections: kPrivacyPolicySections)));

  @override
  Widget build(BuildContext context) {
    final loading = widget.loading;
    final error = widget.error;
    return Stack(fit: StackFit.expand, children: [
      const BrandBackdrop(),
      // The logo: from the middle (where start-up left it) up to its place.
      AnimatedBuilder(
        animation: _enter,
        builder: (context, child) {
          final e = Curves.easeInOutCubic.transform(_enter.value);
          return Align(
            alignment:
                Alignment.lerp(Alignment.center, const Alignment(0, -0.45), e)!,
            child: Transform.scale(scale: 1 + 0.12 * e, child: child),
          );
        },
        child:
            const InsyncLogoReveal(size: InsyncSplash.barsSize, animate: false),
      ),
      SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _enter,
            builder: (context, child) {
              final d = Curves.easeOut
                  .transform(((_enter.value - 0.35) / 0.65).clamp(0.0, 1.0));
              return Opacity(
                opacity: d,
                child: Transform.translate(
                    offset: Offset(0, (1 - d) * 40), child: child),
              );
            },
            child: Padding(
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
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                if (widget.onApple != null) ...[
                  AppleSignInButton(onPressed: loading ? null : widget.onApple),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  onPressed: loading ? null : widget.onGoogle,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF000000),
                      // While signing in the button is disabled: keep
                      // "Signing in…" readable (it was white on white).
                      disabledForegroundColor: const Color(0xFF000000)),
                  icon: widget.googleMark,
                  label: Text(loading ? 'Signing in…' : 'Continue with Google'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('By continuing you agree to our ',
                        style: TextStyle(
                            color: AppColors.textFaint, fontSize: 12)),
                    _Link('Terms', () => _openLegal(context, 'terms')),
                    const Text(' and ',
                        style: TextStyle(
                            color: AppColors.textFaint, fontSize: 12)),
                    _Link(
                        'Privacy Policy', () => _openLegal(context, 'privacy')),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
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
