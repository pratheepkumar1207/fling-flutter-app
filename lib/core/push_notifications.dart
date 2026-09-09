import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';
import 'app_navigator.dart';

enum PushRequestResult { granted, denied, error }

/// Notification deep links — a tapped push should restore the relevant
/// PartySession where one exists, not just open the app to its default
/// screen (spec requirement; previously not implemented at all — see
/// app_navigator.dart's handleNotificationTap for what actually resolves
/// the payload). Covers both real tap scenarios FCM distinguishes:
/// `onMessageOpenedApp` fires when the app was merely backgrounded and the
/// user taps the notification; `getInitialMessage()` covers the app having
/// been fully killed and cold-started BY that same tap. Call once from
/// main() before runApp() — see main.dart.
Future<void> setupNotificationTapHandling() async {
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    handleNotificationTap(message.data);
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage == null) return;
  // This early in a cold start, runApp() may not have drawn a first frame
  // yet — navigatorKey.currentState is null until it has. Deferring to
  // the post-frame callback guarantees the Navigator actually exists by
  // the time this fires, however soon or late that turns out to be.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    handleNotificationTap(initialMessage.data);
  });
}

/// Requests notification permission and registers the resulting FCM token
/// with the backend (POST /auth/fcm-token) — mirrors src/lib/firebase.js's
/// requestWebPushToken on the web app. Called when the user flips on
/// Settings' "Notifications" toggle.
Future<PushRequestResult> requestPushPermissionAndRegister() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return PushRequestResult.denied;

    final token = await messaging.getToken();
    if (token == null) return PushRequestResult.error;
    await ApiClient.post('/auth/fcm-token', body: {'fcmToken': token});
    return PushRequestResult.granted;
  } catch (_) {
    return PushRequestResult.error;
  }
}
