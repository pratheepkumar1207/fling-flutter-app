import 'dart:collection';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../../core/api_client.dart';
import '../../core/mobile_webview_settings.dart';
import '../../core/youtube_util.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_song_lists.dart';
import '../../widgets/spinner.dart';
import 'browser_video_tray.dart';
import 'watch_room_creator.dart';
import '../../widgets/insync_snack.dart';

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
  final String platform; // 'netflix' | 'amazon' | 'youtube_surf' | 'web'
  final String label;
  final String homeUrl;
  final String visibility;
  final String? topic;
  // Room name + mic/song settings chosen in the lobby — see WatchRoomOptions.
  final WatchRoomOptions? options;

  /// Legacy in-room "switch source" path — replaces what the whole room is
  /// currently set to, with a confirmation prompt first. Superseded by
  /// [onAddToQueue] below for the normal picker flow (see _startHere), but
  /// left available for anything that still wants a hard replace.
  final Future<void> Function(String sourceType, String videoUrl,
      {String? videoTitle, String? videoThumbnail})? onConfirmOverride;

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

  /// In-room, the Browser's "Add N to queue": several at the end of the
  /// queue without interrupting what's playing.
  final void Function(List<Map<String, dynamic>> items)? onQueueMany;

  const WebviewBrowseScreen({
    super.key,
    required this.platform,
    required this.label,
    required this.homeUrl,
    required this.visibility,
    this.topic,
    this.options,
    this.onConfirmOverride,
    this.onAddToQueue,
    this.onQueueMany,
  });

  @override
  State<WebviewBrowseScreen> createState() => _WebviewBrowseScreenState();
}

// Best-effort per-platform "this URL is a real watch/play page, not a
// browse/home/search/watchlist page" heuristics — same spirit as
// webview_room_player.dart's _checkLoginUrl. Netflix's player URL is
// reliably /watch/<numeric id>; others are less certain, so they fall back
// to the generic pattern below rather than guessing a specific shape wrong.
final _platformWatchPatterns = <String, RegExp>{
  'netflix': RegExp(r'netflix\.com/(?:[a-z]{2}(?:-[a-z]{2})?/)?watch/\d+',
      caseSensitive: false),
  'hotstar': RegExp(r'hotstar\.com/.+/watch(?:[/?]|$)', caseSensitive: false),
  'sonyliv': RegExp(r'sonyliv\.com/watch/', caseSensitive: false),
  // Prime Video is the odd one out: it never navigates to a distinct
  // /watch/ path at all — browsing and playing both stay on the same
  // /detail/<id> URL, and pressing play just appends ?autoplay=1 (and a
  // resume timestamp) to that same URL (confirmed live from the page's own
  // playbackURL/fallbackURL fields). The generic /watch|/play/ fallback
  // below would never match this, so it needs its own pattern.
  'amazon': RegExp(r'primevideo\.com/detail/[^?]+\?[^#]*\bautoplay=1\b',
      caseSensitive: false),
};
// Slash/query/end-bounded so "/watchlist" (a real nav destination on
// several of these platforms) never false-matches "/watch".
final _genericWatchPattern =
    RegExp(r'/(watch|play|player)(?:[/?]|$)', caseSensitive: false);

class _WebviewBrowseScreenState extends State<WebviewBrowseScreen> {
  InAppWebViewController? _controller;
  bool _creatingRoom = false;
  bool _loading = true;
  // Set the instant auto-detection fires, before the async room-creation
  // work even starts — guards against onLoadStop firing again (redirects,
  // resource loads on the same page) and racing a second _startHere() call.
  bool _autoStarted = false;

  // Belt-and-suspenders alongside onLoadStop/onUpdateVisitedHistory: Prime
  // Video and YouTube's mobile site both reach their real watch page via
  // client-side routing (history.replaceState/pushState), and confirmed
  // live, that route change doesn't always reach either WebView callback —
  // so poll the actual URL as a fallback that doesn't depend on either one
  // firing.
  Timer? _urlPoll;

  // The rule: the moment a title's watch page opens or its video starts
  // playing here, go straight back to the lobby with it pinned — no wait.
  // Only Prime's "a player is somewhere on the page" guess (no watch URL,
  // no Play tap seen) still waits a few seconds, so a trailer on a title
  // page doesn't count as a pick.
  static const _playFor = Duration.zero;
  static const _watchPageFallback = Duration(seconds: 4);
  DateTime? _playingSince;
  DateTime? _watchPageSince;
  // Prime Video: the Play or Resume link that was tapped. Prime's player
  // opens with an ad, so the room is started the moment Play is tapped
  // rather than after 3 seconds of playing — any ad then plays once, in
  // the room. Nothing is skipped.
  String? _pickedUrl;
  static const _watchPrimeTaps = r'''
    (function() {
      if (!window.__insyncTaps) {
        window.__insyncTaps = true;
        document.addEventListener('click', function(e) {
          var a = e.target && e.target.closest &&
            e.target.closest('a[href*="autoplay=1"]');
          if (a) window.__insyncPlayHref = a.href;
        }, true);
      }
      var h = window.__insyncPlayHref || null;
      window.__insyncPlayHref = null;
      return h;
    })();
  ''';
  // Shows the Pin to room button: a title is playing or its watch page is open.
  bool _canPin = false;

  // "Browser": any website, with an address bar. Always the desktop site,
  // fitted to the phone's width with pinch-to-zoom. Nothing is pinned by
  // itself there; the person taps Pin to room.
  bool get _isWeb => widget.platform == 'web';
  static final _browserSettings = desktopWebViewSettings.copy()
    ..supportZoom = true
    ..builtInZoomControls = true
    ..displayZoomControls = false;
  final _address = TextEditingController();

  // Videos found on the current page (Browser only).
  List<FoundVideo> _videos = const [];
  String _videosSig = '';
  bool _cardCollapsed = false;
  String? _dismissedFor; // page whose single-video card was closed
  String _pageUrl = '';
  int _scanTick = 0;

  // Looks for videos on the page: YouTube/Vimeo players and the page's own
  // <video> elements. Reads only addresses, titles, poster pictures and
  // lengths; never touches playback.
  static const _findVideosJs = r'''
(function () {
  function abs(u) { try { return new URL(u, location.href).href; } catch (e) { return null; } }
  var ogEl = document.querySelector('meta[property="og:image"]');
  var og = ogEl ? abs(ogEl.content) : null;
  var out = [], seen = {};
  function add(o) { if (!seen[o.key]) { seen[o.key] = 1; out.push(o); } }
  var href = location.href;
  var m = href.match(/[?&]v=([\w-]{11})/) || href.match(/youtu\.be\/([\w-]{11})/) ||
          href.match(/youtube\.com\/shorts\/([\w-]{11})/);
  if (m) add({ key: 'yt:' + m[1], kind: 'youtube', id: m[1], title: document.title });
  var frames = document.querySelectorAll('iframe');
  for (var i = 0; i < frames.length; i++) {
    var src = frames[i].src || '';
    var y = src.match(/youtube(?:-nocookie)?\.com\/embed\/([\w-]{11})/);
    if (y) add({ key: 'yt:' + y[1], kind: 'youtube', id: y[1], title: frames[i].title || '' });
    var v = src.match(/player\.vimeo\.com\/video\/(\d+)/);
    if (v) add({ key: 'vm:' + v[1], kind: 'vimeo', id: v[1], title: frames[i].title || '',
                 url: 'https://player.vimeo.com/video/' + v[1], thumb: og });
  }
  if (!/(^|\.)youtube\.com$/.test(location.hostname)) {
    var vids = document.querySelectorAll('video');
    for (var j = 0; j < vids.length; j++) {
      var el = vids[j], r = el.getBoundingClientRect();
      if (r.width < 120 || r.height < 70) continue;
      var s = el.currentSrc || el.src || '';
      var direct = /^https?:/.test(s) ? s : null;
      add({ key: 'v:' + (direct || (href + '#' + j)), kind: 'video',
            url: direct || href,
            title: el.getAttribute('title') || el.getAttribute('aria-label') || document.title,
            thumb: el.poster ? abs(el.poster) : og,
            duration: isFinite(el.duration) ? Math.round(el.duration) : null,
            locked: !!el.mediaKeys });
    }
  }
  return JSON.stringify({ title: document.title, items: out });
})();
''';

  Future<void> _scanVideos() async {
    // Every other tick (about 1.4 s) is plenty.
    if (++_scanTick % 2 != 0) return;
    final raw = await _controller?.evaluateJavascript(source: _findVideosJs);
    if (!mounted || raw is! String) return;
    if (raw == _videosSig) return;
    _videosSig = raw;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final pageTitle = (data['title'] as String?)?.trim() ?? '';
    final host = Uri.tryParse(_pageUrl)?.host.replaceFirst('www.', '') ?? '';
    String nameOr(String? t) =>
        (t != null && t.trim().isNotEmpty) ? t.trim() : pageTitle;
    final found = <FoundVideo>[];
    for (final it in (data['items'] as List? ?? const [])) {
      if (it is! Map) continue;
      switch (it['kind']) {
        case 'youtube':
          final id = it['id'] as String;
          found.add(FoundVideo(
            key: it['key'] as String,
            title: nameOr((it['title'] as String?)
                ?.replaceAll(RegExp(r'\s*-\s*YouTube$'), '')),
            thumbnail: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
            videoUrl: youtubeWatchUrl(id),
            sourceType: 'youtube',
            site: 'YouTube',
          ));
        case 'vimeo':
          found.add(FoundVideo(
            key: it['key'] as String,
            title: nameOr(it['title'] as String?),
            thumbnail: it['thumb'] as String?,
            videoUrl: it['url'] as String,
            sourceType: 'web',
            site: 'Vimeo',
          ));
        default:
          found.add(FoundVideo(
            key: it['key'] as String,
            title: nameOr(it['title'] as String?),
            thumbnail: it['thumb'] as String?,
            durationSec: (it['duration'] as num?)?.toInt(),
            videoUrl: it['url'] as String,
            sourceType: 'web',
            site: host,
            locked: it['locked'] == true,
          ));
      }
    }
    setState(() => _videos = found);
  }

  /// Watch these: in a room they go to its queue; otherwise a new room
  /// starts on the first, with the rest queued.
  Future<void> _pickVideos(List<FoundVideo> picks) async {
    final ok = picks.where((v) => !v.locked).toList();
    if (ok.isEmpty || _creatingRoom) return;
    final first = ok.first;
    final many = widget.onQueueMany;
    if (widget.onAddToQueue != null) {
      if (ok.length > 1 && many != null) {
        setState(() => _creatingRoom = true);
        final messenger = ScaffoldMessenger.of(context);
        many([for (final v in ok) v.toQueueItem()]);
        Navigator.of(context).pop();
        messenger.showSnackBar(insyncSnackBar(
            content: Text('Added ${ok.length} videos to the queue')));
        return;
      }
      await _addOrCreate(
          sourceType: first.sourceType,
          videoUrl: first.videoUrl,
          videoTitle: first.title,
          videoThumbnail: first.thumbnail);
      return;
    }
    if (widget.onConfirmOverride != null) {
      await _addOrCreate(
          sourceType: first.sourceType,
          videoUrl: first.videoUrl,
          videoTitle: first.title,
          videoThumbnail: first.thumbnail);
      return;
    }
    setState(() => _creatingRoom = true);
    createWatchRoomAndEnter(
      context,
      sourceType: first.sourceType,
      videoUrl: first.videoUrl,
      visibility: widget.visibility,
      topic: widget.topic,
      options: widget.options,
      videoTitle: first.title,
      videoThumbnail: first.thumbnail,
      queueItems:
          ok.length > 1 ? [for (final v in ok) v.toQueueItem()] : null,
    ).whenComplete(() {
      if (mounted) setState(() => _creatingRoom = false);
    });
  }

  void _go(String input) {
    final text = input.trim();
    if (text.isEmpty) return;
    final looksLikeUrl = !text.contains(' ') &&
        (text.startsWith('http://') ||
            text.startsWith('https://') ||
            RegExp(r'^[\w-]+(\.[\w-]+)+(/.*)?$').hasMatch(text));
    final url = looksLikeUrl
        ? (text.startsWith('http') ? text : 'https://$text')
        : 'https://www.google.com/search?q=${Uri.encodeQueryComponent(text)}';
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _updateCanPin() {
    final can = _playingSince != null || _watchPageSince != null;
    if (can != _canPin && mounted) setState(() => _canPin = can);
  }

  @override
  void initState() {
    super.initState();
    _urlPoll = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (_autoStarted || _creatingRoom || !mounted) return;
      if (_isWeb) {
        await _scanVideos();
        return;
      }
      final url = await _controller?.getUrl();
      if (!mounted || url == null) return;
      final urlStr = url.toString();
      if (widget.platform == 'amazon') {
        final tapped =
            await _controller?.evaluateJavascript(source: _watchPrimeTaps);
        if (!mounted || _autoStarted || _creatingRoom) return;
        if (tapped is String && tapped.isNotEmpty) {
          _pickedUrl = tapped;
          _triggerAutoStart(tapped);
          return;
        }
        if (_looksReadyToStart(urlStr)) {
          _pickedUrl = urlStr;
          _triggerAutoStart(urlStr);
          return;
        }
      }
      if (!_isWeb && _looksReadyToStart(urlStr)) {
        // A watch page: go now.
        _triggerAutoStart(urlStr);
        return;
      } else {
        _watchPageSince = null;
      }
      // Prime Video's play button doesn't reliably touch the URL at all —
      // it can open the video as an in-page overlay with no ?autoplay=1
      // ever landing in the address bar and no navigation/history entry
      // either, which every URL-based check above is structurally unable
      // to see (confirmed by user report — selecting Play/Resume just sits
      // on the same page). Falling back to "does a <video> element exist
      // on the page yet" catches that case too — this only checks
      // presence (a plain boolean), never reads, plays, or otherwise
      // touches the element or its content.
      // Netflix plays trailers on its title pages, which aren't a pick:
      // for Netflix only its watch page counts (handled above).
      final playing = widget.platform == 'netflix'
          ? false
          : await _controller?.evaluateJavascript(source: '''
        (function() {
          var vids = Array.from(document.querySelectorAll('video'));
          var frames = document.querySelectorAll('iframe');
          for (var i = 0; i < frames.length; i++) {
            try {
              if (frames[i].contentDocument) {
                vids = vids.concat(Array.from(
                    frames[i].contentDocument.querySelectorAll('video')));
              }
            } catch (e) {}
          }
          var w = window.innerWidth || 1;
          return vids.some(function(v) {
            var r = v.getBoundingClientRect();
            return !v.paused && !v.muted && v.currentTime > 1 &&
                r.width >= w * 0.6;
          });
        })();
      ''');
      if (!mounted || _autoStarted || _creatingRoom) return;
      final now = DateTime.now();
      _playingSince = playing == true ? (_playingSince ?? now) : null;
      _updateCanPin();
      if (_isWeb) return;
      if (playing == true) {
        _playingSince ??= now;
        if (now.difference(_playingSince!) >= _playFor) {
          _triggerAutoStart(urlStr);
        }
        return;
      }
      _playingSince = null;
      final since = _watchPageSince;
      if (since != null && now.difference(since) >= _watchPageFallback) {
        _triggerAutoStart(urlStr);
        return;
      }
      if (widget.platform == 'amazon') {
        // Also checks inside same-origin iframes — Amazon's player can sit
        // in one rather than the top document. A cross-origin iframe would
        // throw here (the browser's own Same-Origin Policy, not anything
        // DRM-specific), which the try/catch just treats as "not found
        // this way" rather than crashing the check.
        final hasVideo = await _controller?.evaluateJavascript(source: '''
          (function() {
            if (document.querySelector('video')) return true;
            var frames = document.querySelectorAll('iframe');
            for (var i = 0; i < frames.length; i++) {
              try {
                if (frames[i].contentDocument &&
                    frames[i].contentDocument.querySelector('video')) {
                  return true;
                }
              } catch (e) {}
            }
            return false;
          })();
        ''');
        // A player on the page counts as a watch page: it gets its 3
        // seconds of playing, or goes back after the fallback wait.
        if (hasVideo == true && mounted) _watchPageSince ??= DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    _urlPoll?.cancel();
    _address.dispose();
    super.dispose();
  }

  bool _looksReadyToStart(String url) {
    if (widget.platform == 'youtube_surf') return extractYouTubeId(url) != null;
    final specific = _platformWatchPatterns[widget.platform];
    if (specific != null) return specific.hasMatch(url);
    return _genericWatchPattern.hasMatch(url);
  }

  // Shared by onLoadStop (real page navigations) and onUpdateVisitedHistory
  // (SPA history.pushState/replaceState — confirmed needed for Prime Video,
  // which reaches its watch state on the same /detail/<id> URL by pushing
  // ?autoplay=1 onto it client-side rather than doing a real navigation;
  // onLoadStop alone would never see that).
  void _maybeAutoStart(String? url) {
    if (_isWeb) return;
    if (_autoStarted || _creatingRoom || url == null) return;
    if (_looksReadyToStart(url)) _triggerAutoStart(url);
  }

  // The actual "we're ready, go" action — split out of _maybeAutoStart so
  // the Amazon DOM-presence fallback in the _urlPoll timer above can invoke
  // it directly without needing the URL to match a pattern first (that
  // fallback exists precisely because the URL sometimes never does).
  void _triggerAutoStart(String url) {
    if (_autoStarted || _creatingRoom) return;
    _autoStarted = true;
    _urlPoll?.cancel();
    // Covers the WebView immediately, before _startHere's own async work
    // (a real network round trip to create the room) even starts — OTT
    // sites attempt real DRM playback the instant this URL lands, which
    // always fails here (this WebView is desktop-UA for browsing; only
    // the room's own player is mobile-UA, see mobile_webview_settings
    // .dart). Without covering it up front, that failure is what's
    // visible for however long the room-creation call takes, instead of
    // a plain loading state.
    setState(() => _creatingRoom = true);
    if (widget.platform == 'amazon') {
      _controller?.evaluateJavascript(
          source: "document.querySelectorAll('video').forEach(function(v) "
              "{ v.muted = true; v.pause(); });");
    }
    _startHere();
  }

  Future<String?> _lookupYoutubeTitle(String videoId) async {
    try {
      final data = await ApiClient.get('/youtube/embed-size?v=$videoId');
      final title = data is Map ? data['title'] as String? : null;
      return (title == null || title.trim().isEmpty) ? null : title.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _startHere() async {
    final controller = _controller;
    // Not a _creatingRoom guard here — the bottom button already disables
    // itself while that's true, and _maybeAutoStart sets it *before*
    // calling this (see its comment), so checking it here would make this
    // whole method a no-op for every auto-triggered call.
    if (controller == null) return;
    final url = await controller.getUrl();
    if (url == null || !mounted) return;

    var sourceType = widget.platform;
    var videoUrl = _pickedUrl ?? url.toString();
    String? videoTitle;
    String? videoThumbnail;
    if (widget.platform == 'youtube_surf' || _isWeb) {
      final videoId = extractYouTubeId(videoUrl);
      if (videoId != null) {
        // Landed on a real video page — upgrade to a normal fully-synced
        // YouTube room instead of a no-sync 'youtube_surf' one. The page's
        // own <title> (usually "Video Name - YouTube") is the cheapest
        // real title available here — no extra YouTube API call needed,
        // and the thumbnail CDN URL is fully predictable from the id.
        sourceType = 'youtube';
        // Opened from a playlist or mix: keep the list for Autoplay.
        videoUrl =
            youtubeWatchUrl(videoId, playlistId: youtubeListId(videoUrl));
        final pageTitle = await controller.getTitle();
        videoTitle = pageTitle
            ?.replaceAll(RegExp(r'\s*-\s*YouTube( Music)?$'), '')
            .trim();
        if (videoTitle?.isEmpty ?? true) videoTitle = null;
        // Mobile YouTube often still reports a bare "YouTube" here (its page
        // title lags the in-app navigation), which would otherwise become
        // the room's title — ask oEmbed for the real one instead.
        if (videoTitle == null ||
            RegExp(r'^YouTube( Music)?$').hasMatch(videoTitle)) {
          videoTitle = await _lookupYoutubeTitle(videoId);
        }
        videoThumbnail = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    }
    if (_isWeb && sourceType == 'web') {
      final page = (await controller.getTitle())?.trim();
      if (page != null && page.isNotEmpty) videoTitle = page;
    }
    if (widget.platform == 'netflix') {
      // "Watch Baththa | Netflix"
      final page = (await controller.getTitle())
          ?.replaceAll(RegExp(r'^Watch\s+|\s*\|\s*Netflix.*$'), '')
          .trim();
      if (page != null && page.isNotEmpty && page != 'Netflix') {
        videoTitle = page;
      }
    }
    if (!mounted) return;
    await _addOrCreate(
        sourceType: sourceType,
        videoUrl: videoUrl,
        videoTitle: videoTitle,
        videoThumbnail: videoThumbnail);
  }

  // Shared tail of both "confirm the current page" (_startHere, via the
  // bottom button) and "long-pressed a video thumbnail while still browsing"
  // (_onLongPressVideo) — same three destinations either way: queue it,
  // hard-replace the room's source, or start a brand new room.
  Future<void> _addOrCreate(
      {required String sourceType,
      required String videoUrl,
      String? videoTitle,
      String? videoThumbnail}) async {
    final onAddToQueue = widget.onAddToQueue;
    if (onAddToQueue != null) {
      setState(() => _creatingRoom = true);
      onAddToQueue(
          videoUrl: videoUrl,
          title: videoTitle ?? widget.label,
          thumbnail: videoThumbnail,
          mediaMode: 'video',
          sourceType: sourceType);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final onConfirmOverride = widget.onConfirmOverride;
    if (onConfirmOverride != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Switch this room\'s source?'),
          content: Text(
              "Everyone in the room will switch to ${widget.label} — this replaces what's currently playing."),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Switch')),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        // Started playing but don't want to switch: go back to the room.
        Navigator.of(context).pop();
        return;
      }
      setState(() => _creatingRoom = true);
      await onConfirmOverride(sourceType, videoUrl,
          videoTitle: videoTitle, videoThumbnail: videoThumbnail);
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
      options: widget.options,
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
  Future<void> _onLongPressVideo(
      InAppWebViewHitTestResult hitTestResult) async {
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
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add')),
          ],
        ),
      );
      if (add != true || !mounted) return;
    }

    setState(() => _creatingRoom = true);
    final fallbackThumbnail =
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
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
      final uri = Uri.parse(
          'https://www.youtube.com/oembed?format=json&url=${Uri.encodeComponent('https://www.youtube.com/watch?v=$videoId')}');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final title = data['title'] as String?;
      final thumbnail = data['thumbnail_url'] as String?;
      return {
        if (title != null && title.isNotEmpty) 'title': title,
        if (thumbnail != null) 'thumbnail': thumbnail
      };
    } catch (_) {
      return null; // Falls back to the predictable CDN thumbnail + widget.label as title.
    }
  }

  String get _hint {
    if (_isWeb) return 'Play a video, then tap Pin to room';
    if (widget.onAddToQueue != null) {
      return 'Press play. After 3 seconds it goes to your room’s queue';
    }
    if (widget.onConfirmOverride != null) {
      return 'Press play. After 3 seconds the room switches to it';
    }
    return 'Press play. After 3 seconds your room opens with it';
  }

  String get _buttonLabel {
    if (widget.onAddToQueue != null) {
      return _creatingRoom ? 'Adding…' : 'Add to queue';
    }
    if (widget.onConfirmOverride != null) {
      return _creatingRoom ? 'Switching…' : 'Switch room to this';
    }
    return _creatingRoom ? 'Starting…' : 'Start watch party here';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _isWeb
          ? AppBar(
              titleSpacing: 0,
              title: TextField(
                controller: _address,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: _go,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search or type a web address',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => _controller?.goBack(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                IconButton(
                  tooltip: 'Reload',
                  onPressed: () => _controller?.reload(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : AppBar(title: Text(widget.label)),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.homeUrl)),
            // Desktop site, fitted to the screen (the Browser can also zoom).
            initialSettings:
                _isWeb ? _browserSettings : desktopWebViewSettings,
            initialUserScripts: UnmodifiableListView([desktopSiteScript]),
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStart: (controller, url) => setState(() {
              _loading = true;
              if (_isWeb) {
                _pageUrl = url?.toString() ?? '';
                _videos = const [];
                _videosSig = '';
                _cardCollapsed = false;
              }
            }),
            // The single-video card shrinks to a pill while you scroll.
            onScrollChanged: (controller, x, y) {
              if (_isWeb && _videos.length == 1 && !_cardCollapsed) {
                setState(() => _cardCollapsed = true);
              }
            },
            onLoadStop: (controller, url) {
              setState(() => _loading = false);
              if (_isWeb && url != null) _address.text = url.toString();
              // Landed on what looks like a real watch/play page — jump
              // straight into the room with it pinned.
              _maybeAutoStart(url?.toString());
            },
            // Catches SPA route changes that never trigger onLoadStop at
            // all — see _maybeAutoStart's comment.
            onUpdateVisitedHistory: (controller, url, isReload) =>
                _maybeAutoStart(url?.toString()),
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
              return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT);
            },
            onLongPressHitTestResult: (controller, hitTestResult) =>
                _onLongPressVideo(hitTestResult),
          ),
          if (_loading)
            const Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(child: Spinner(size: 20))),
          // Covers the WebView the moment a watch page is detected (see
          // _maybeAutoStart) so nobody ever sees the OTT site's own failed
          // playback attempt — this WebView is desktop-UA for browsing,
          // which can't do real DRM (confirmed live, see
          // mobile_webview_settings.dart); only the room's own player,
          // loaded next with mobile-UA settings, actually plays it.
          if (_creatingRoom)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.bg,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spinner(size: 28),
                      const SizedBox(height: 12),
                      Text(_buttonLabel,
                          style: const TextStyle(color: AppColors.textDim)),
                    ],
                  ),
                ),
              ),
            ),
          // Browser: one video floats as a card; two or more sit in a tray.
          if (_isWeb && !_creatingRoom && _videos.length == 1 &&
              !_videos.first.locked && _dismissedFor != _pageUrl)
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: Center(
                child: BrowserVideoCard(
                  video: _videos.first,
                  collapsed: _cardCollapsed,
                  onWatch: () => _pickVideos(_videos),
                  onExpand: () => setState(() => _cardCollapsed = false),
                  onClose: () => setState(() => _dismissedFor = _pageUrl),
                ),
              ),
            ),
          if (_isWeb && !_creatingRoom && _videos.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BrowserVideoTray(
                videos: _videos,
                inRoom: widget.onAddToQueue != null,
                onPick: _pickVideos,
              ),
            ),
          // Playing a title pins it to the room after 3 seconds (see
          // _urlPoll); the button does it straight away.
          if (!_creatingRoom && !_isWeb)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _canPin
                  ? FilledButton.icon(
                      onPressed: () async {
                        final url = await _controller?.getUrl();
                        if (url != null) _triggerAutoStart(url.toString());
                      },
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: const StadiumBorder()),
                      icon: const InIcon(InIcons.pin,
                          size: 18, color: Colors.white),
                      label: const Text('Pin to room'),
                    )
                  : IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const InIcon(InIcons.play,
                              size: 15, color: Colors.white, filled: true),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(_hint,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12.5)),
                          ),
                        ]),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
