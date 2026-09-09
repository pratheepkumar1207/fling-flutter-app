import 'media_source.dart';

/// Spec Step 9 — provider abstraction over search/resolve. No concrete
/// implementation exists yet: today's source picker (lobby/
/// webview_browse_screen.dart, source_picker_screen.dart) talks to
/// per-platform backend routes directly (e.g. /youtube/search,
/// /drive/list) rather than through a shared client-side interface.
/// Wiring a real implementation of this is future work (see
/// INSYNC_MIGRATION_MAP.md) — declared now so PlaybackAdapter
/// implementations have a stable interface to depend on without waiting
/// for that wiring to land first.
abstract interface class MediaProvider {
  String get id;
  Future<List<MediaSource>> search(String query);
  Future<MediaSource?> resolve(String id);
}
