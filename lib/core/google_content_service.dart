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
/// GOOGLE_OAUTH_CLIENT_SECRET, which stays server-side only. This must be
/// the "Web application" OAuth Client ID from the SAME Google Cloud
/// project the backend's GOOGLE_OAUTH_CLIENT_ID/SECRET use, created in
/// Cloud Console with the YouTube Data API v3 and Google Drive API
/// enabled — see the setup note in googleOAuth.js. Left blank until that's
/// done; every entry point below checks isConfigured first instead of
/// crashing on an empty client id.
const String kGoogleOAuthWebClientId = '';

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
      throw StateError('Google sign-in is not configured yet (kGoogleOAuthWebClientId is empty).');
    }
    final account = await _signIn().signIn();
    if (account == null) throw StateError('Sign-in was cancelled.');
    final serverAuthCode = account.serverAuthCode;
    if (serverAuthCode == null) {
      throw StateError('No serverAuthCode returned — check the Web Client ID matches the backend\'s GOOGLE_OAUTH_CLIENT_ID.');
    }
    final result = await ApiClient.post('/auth/google/connect', body: {'serverAuthCode': serverAuthCode}) as Map<String, dynamic>;
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
