import 'package:supabase_flutter/supabase_flutter.dart';

/// Used only to reach Supabase Auth for "Sign in with Google" (see
/// google_auth_service.dart) — the app's actual data still lives in the
/// existing Node/Postgres backend (see api_client.dart). Both values are
/// the project's public anon key/URL, safe to ship in the client (same
/// status as kAgoraAppId) — the matching Google Client Secret stays in
/// Supabase's own dashboard, never here.
const String kSupabaseUrl = 'https://dimgnzkpxvbepgjecumf.supabase.co';
const String kSupabaseAnonKey =
    'sb_publishable_8qohuKsQJf8qWjXZTWDyuw_TTTYS6a8';

Future<void> initSupabase() async {
  await Supabase.initialize(
      url: kSupabaseUrl, publishableKey: kSupabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
