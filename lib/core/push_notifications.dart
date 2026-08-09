import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';

enum PushRequestResult { granted, denied, error }

/// Requests notification permission and registers the resulting FCM token
/// with the backend (POST /auth/fcm-token) — mirrors src/lib/firebase.js's
/// requestWebPushToken on the web app. Called from SafetyGuidelinesScreen's
/// "Turn on notifications" button.
Future<PushRequestResult> requestPushPermissionAndRegister() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
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
