import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_messenger.dart';
import 'core/app_navigator.dart';
import 'core/auth_provider.dart';
import 'core/background_audio_handler.dart';
import 'core/firebase_service.dart';
import 'core/push_notifications.dart';
import 'core/socket_service.dart';
import 'core/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  // Only used for "Sign in with Google" (see google_auth_service.dart) —
  // phone login still goes through Firebase directly.
  await initSupabase();
  // Ready before any room needs it — see background_audio_handler.dart.
  backgroundAudioHandler = await AudioService.init(
    builder: () => BackgroundAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.fling.app.channel.audio',
      androidNotificationChannelName: 'Room playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  // Not awaited — restoring a notification-tapped PartySession shouldn't
  // delay the app's own startup; both listeners it registers stay valid
  // however long the actual setup takes to complete.
  unawaited(setupNotificationTapHandling());
  runApp(const FlingApp());
}

class FlingApp extends StatelessWidget {
  const FlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SocketService()),
      ],
      // Single fixed dark theme — no light-mode toggle. Most of the app
      // (room screens, Home, the glass chrome) hardcodes the dark
      // AppColors palette in its body regardless of theme, so letting
      // ambient chrome (AppBars etc.) switch to light independently used
      // to produce a light bar over a dark body — worst case reading as a
      // blank white screen. One theme, always installed, removes that
      // whole class of mismatch.
      child: MaterialApp(
        title: 'Insync',
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
