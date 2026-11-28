import 'package:flutter/material.dart';
import '../widgets/insync_brand.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../core/avatar_frame_cache.dart';
import '../core/app_navigator.dart';
import '../core/location_service.dart';
import 'auth/complete_profile_screen.dart';
import 'auth/intro_video_screen.dart';
import 'auth/login_screen.dart';
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
  // First time only, before signing in: the 16 s features intro video.
  // Signed out: the intro video plays once per app opening. Signed in:
  // never.
  static bool _introVideoPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
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
        if (!_introPlayed) {
          return _SplashScaffold(
              onIntroDone: () => setState(() => _introPlayed = true));
        }
        switch (auth.status) {
          case AuthStatus.loading:
            return const _SplashScaffold();
          case AuthStatus.anon:
            // Signed out: the intro video, then straight to sign-in (the
            // old "Get started" page repeated both).
            if (!_introVideoPlayed) {
              return IntroVideoScreen(
                  onDone: () => setState(() => _introVideoPlayed = true));
            }
            return const LoginScreen();
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

/// Start-up on the sign-in design: the logo reveal on the brand backdrop.
/// While signing in takes longer (the server waking up), the same logo,
/// still, with a small loader under it.
class _SplashScaffold extends StatelessWidget {
  final VoidCallback? onIntroDone;
  const _SplashScaffold({this.onIntroDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InsyncBrand.night,
      body: onIntroDone != null
          ? InsyncSplash(onDone: onIntroDone)
          : Stack(fit: StackFit.expand, children: [
              const BrandBackdrop(),
              const Center(
                  child: InsyncLogoReveal(
                      size: InsyncSplash.barsSize, animate: false)),
              Align(
                alignment: const Alignment(0, 0.6),
                child: InsyncSpinner(size: 28, showPlay: false),
              ),
            ]),
    );
  }
}
