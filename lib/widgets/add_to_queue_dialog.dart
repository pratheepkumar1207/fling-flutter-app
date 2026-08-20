import 'package:flutter/material.dart';

/// Shown right before a picked song/video actually gets queued — one
/// choke point (queue_sheet.dart's _addToQueue) covers every picker entry
/// point (YouTube, Drive, OTT/YouTube Surf, Liked, History, Playlists),
/// since they all funnel through the same onAdd callback.
///
/// Returns the chosen position ('top' | 'bottom'), or null if cancelled.
/// When the queue is empty there's nothing to be "on top of" or "under" —
/// only one real choice, framed as "Start Here" rather than a queue
/// position at all (the backend treats an empty-queue add as position
/// 'bottom' either way, since that's just "become item 0").
Future<String?> showAddToQueueDialog(BuildContext context, {required bool queueIsEmpty}) {
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(queueIsEmpty ? 'Start here?' : 'Add to queue'),
      content: Text(
        queueIsEmpty
            ? "Nothing's playing yet in this lobby — this will start right away."
            : "Something's already playing — where should this go?",
      ),
      actions: queueIsEmpty
          ? [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop('bottom'), child: const Text('Start Here')),
            ]
          : [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop('bottom'), child: const Text('Add to Bottom')),
              TextButton(onPressed: () => Navigator.of(context).pop('top'), child: const Text('Add to Top')),
            ],
    ),
  );
}
