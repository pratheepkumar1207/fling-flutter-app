import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/media3_player_adapter.dart';
import '../domain/video_player_adapter.dart';

/// Hosts the native Media3PlayerView platform view (registered in
/// MainActivity.kt under "fling/media3_player") and hands the caller a
/// ready VideoPlayerAdapter once Android has actually created the
/// underlying ExoPlayer — mirrors the existing WebView-based players'
/// pattern (an AndroidView wrapped in a Flutter widget, real controls drawn
/// on top by the caller, not by this widget).
///
/// This widget only owns the platform view's lifecycle; it does not create
/// any UI chrome itself (no play/pause/seek bar) — same division of
/// responsibility as SyncVideoPlayer/DriveVideoPlayer, which draw their own
/// controls above whichever player surface they're driving.
class Media3PlayerView extends StatefulWidget {
  final ValueChanged<VideoPlayerAdapter> onAdapterReady;

  const Media3PlayerView({super.key, required this.onAdapterReady});

  @override
  State<Media3PlayerView> createState() => _Media3PlayerViewState();
}

class _Media3PlayerViewState extends State<Media3PlayerView> {
  Media3PlayerAdapter? _adapter;

  @override
  void dispose() {
    // Media3PlayerAdapter.dispose() only cancels this adapter's own event
    // subscription and closes its Dart-side StreamController — it does not
    // call any native method (see the adapter's own comment on why:
    // AndroidView's disposal, happening as this widget leaves the tree
    // right now, is what releases the actual ExoPlayer instance). Calling
    // it here regardless of whether the caller that received the adapter
    // via onAdapterReady remembered to, so a widget removed from the tree
    // never leaks a live stream subscription.
    _adapter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'fling/media3_player',
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int viewId) {
        final adapter = Media3PlayerAdapter(viewId);
        _adapter = adapter;
        widget.onAdapterReady(adapter);
      },
    );
  }
}
