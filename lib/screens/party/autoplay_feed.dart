import '../../core/api_client.dart';
import '../../core/ott_page_suggestions.dart';
import '../../core/youtube_util.dart';
import 'room_socket_controller.dart';

/// The suggestions shown in the lobby for [videoUrl]: YouTube's list for a
/// YouTube song, the title page's own list (next episodes, then similar
/// titles) for Prime, Netflix and Hotstar, and otherwise this phone's liked
/// songs and history from the same source. Shared by the suggestions panel
/// and Autoplay (see [AutoplayFeed]).
Future<List<Map<String, dynamic>>> loadRoomSuggestions(
    String? videoUrl, String? sourceType) async {
  var items = <Map<String, dynamic>>[];
  if (const {'amazon', 'netflix', 'hotstar'}.contains(sourceType)) {
    items = OttPageSuggestions.itemsFor(videoUrl);
  }
  if (sourceType == 'youtube') {
    try {
      items = await loadYoutubeSuggestions(videoUrl);
    } catch (_) {
      // e.g. 503 when YOUTUBE_API_KEY isn't configured — fall through.
    }
  }
  if (items.isEmpty) {
    try {
      items = await loadLikedHistoryFor(videoUrl, sourceType);
    } catch (_) {}
  }
  // The page's own list may have come in while this was loading.
  final page = OttPageSuggestions.itemsFor(videoUrl);
  return page.isNotEmpty ? page : items;
}

Future<List<Map<String, dynamic>>> loadYoutubeSuggestions(
    String? videoUrl) async {
  final videoId = extractYouTubeId(videoUrl ?? '');
  if (videoId == null) return [];
  final data = await ApiClient.get('/youtube/suggestions?v=$videoId');
  return (data as List)
      .cast<Map<String, dynamic>>()
      .map((v) => {
            'videoUrl': 'https://www.youtube.com/watch?v=${v['videoId']}',
            'title': v['title'],
            'thumbnail': v['thumbnail'],
            'sourceType': 'youtube',
            'durationSeconds': v['durationSeconds'],
          })
      .toList();
}

// No room-agnostic "suggestions" pool exists for a private Drive file or a
// DRM-locked OTT page — this device's own liked/history, filtered to the
// same source, is the closest real (not fabricated) list available.
Future<List<Map<String, dynamic>>> loadLikedHistoryFor(
    String? videoUrl, String? sourceType) async {
  final results = await Future.wait([
    ApiClient.get('/liked-songs'),
    ApiClient.get('/song-history'),
  ]);
  final seen = <String>{videoUrl ?? ''};
  final items = <Map<String, dynamic>>[];
  for (final list in results) {
    for (final raw in (list as List)) {
      final v = Map<String, dynamic>.from(raw as Map);
      final url = v['videoUrl'] as String?;
      if (url == null || !seen.add(url)) continue;
      if ((v['sourceType'] as String?) != sourceType) continue;
      items.add(v);
    }
  }
  return items;
}

/// On the host's phone: sends the room's lobby suggestions for the song
/// that's playing to the server, so Autoplay plays the top one when the
/// queue runs out (syncHandler.js's queue:suggestions).
class AutoplayFeed {
  AutoplayFeed(this.rs) {
    OttPageSuggestions.current.addListener(_onPageList);
  }

  final RoomSocketController rs;
  String? _fedFor;

  void dispose() => OttPageSuggestions.current.removeListener(_onPageList);

  /// Call on every build: sends once per song, and only for the host.
  void update(Map<String, dynamic>? current) {
    final url = current?['videoUrl'] as String?;
    if (!rs.isHost || url == null || url == _fedFor) return;
    _fedFor = url;
    final type = current!['sourceType'] as String?;
    loadRoomSuggestions(url, type).then((items) {
      if (_fedFor == url && items.isNotEmpty) rs.shareSuggestions(url, items);
    });
  }

  // Prime/Netflix/Hotstar: the title page's list arrives a little later.
  void _onPageList() {
    final url = _fedFor;
    if (url == null || !rs.isHost) return;
    final items = OttPageSuggestions.itemsFor(url);
    if (items.isNotEmpty) rs.shareSuggestions(url, items);
  }
}
