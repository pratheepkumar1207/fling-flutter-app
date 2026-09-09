import '../../media/domain/media_source.dart';

class QueueItem {
  final String id;
  final MediaSource media;
  final String addedBy;

  const QueueItem({
    required this.id,
    required this.media,
    required this.addedBy,
  });
}

/// Typed view over RoomSocketController.queue's existing raw Map (see
/// INSYNC_MIGRATION_MAP.md's PartyQueue row) — the real queue system
/// already exceeds this shape (majority vote-to-skip/vote-to-add, server-
/// authoritative versioning against stale mutations, spec Step 11), this
/// is just a typed snapshot for code that wants PartySession-shaped data
/// rather than a raw map.
class PartyQueue {
  final List<QueueItem> items;
  final int currentIndex;
  final int version;

  const PartyQueue({
    this.items = const [],
    this.currentIndex = 0,
    this.version = 0,
  });

  QueueItem? get current => items.isNotEmpty && currentIndex < items.length ? items[currentIndex] : null;
}
