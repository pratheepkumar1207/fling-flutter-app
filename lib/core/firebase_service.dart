import 'package:firebase_core/firebase_core.dart';

/// Mirrors firebaseConfigured in the web app's src/lib/firebase.js — true
/// once native Firebase config (google-services.json / GoogleService-Info.plist)
/// is present for the running platform, false otherwise so the login screen
/// can fall back to dev-login instead of crashing.
bool firebaseConfigured = false;

Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp();
    firebaseConfigured = true;
  } catch (_) {
    firebaseConfigured = false;
  }
}
