import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';

/// "Connect Google account" for the Rave-style YouTube/Drive source picker
/// (see source_picker_screen.dart) — separate from firebase_auth's phone
/// login. Requests offline access + these two scopes so the backend can
/// keep browsing on our behalf without the user present (see POST
/// /auth/google/connect and src/config/googleOAuth.js).
///
/// kGoogleOAuthWebClientId is a public identifier (same non-secret status
/// as kAgoraAppId in voice_chat_controller.dart) — the actual secret is
/// GOOGLE_OAUTH_CLIENT_SECRET, which stays server-side only. Same Web
/// application OAuth Client ID as google_auth_service.dart's
/// kGoogleSignInWebClientId (SAME Google Cloud project, "fling final") —
/// requires the youtube.readonly and drive.readonly scopes added on that
/// project's OAuth consent screen (Data Access), which plain sign-in
/// doesn't need. isConfigured stays false, and this feature stays a dead
/// end for the user, until that scope setup is done and the backend's
/// GOOGLE_OAUTH_CLIENT_ID/SECRET env vars are set to match.
const String kGoogleOAuthWebClientId =
    '409464876557-jiuv41mqj3e2mg4rqb0kovk5nj1ttt1j.apps.googleusercontent.com';

class GoogleContentService {
  GoogleContentService._();
  static final instance = GoogleContentService._();

  static bool get isConfigured => kGoogleOAuthWebClientId.isNotEmpty;

  GoogleSignIn? _googleSignIn;

  GoogleSignIn _signIn() {
    return _googleSignIn ??= GoogleSignIn(
      scopes: const [
        'https://www.googleapis.com/auth/youtube.readonly',
        'https://www.googleapis.com/auth/drive.readonly',
      ],
      serverClientId: kGoogleOAuthWebClientId,
    );
  }

  /// Runs the native Google sign-in UI, then hands the resulting
  /// serverAuthCode to the backend to exchange for a stored refresh token.
  /// Returns the granted scopes, or throws on cancel/failure.
  Future<List<String>> connect() async {
    if (!isConfigured) {
      throw StateError(
          'Google sign-in is not configured yet (kGoogleOAuthWebClientId is empty).');
    }
    final account = await _signIn().signIn();
    if (account == null) throw StateError('Sign-in was cancelled.');
    final serverAuthCode = account.serverAuthCode;
    if (serverAuthCode == null) {
      throw StateError(
          'No serverAuthCode returned — check the Web Client ID matches the backend\'s GOOGLE_OAUTH_CLIENT_ID.');
    }
    final result = await ApiClient.post('/auth/google/connect',
        body: {'serverAuthCode': serverAuthCode}) as Map<String, dynamic>;
    return List<String>.from(result['scopes'] as List? ?? []);
  }

  Future<Map<String, dynamic>> status() async {
    return await ApiClient.get('/auth/google/status') as Map<String, dynamic>;
  }

  Future<void> disconnect() async {
    await ApiClient.delete('/auth/google');
    await _googleSignIn?.signOut();
  }
}
