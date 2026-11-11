import 'package:flutter/foundation.dart';

/// What a streaming site's own page offers next for the title playing in
/// the room — Prime Video's episode list and "Customers also watched" —
/// read from this person's own logged-in page by webview_room_player.dart
/// and shown by video_suggestions_panel.dart. Each phone reads its own
/// page, so nothing goes through the server.
class OttPageSuggestions {
  OttPageSuggestions._();

  /// The latest list, with the room title (host + path of its address)
  /// it belongs to.
  static final ValueNotifier<({String key, List<Map<String, dynamic>> items})?>
      current = ValueNotifier(null);

  static String keyFor(String? url) {
    final u = Uri.tryParse(url ?? '');
    return u == null ? '' : '${u.host}${u.path}';
  }

  static List<Map<String, dynamic>> itemsFor(String? url) {
    final c = current.value;
    return c != null && c.key == keyFor(url) ? c.items : const [];
  }

  /// Prime and Hotstar serve AVIF thumbnails, which the app's image
  /// decoder can't read; the same image is available as JPEG.
  static String? jpegThumbnail(String? url) => url
      ?.replaceAll('_FMavif_', '_FMjpg_')
      .replaceAll('_FMwebp_', '_FMjpg_')
      .replaceAll('/f_auto,', '/f_jpg,')
      .replaceAll('/f_auto/', '/f_jpg/');
}
