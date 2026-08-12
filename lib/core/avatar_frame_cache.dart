import 'api_client.dart';
import '../models/avatar_frame.dart';

/// In-memory cache of the avatar-frame catalog (id -> imageUrl) so any
/// screen rendering someone else's `equippedFrameId` (Discover cards,
/// swipe cards, chat) can resolve it to an image without a per-avatar
/// network round trip. Populated lazily on first use; VipStoreScreen
/// refreshes it after a purchase/equip change.
class AvatarFrameCache {
  AvatarFrameCache._();

  static Map<String, String>? _urlById;

  static Future<Map<String, String>> load() async {
    final cached = _urlById;
    if (cached != null) return cached;
    return refresh();
  }

  static Future<Map<String, String>> refresh() async {
    try {
      final data = await ApiClient.get('/store/avatar-frames');
      final frames = (data as List).map((e) => AvatarFrame.fromJson(e as Map<String, dynamic>)).toList();
      _urlById = {for (final f in frames) f.id: f.imageUrl};
    } catch (_) {
      _urlById = {};
    }
    return _urlById!;
  }

  /// Synchronous best-effort lookup for widgets that can't await (e.g. a
  /// list item builder) — returns null until [load]/[refresh] has resolved
  /// at least once this session, which is fine since the frame border is
  /// a cosmetic nice-to-have, not core content.
  static String? urlFor(String? frameId) {
    if (frameId == null) return null;
    return _urlById?[frameId];
  }
}
