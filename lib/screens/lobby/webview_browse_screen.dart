import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/mobile_webview_settings.dart';
import '../../core/youtube_util.dart';
import '../../theme/app_colors.dart';
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

  /// When set (the unified source picker's in-room "switch source" path —
  /// see SourcePickerBody in source_picker_screen.dart), landing here and
  /// confirming calls this instead of creating a new room. Streaming
  /// platforms have no sync/queue, so "adding to queue" doesn't make sense
  /// for them the way it does for YouTube/Drive — the only sensible in-room
  /// action is replacing what the whole room is currently set to, which is
  /// why this prompts for confirmation first (see _startHere).
  final Future<void> Function(String sourceType, String videoUrl, {String? videoTitle, String? videoThumbnail})? onConfirmOverride;

  const WebviewBrowseScreen({
    super.key,
    required this.platform,
    required this.label,
    required this.homeUrl,
    required this.visibility,
    this.topic,
    this.onConfirmOverride,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(widget.label)),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.homeUrl)),
            initialSettings: mobileWebViewSettings,
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
          ),
          if (_loading) const Positioned(top: 8, left: 0, right: 0, child: Center(child: Spinner(size: 20))),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _creatingRoom ? null : _startHere,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_creatingRoom ? 'Starting…' : (widget.onConfirmOverride != null ? 'Switch room to this' : 'Start watch party here')),
            ),
          ),
        ],
      ),
    );
  }
}
