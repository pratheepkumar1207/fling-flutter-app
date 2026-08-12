import 'api_client.dart';
import 'interest_options.dart';

/// Admin-managed interest tags (see GET /auth/interest-options,
/// src/models/Interest.js) — replaces the old hardcoded kInterestOptions
/// list. Cached in-memory for the process lifetime since it rarely
/// changes and every screen using InterestPicker would otherwise re-fetch
/// it independently.
class InterestOptionsCache {
  InterestOptionsCache._();

  static List<List<String>>? _cached;

  static Future<List<List<String>>> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final data = await ApiClient.get('/auth/interest-options');
      final options = (data as List)
          .map((e) => [e['key'] as String, e['label'] as String, e['emoji'] as String])
          .toList();
      // An empty/failed response shouldn't leave the picker with nothing to
      // show — fall back to the old static list rather than a blank screen.
      _cached = options.isNotEmpty ? options : kInterestOptions;
    } catch (_) {
      _cached = kInterestOptions;
    }
    return _cached!;
  }
}
