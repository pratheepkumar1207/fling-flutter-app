import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../core/avatar_frame_cache.dart';
import '../core/location_service.dart';
import '../theme/app_colors.dart';
import 'auth/complete_profile_screen.dart';
import 'auth/login_screen.dart';
import 'auth/onboarding_screen.dart';
import 'auth/safety_guidelines_screen.dart';
import 'shell/app_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _locationPinged = false;
  bool _frameCacheLoaded = false;
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
    OnboardingScreen.hasSeenOnboarding().then((seen) {
      if (mounted) setState(() => _hasSeenOnboarding = seen);
    });
  }

  // "Location update on app opens" — only for users who already opted into
  // locationSharingEnabled in a previous session, so this never triggers a
  // permission prompt for anyone who hasn't. Fire-and-forget: a failure
  // here shouldn't block getting into the app.
  void _pingLocationIfOptedIn(AuthProvider auth) {
    if (_locationPinged) return;
    if (auth.user?.locationSharingEnabled != true) return;
    _locationPinged = true;
    LocationService.requestPermissionAndPing();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.loading:
            return const _SplashScaffold();
          case AuthStatus.anon:
            if (_hasSeenOnboarding == null) {
              return const _SplashScaffold();
            }
            return _hasSeenOnboarding!
                ? const LoginScreen()
                : const OnboardingScreen();
          case AuthStatus.authed:
            // New (or not-yet-finished) accounts must fill in "looking
            // for", interests, and a real gallery before anything else —
            // see CompleteProfileScreen and profileComplete in
            // GET/PATCH /auth/me.
            if (auth.user != null && !auth.user!.profileComplete) {
              return const CompleteProfileScreen();
            }
            // One-time safety/notifications screen, shown right after
            // profile completion — see SafetyGuidelinesScreen and
            // POST /auth/safety-seen.
            if (auth.user != null &&
                auth.user!.profileComplete &&
                auth.user!.safetyGuidelinesSeenAt == null) {
              return const SafetyGuidelinesScreen();
            }
            _pingLocationIfOptedIn(auth);
            if (!_frameCacheLoaded) {
              _frameCacheLoaded = true;
              AvatarFrameCache
                  .load(); // fire-and-forget; a cache miss just renders without a frame
            }
            return const AppShell();
        }
      },
    );
  }
}

/// Matches SplashDark.dc.html: two soft blurred glows, the brand glass
/// icon, "Fling" in the display font, tagline, and a spinning ring.
class _SplashScaffold extends StatelessWidget {
  const _SplashScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(
            top: 120,
            left: -40,
            child: _glow(220, AppColors.accent2.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: 140,
            right: -30,
            child: _glow(180, AppColors.primary.withValues(alpha: 0.35)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(colors: AppGradients.brand),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.accent2.withValues(alpha: 0.55),
                          blurRadius: 30,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 42),
                ),
                const SizedBox(height: 22),
                Text('Fling',
                    style: GoogleFonts.bricolageGrotesque(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                        letterSpacing: -0.3)),
                const SizedBox(height: 6),
                const Text('Watch, talk, play — together',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.textFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
