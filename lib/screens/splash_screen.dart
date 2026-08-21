import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../core/avatar_frame_cache.dart';
import '../core/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/spinner.dart';
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
            return const Scaffold(
              backgroundColor: AppColors.bg,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Fling',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 24),
                    Spinner(),
                  ],
                ),
              ),
            );
          case AuthStatus.anon:
            if (_hasSeenOnboarding == null) {
              return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: Spinner()));
            }
            return _hasSeenOnboarding! ? const LoginScreen() : const OnboardingScreen();
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
            if (auth.user != null && auth.user!.profileComplete && auth.user!.safetyGuidelinesSeenAt == null) {
              return const SafetyGuidelinesScreen();
            }
            _pingLocationIfOptedIn(auth);
            if (!_frameCacheLoaded) {
              _frameCacheLoaded = true;
              AvatarFrameCache.load(); // fire-and-forget; a cache miss just renders without a frame
            }
            return const AppShell();
        }
      },
    );
  }
}
