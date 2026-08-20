import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../../core/mobile_webview_settings.dart';
import '../../core/youtube_util.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_song_lists.dart';
import '../../widgets/spinner.dart';
import 'watch_room_creator.dart';

/// "Browse together" via a real embedded browser (not an <iframe>, which
/// Netflix/Prime block via X-Frame-Options/CSP; a WebView is a top-level
/// navigation context, so those headers don't apply) pointed at the
/// platform's own site.
///
/// For Netflix/Prime there's deliberately no content-detection or playback
/// sync: their video elements are DRM-protected and don't expose
/// play/pause/seek state to a WebView, and scripting them to try would
/// violate both platforms' terms of service. Sign-in itself is also only
/// reliable for a WebView that already has a valid session — Netflix's own
/// bot detection blocks fresh sign-in attempts in an embedded WebView
/// (confirmed live); that's a real limitation of staying embedded, not a
/// bug here, and not something this app tries to work around. Everyone who
/// *can* sign in just browses to (and lands on) the same page together;
/// from there, playing in sync is on the room, same as people in the same
/// physical room pressing play together.
///
/// 'youtube_surf' is the exception: YouTube isn't DRM-locked or blocked in
/// a WebView, so landing on a real /watch?v= page and tapping "start"
/// extracts the video id and creates a normal, fully-synced 'youtube' room
/// instead of a no-sync one — see _startHere below.
class WebviewBrowseScreen extends StatefulWidget {
  final String platform; // 'netflix' | 'amazon' | 'youtube_surf'
  final String label;
  final String homeUrl;
  final String visibility;
  final String? topic;

  /// Legacy in-room "switch source" path — replaces what the whole room is
  /// currently set to, with a confirmation prompt first. Superseded by
  /// [onAddToQueue] below for the normal picker flow (see _startHere), but
  /// left available for anything that still wants a hard replace.
  final Future<void> Function(String sourceType, String videoUrl, {String? videoTitle, String? videoThumbnail})? onConfirmOverride;

  /// The unified source picker's in-room "add to queue" path (see
  /// SourcePickerBody in source_picker_screen.dart) — same callback
  /// YouTube/Drive already use there. Queueing works fine for OTT/YouTube
  /// Surf too: the queue is just "what plays next," not a synced position,
  /// so it doesn't need per-item position sync to make sense. An empty
  /// queue means this becomes item 0 at currentIndex 0 and plays
  /// immediately (see queue:add on the backend); a non-empty queue means
  /// it's pinned to play after whatever's current — no destructive
  /// replace, so no confirmation prompt needed either.
  final SongAddCallback? onAddToQueue;

  const WebviewBrowseScreen({
    super.key,
    required this.platform,
    required this.label,
    required this.homeUrl,
    required this.visibility,
    this.topic,
    this.onConfirmOverride,
    this.onAddToQueue,
  });

  @override
  State<WebviewBrowseScreen> createState() => _WebviewBrowseScreenState();
}

class _WebviewBrowseScreenState extends State<WebviewBrowseScreen> {
  InAppWebViewController? _controller;
  bool _creatingRoom = false;
  bool _loading = true;

  Future<void> _startHere() async {
    final controller = _controller;
    if (controller == null || _creatingRoom) return;
    final url = await controller.getUrl();
    if (url == null || !mounted) return;

    var sourceType = widget.platform;
    var videoUrl = url.toString();
    String? videoTitle;
    String? videoThumbnail;
    if (widget.platform == 'youtube_surf') {
      final videoId = extractYouTubeId(videoUrl);
      if (videoId != null) {
        // Landed on a real video page — upgrade to a normal fully-synced
        // YouTube room instead of a no-sync 'youtube_surf' one. The page's
        // own <title> (usually "Video Name - YouTube") is the cheapest
        // real title available here — no extra YouTube API call needed,
        // and the thumbnail CDN URL is fully predictable from the id.
        sourceType = 'youtube';
        videoUrl = 'https://www.youtube.com/watch?v=$videoId';
        final pageTitle = await controller.getTitle();
        videoTitle = pageTitle?.replaceAll(RegExp(r'\s*-\s*YouTube$'), '').trim();
        if (videoTitle?.isEmpty ?? true) videoTitle = null;
        videoThumbnail = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    }
    if (!mounted) return;
    await _addOrCreate(sourceType: sourceType, videoUrl: videoUrl, videoTitle: videoTitle, videoThumbnail: videoThumbnail);
  }

  // Shared tail of both "confirm the current page" (_startHere, via the
  // bottom button) and "long-pressed a video thumbnail while still browsing"
  // (_onLongPressVideo) — same three destinations either way: queue it,
  // hard-replace the room's source, or start a brand new room.
  Future<void> _addOrCreate({required String sourceType, required String videoUrl, String? videoTitle, String? videoThumbnail}) async {
    final onAddToQueue = widget.onAddToQueue;
    if (onAddToQueue != null) {
      setState(() => _creatingRoom = true);
      onAddToQueue(videoUrl: videoUrl, title: videoTitle ?? widget.label, thumbnail: videoThumbnail, mediaMode: 'video', sourceType: sourceType);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final onConfirmOverride = widget.onConfirmOverride;
    if (onConfirmOverride != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Switch this room\'s source?'),
          content: Text("Everyone in the room will switch to ${widget.label} — this replaces what's currently playing."),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Switch')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _creatingRoom = true);
      await onConfirmOverride(sourceType, videoUrl, videoTitle: videoTitle, videoThumbnail: videoThumbnail);
      if (mounted) setState(() => _creatingRoom = false);
      return;
    }

    setState(() => _creatingRoom = true);
    createWatchRoomAndEnter(
      context,
      sourceType: sourceType,
      videoUrl: videoUrl,
      visibility: widget.visibility,
      topic: widget.topic,
      videoTitle: videoTitle,
      videoThumbnail: videoThumbnail,
    ).whenComplete(() {
      if (mounted) setState(() => _creatingRoom = false);
    });
  }

  // Long-press a video thumbnail/link while still browsing (search results,
  // home feed, etc.) instead of having to navigate into the watch page and
  // tap the bottom button — YouTube only, and only where extractYouTubeId
  // actually recognizes the pressed link as a real video, so long-pressing
  // unrelated page chrome does nothing.
  Future<void> _onLongPressVideo(InAppWebViewHitTestResult hitTestResult) async {
    if (widget.platform != 'youtube_surf' || _creatingRoom || !mounted) return;
    final videoId = extractYouTubeId(hitTestResult.extra);
    if (videoId == null) return;

    // In-room, _addOrCreate's onAddToQueue path already shows its own
    // Start-Here/Top/Bottom confirmation (see queue_sheet.dart's
    // _addToQueue) — a second "Add this video?" prompt here would just be
    // a redundant extra tap. Only ask here when there's no room yet.
    if (widget.onAddToQueue == null) {
      final add = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Add this video?'),
          content: const Text('Starts a new watch party with this video.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add')),
          ],
        ),
      );
      if (add != true || !mounted) return;
    }

    setState(() => _creatingRoom = true);
    final fallbackThumbnail = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    final meta = await _fetchYoutubeOembed(videoId);
    if (!mounted) return;
    await _addOrCreate(
      sourceType: 'youtube',
      videoUrl: 'https://www.youtube.com/watch?v=$videoId',
      videoTitle: meta?['title'],
      videoThumbnail: meta?['thumbnail'] ?? fallbackThumbnail,
    );
  }

  // YouTube's oEmbed endpoint — the best option for turning just a video id
  // into a real title/thumbnail without navigating there ourselves: no API
  // key, no OAuth, no scraping a page we haven't loaded.
  Future<Map<String, String>?> _fetchYoutubeOembed(String videoId) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/oembed?format=json&url=${Uri.encodeComponent('https://www.youtube.com/watch?v=$videoId')}');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final title = data['title'] as String?;
      final thumbnail = data['thumbnail_url'] as String?;
      return {if (title != null && title.isNotEmpty) 'title': title, if (thumbnail != null) 'thumbnail': thumbnail};
    } catch (_) {
      return null; // Falls back to the predictable CDN thumbnail + widget.label as title.
    }
  }

  String get _buttonLabel {
    if (widget.onAddToQueue != null) return _creatingRoom ? 'Adding…' : 'Add to queue';
    if (widget.onConfirmOverride != null) return _creatingRoom ? 'Switching…' : 'Switch room to this';
    return _creatingRoom ? 'Starting…' : 'Start watch party here';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(widget.label)),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.homeUrl)),
            initialSettings: desktopWebViewSettings,
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStart: (controller, url) => setState(() => _loading = true),
            onLoadStop: (controller, url) => setState(() => _loading = false),
            // Some sites try to deep-link into their own native app via a
            // custom URL scheme (e.g. "sunnxt://detail/268303") when you
            // tap a video — a WebView can't open that (there's no app to
            // hand it to), and letting the navigation through just replaces
            // the page with an ugly "Webpage not available" system error.
            // Silently ignoring anything that isn't http(s) keeps the
            // WebView on whatever content was already loaded instead.
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final scheme = navigationAction.request.url?.scheme;
              if (scheme != null && scheme != 'http' && scheme != 'https') {
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            // See webview_room_player.dart — without granting this, DRM
            // playback (previews included) can't initialize at all.
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT);
            },
            onLongPressHitTestResult: (controller, hitTestResult) => _onLongPressVideo(hitTestResult),
          ),
          if (_loading) const Positioned(top: 8, left: 0, right: 0, child: Center(child: Spinner(size: 20))),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _creatingRoom ? null : _startHere,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
