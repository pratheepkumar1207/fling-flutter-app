import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Sign in with Apple, through Firebase (the server's /auth/firebase takes
/// the Firebase ID token, the same as Google and phone sign-in). Apple's
/// rules: any app offering Google sign-in on iPhone must offer this too.
class AppleAuthService {
  AppleAuthService._();

  static bool get available => !kIsWeb && Platform.isIOS;

  /// The Firebase ID token, or null if the person cancelled.
  static Future<String?> signInAndGetFirebaseIdToken() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    try {
      final result = await FirebaseAuth.instance.signInWithProvider(provider);
      return await result.user?.getIdToken();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' || e.code == 'web-context-canceled') {
        return null;
      }
      rethrow;
    }
  }
}
