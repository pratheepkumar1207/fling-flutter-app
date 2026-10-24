import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// "Sign in with Google" for login — separate from GoogleContentService's
/// "connect my Google account" (that one requests offline
/// youtube.readonly/drive.readonly access for the source picker; this one
/// only needs an identity). A distinct GoogleSignIn instance keeps the two
/// from fighting over scopes/serverClientId.
///
/// Goes through Firebase Auth — the same Firebase project (fling-8a7ba)
/// phone login uses — so the backend verifies both kinds of login the same
/// way (POST /auth/firebase). kGoogleSignInWebClientId is that project's
/// public web client id (client_type 3 in google-services.json), not a
/// secret.
const String kGoogleSignInWebClientId =
    '409464876557-jiuv41mqj3e2mg4rqb0kovk5nj1ttt1j.apps.googleusercontent.com';

class GoogleAuthService {
  static GoogleSignIn? _googleSignIn;

  static GoogleSignIn _signIn() {
    return _googleSignIn ??=
        GoogleSignIn(serverClientId: kGoogleSignInWebClientId, scopes: const [
      'email',
    ]);
  }

  /// Runs the native Google sign-in UI, signs into Firebase with it, and
  /// returns the Firebase ID token — ready for
  /// AuthProvider.loginWithFirebaseIdToken. Returns null if the user
  /// cancelled the picker.
  static Future<String?> signInAndGetFirebaseIdToken() async {
    final account = await _signIn().signIn();
    if (account == null) return null;
    final googleAuth = await account.authentication;
    if (googleAuth.idToken == null) {
      throw StateError('Google sign-in did not return an ID token.');
    }
    final result = await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      ),
    );
    final idToken = await result.user?.getIdToken();
    if (idToken == null) {
      throw StateError('Firebase did not return a session for this sign-in.');
    }
    return idToken;
  }

  /// Also signs out of Google, so the next sign-in shows the account
  /// picker again instead of silently reusing the last account.
  static Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
