import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/add_to_queue_dialog.dart';
import '../../widgets/app_image.dart';
import '../lobby/source_picker_screen.dart';

/// Consolidated queue + source-picker screen — the queue itself (reorder,
/// jump, remove) always visible at the bottom; the same source-picker grid
/// used at room creation (see source_picker_screen.dart's SourcePickerBody)
/// sits above it in "in-room" mode, so adding a song or switching the
/// room's source uses one consistent picker everywhere in the app.
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
  final Future<void> Function(String sourceType, String videoUrl, {String? videoTitle, String? videoThumbnail}) onSwitchSource;
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
  Future<void> _addToQueue({required String videoUrl, required String title, String? thumbnail, required String mediaMode, String sourceType = 'youtube'}) async {
    final items = (widget.queue['items'] as List?) ?? [];
    final position = await showAddToQueueDialog(context, queueIsEmpty: items.isEmpty);
    if (position == null || !mounted) return;
    widget.onAdd(
      {'sourceType': sourceType, 'videoUrl': videoUrl, 'title': title, 'thumbnail': thumbnail, 'mediaMode': widget.audioOnly ? 'audio' : mediaMode},
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

    return GestureDetector(
      // Swipe left-to-right closes this screen and lands back on the room,
      // mirroring the right-to-left swipe on the room that opened it.
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) _close();
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: _close),
        title: const Text('Queue'),
        actions: [
          if (widget.canAddSongs)
            IconButton(
              icon: Icon(_showPicker ? Icons.search_off : Icons.search),
              tooltip: _showPicker ? 'Hide search' : 'Search to add a video',
              onPressed: () => setState(() => _showPicker = !_showPicker),
            ),
          TextButton(
            onPressed: widget.onOpenRoster,
            child: Text('👥 ${widget.participantCount}', style: const TextStyle(color: AppColors.textDim)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.canAddSongs && _showPicker)
            SizedBox(
              height: 320,
              child: SourcePickerBody(
                roomId: widget.roomId,
                onAddToQueue: _addToQueue,
                onSwitchSource: widget.onSwitchSource,
              ),
            ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Queue', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                Text('${items.length} item${items.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Nothing queued yet.', style: TextStyle(color: AppColors.textFaint)))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    // onReorderItem (unlike the deprecated onReorder) already
                    // adjusts newIndex for the removed item at oldIndex, so
                    // no manual off-by-one correction is needed here.
                    onReorderItem: widget.isHost
                        ? (from, to) => widget.onReorder(from, to)
                        : (_, __) {},
                    itemBuilder: (context, i) {
                      final item = Map<String, dynamic>.from(items[i] as Map);
                      final isCurrent = i == currentIndex;
                      return Container(
                        key: ValueKey('queue-$i-${item['videoUrl']}'),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                          border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            if (widget.isHost) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.drag_handle, color: AppColors.textFaint, size: 18)),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
                              clipBehavior: Clip.antiAlias,
                              child: item['thumbnail'] != null ? AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover) : const Center(child: Text('📺')),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'] as String? ?? 'Video', style: const TextStyle(color: AppColors.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (isCurrent || item['mediaMode'] == 'audio')
                                    Text(
                                      [if (isCurrent) 'Now playing', if (item['mediaMode'] == 'audio') '🎧 Audio only'].join(' · '),
                                      style: const TextStyle(color: AppColors.primary, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            if (!isCurrent && widget.canPin)
                              TextButton(onPressed: () => widget.onJump(i), child: const Text('Play', style: TextStyle(fontSize: 11))),
                            if (!isCurrent && widget.isHost)
                              IconButton(onPressed: () => widget.onRemove(i), icon: const Icon(Icons.close, color: AppColors.danger, size: 16)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
