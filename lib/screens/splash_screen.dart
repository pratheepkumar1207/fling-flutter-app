import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../core/avatar_frame_cache.dart';
import '../core/app_navigator.dart';
import '../core/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_logo.dart';
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
  // The logo intro plays once per launch, then the splash steps aside as
  // soon as auth has resolved.
  static bool _introPlayed = false;
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
    LocationService.requestPermissionAndPing(prompt: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!_introPlayed) {
          return _SplashScaffold(
              onIntroDone: () => setState(() => _introPlayed = true));
        }
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
            // A notification can wake a terminated app before its JWT has
            // been restored. Flush the queued room link only after AppShell
            // is in the Navigator tree, otherwise PartyScreen would attempt
            // its initial room request unauthenticated.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              openPendingPartyNotification();
            });
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

/// Black ground, soft purple glow, the animated logo and a gradient
/// loading bar — the approved splash design.
class _SplashScaffold extends StatelessWidget {
  final VoidCallback? onIntroDone;
  const _SplashScaffold({this.onIntroDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.12),
                  radius: 0.9,
                  colors: [Color(0xFF2A1240), AppColors.bg],
                  stops: [0, 0.62],
                ),
              ),
            ),
          ),
          Center(
            child: onIntroDone != null
                ? AnimatedLogo(width: 250, onDone: onIntroDone)
                : Image.asset('assets/icon/insync-logo.png', width: 250),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 70,
            child: Center(child: SplashLoadingBar()),
          ),
        ],
      ),
    );
  }
}
