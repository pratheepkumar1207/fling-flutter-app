import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/add_to_queue_dialog.dart';
import '../../widgets/app_image.dart';
import '../lobby/source_picker_screen.dart';

/// Matches QueueSheetDark.dc.html: a dimmed-backdrop rounded-top sheet
/// with "Now playing" (current track, play-icon thumbnail) and "Up next"
/// section labels, drag-handle + thumbnail + title/subtitle + remove per
/// row. The inline source-picker search (real, necessary — this app has
/// no other add-a-song entry point) opens under the header's "+ Add" pill
/// instead of an AppBar search icon, matching the mockup's button. Section
/// labels are rendered as part of each row (not separate list entries) so
/// the single ReorderableListView over the full item list — and its
/// existing fromIndex/toIndex wire-format to queue:reorder — stays exactly
/// as it was; splitting into two separately-reorderable lists would have
/// needed a local-to-real index translation with no way to verify it
/// against the live multiplayer sync without real testing. Still pushed as
/// a full route rather than a real showModalBottomSheet (keeps the
/// existing swipe-to-dismiss gesture and AnimatedBuilder wiring in
/// party_screen.dart unchanged), just styled to read as one.
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
  bool _showPicker = false;

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
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.82,
              widthFactor: 1,
              child: Container(
                decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
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
                          Row(
                            children: [
                              GestureDetector(
                                onTap: widget.onOpenRoster,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Text('👥 ${widget.participantCount}',
                                      style: const TextStyle(
                                          color: AppColors.textDim,
                                          fontSize: 12)),
                                ),
                              ),
                              if (widget.canAddSongs)
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _showPicker = !_showPicker),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 13, vertical: 7),
                                    decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                            color: AppColors.accent2,
                                            width: 1.5)),
                                    child: Text(_showPicker ? 'Hide' : '+ Add',
                                        style: const TextStyle(
                                            color: AppColors.accent2,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.canAddSongs && _showPicker)
                      SizedBox(
                        height: 320,
                        child: SourcePickerBody(
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
                                          padding:
                                              EdgeInsets.fromLTRB(0, 14, 0, 4),
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
                                                padding:
                                                    EdgeInsets.only(right: 11),
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
                                                        source:
                                                            item['thumbnail']
                                                                as String?,
                                                        fit: BoxFit.cover)
                                                    : const Center(
                                                        child: Text('📺')),
                                                if (isCurrent)
                                                  Container(
                                                      color: Colors.black26,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Icon(
                                                          Icons
                                                              .play_arrow_rounded,
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: AppColors.text,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13)),
                                                if (item['mediaMode'] ==
                                                    'audio')
                                                  const Text('Audio only',
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .textFaint,
                                                          fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                          if (!isCurrent && widget.canPin)
                                            GestureDetector(
                                              onTap: () => widget.onJump(i),
                                              child: const Padding(
                                                  padding: EdgeInsets.only(
                                                      right: 10),
                                                  child: Icon(
                                                      Icons
                                                          .play_circle_outline_rounded,
                                                      color:
                                                          AppColors.textFaint,
                                                      size: 18)),
                                            ),
                                          if (!isCurrent && widget.isHost)
                                            GestureDetector(
                                              onTap: () => widget.onRemove(i),
                                              child: const Icon(
                                                  Icons.close_rounded,
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
        ),
      ),
    );
  }
}
