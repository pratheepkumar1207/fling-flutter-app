import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/add_to_queue_dialog.dart';
import '../../widgets/app_image.dart';
import '../../widgets/glass.dart';
import '../lobby/source_picker_screen.dart';

/// Full-screen (not a bottom sheet) — "Now playing" (current track,
/// play-icon thumbnail) and "Up next" section labels, drag-handle +
/// thumbnail + title/subtitle + remove per row. The inline source-picker
/// search (real, necessary — this app has no other add-a-song entry point)
/// sits right under the header instead of behind a separate AppBar search
/// icon. Section labels are rendered as part of each row (not separate list
/// entries) so the single ReorderableListView over the full item list — and
/// its existing fromIndex/toIndex wire-format to queue:reorder — stays
/// exactly as it was; splitting into two separately-reorderable lists would
/// have needed a local-to-real index translation with no way to verify it
/// against the live multiplayer sync without real testing. Swipe-left-to-
/// right still closes it, mirroring the swipe that opens it from the room.
class QueueSheetScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> queue;
  final bool isHost;
  final int participantCount;
  final void Function(Map<String, dynamic> item, {String position}) onAdd;
  final void Function(int index) onJump;
  final void Function(int index) onRemove;
  final void Function(int fromIndex, int toIndex) onReorder;
  final VoidCallback onOpenRoster;
  final Future<void> Function(String sourceType, String videoUrl,
      {String? videoTitle, String? videoThumbnail}) onSwitchSource;
  final bool audioOnly;
  final bool canPin;
  final bool canAddSongs;

  const QueueSheetScreen({
    super.key,
    required this.roomId,
    required this.queue,
    required this.isHost,
    required this.participantCount,
    required this.onAdd,
    required this.onJump,
    required this.onRemove,
    required this.onReorder,
    required this.onOpenRoster,
    required this.onSwitchSource,
    this.audioOnly = false,
    bool? canPin,
    this.canAddSongs = true,
  }) : canPin = canPin ?? isHost;

  @override
  State<QueueSheetScreen> createState() => _QueueSheetScreenState();
}

class _QueueSheetScreenState extends State<QueueSheetScreen> {
  // The one choke point every picker entry point (YouTube, Drive, OTT/
  // YouTube Surf, Liked, History, Playlists) funnels through — see
  // add_to_queue_dialog.dart for why the confirmation lives here instead
  // of in each individual picker screen.
  Future<void> _addToQueue(
      {required String videoUrl,
      required String title,
      String? thumbnail,
      required String mediaMode,
      String sourceType = 'youtube'}) async {
    final items = (widget.queue['items'] as List?) ?? [];
    // "Queue empty" means nothing queued *after* whatever's currently
    // playing — the currently-playing item itself doesn't count. Since
    // items always includes the current item at currentIndex, that's
    // exactly items.length <= 1 (0 = truly nothing, 1 = only the item
    // that's already playing).
    final position =
        await showAddToQueueDialog(context, queueIsEmpty: items.length <= 1);
    if (position == null || !mounted) return;
    widget.onAdd(
      {
        'sourceType': sourceType,
        'videoUrl': videoUrl,
        'title': title,
        'thumbnail': thumbnail,
        'mediaMode': widget.audioOnly ? 'audio' : mediaMode
      },
      position: position,
    );
  }

  void _close() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.queue['items'] as List?) ?? [];
    final currentIndex = widget.queue['currentIndex'] as int? ?? 0;
    // First row (in existing array order) that isn't the current track —
    // that's where the "UP NEXT" label goes, right before it.
    final firstUpNextIndex = items.isEmpty
        ? -1
        : (currentIndex == 0 ? (items.length > 1 ? 1 : -1) : 0);

    return GestureDetector(
      // Swipe left-to-right closes this screen and lands back on the room,
      // mirroring the right-to-left swipe on the room that opened it.
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: GlassPanel(
            borderRadius: BorderRadius.zero,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                          onTap: _close,
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.textFaint, size: 20)),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                          children: [
                            const TextSpan(text: 'Queue '),
                            TextSpan(
                                text:
                                    '· ${items.length} song${items.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: AppColors.textFaint,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onOpenRoster,
                        child: Text('👥 ${widget.participantCount}',
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                // Always visible now (search icon + this screen are the
                // single, merged entry point for finding and queueing a
                // song — see party_screen.dart's AppBar comment) instead
                // of behind a "+Add" toggle. 5 icons per row, sized for
                // ~3 rows before it scrolls.
                if (widget.canAddSongs)
                  SizedBox(
                    height: 270,
                    child: SourcePickerBody(
                      compact: true,
                      roomId: widget.roomId,
                      onAddToQueue: _addToQueue,
                      onSwitchSource: widget.onSwitchSource,
                    ),
                  ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text('Nothing queued yet.',
                              style: TextStyle(color: AppColors.textFaint)))
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                          itemCount: items.length,
                          // onReorderItem (unlike the deprecated onReorder) already
                          // adjusts newIndex for the removed item at oldIndex, so
                          // no manual off-by-one correction is needed here.
                          onReorderItem: widget.isHost
                              ? (from, to) => widget.onReorder(from, to)
                              : (_, __) {},
                          itemBuilder: (context, i) {
                            final item =
                                Map<String, dynamic>.from(items[i] as Map);
                            final isCurrent = i == currentIndex;
                            return Column(
                              key: ValueKey('queue-$i-${item['videoUrl']}'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isCurrent)
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Text('NOW PLAYING',
                                          style: TextStyle(
                                              color: AppColors.accent2,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6))),
                                if (i == firstUpNextIndex)
                                  const Padding(
                                      padding: EdgeInsets.fromLTRB(0, 14, 0, 4),
                                      child: Text('UP NEXT',
                                          style: TextStyle(
                                              color: AppColors.textFaint,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6))),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: isCurrent ? 4 : 9),
                                  child: Row(
                                    children: [
                                      if (widget.isHost && !isCurrent)
                                        const Padding(
                                            padding: EdgeInsets.only(right: 11),
                                            child: Icon(
                                                Icons.drag_handle_rounded,
                                                color: AppColors.textFaint,
                                                size: 16)),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                            color: AppColors.surface3,
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            item['thumbnail'] != null
                                                ? AppImage(
                                                    source: item['thumbnail']
                                                        as String?,
                                                    fit: BoxFit.cover)
                                                : const Center(
                                                    child: Text('📺')),
                                            if (isCurrent)
                                              Container(
                                                  color: Colors.black26,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                      Icons.play_arrow_rounded,
                                                      color: Colors.white,
                                                      size: 18)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                item['title'] as String? ??
                                                    'Video',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: AppColors.text,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13)),
                                            if (item['mediaMode'] == 'audio')
                                              const Text('Audio only',
                                                  style: TextStyle(
                                                      color:
                                                          AppColors.textFaint,
                                                      fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      if (!isCurrent && widget.canPin)
                                        GestureDetector(
                                          onTap: () => widget.onJump(i),
                                          child: const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 10),
                                              child: Icon(
                                                  Icons
                                                      .play_circle_outline_rounded,
                                                  color: AppColors.textFaint,
                                                  size: 18)),
                                        ),
                                      if (!isCurrent && widget.isHost)
                                        GestureDetector(
                                          onTap: () => widget.onRemove(i),
                                          child: const Icon(Icons.close_rounded,
                                              color: AppColors.textFaint,
                                              size: 16),
                                        )
                                      else if (isCurrent)
                                        const Icon(Icons.more_vert_rounded,
                                            color: AppColors.textFaint,
                                            size: 18),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
