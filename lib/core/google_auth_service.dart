import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// "Sign in with Google" for login — separate from GoogleContentService's
/// "connect my Google account" (that one requests offline
/// youtube.readonly/drive.readonly access for the source picker; this one
/// only needs an identity to hand to Supabase Auth). A distinct GoogleSignIn
/// instance keeps the two from fighting over scopes/serverClientId.
///
/// kGoogleSignInWebClientId is a public identifier (same non-secret status
/// as kAgoraAppId) — it must be one of the Client IDs registered in
/// Supabase's dashboard under Authentication > Providers > Google, so the
/// ID token's audience matches what Supabase expects to verify.
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

  /// Runs the native Google sign-in UI, hands the resulting ID token to
  /// Supabase Auth, and returns the Supabase session's access token —
  /// ready for AuthProvider.loginWithSupabaseAccessToken. Returns null if
  /// the user cancelled the picker.
  static Future<String?> signInAndGetAccessToken() async {
    final account = await _signIn().signIn();
    if (account == null) return null;
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in did not return an ID token.');
    }
    final response = await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
    final accessToken = response.session?.accessToken;
    if (accessToken == null) {
      throw StateError('Supabase did not return a session for this sign-in.');
    }
    return accessToken;
  }
}
