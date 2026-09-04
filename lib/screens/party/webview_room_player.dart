import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/mobile_webview_settings.dart';
import '../../theme/app_colors.dart';

/// Netflix/Prime "browse together" sibling of sync_video_player.dart /
/// drive_video_player.dart. Unlike those two there is still no *real* sync
/// contract — DRM (Widevine) blocks any script, including this WebView's
/// own JS, from reading or controlling the actual video element inside a
/// cross-origin, DRM-protected page. That's a hard platform boundary, not
/// a missing feature — see https://rave.io (a real, popular watch-party
/// app) confirming the exact same constraint: "Every single person has to
/// sign into their own Netflix account... No screen sharing at all."
///
/// What this DOES provide, reusing the same playback:play/pause/state
/// socket channel the YouTube/Drive players already use (see
/// room_socket_controller.dart's play/pause/playback, unchanged on the
/// backend — this just treats `position` as an approximate elapsed-time
/// clock instead of a real, seekable video position):
///  - An elapsed-time estimate ("Room is ~10:30 in") so someone joining
///    late knows roughly where to manually scrub to in their own player.
///  - Host-only Play/Pause buttons that broadcast a "please press play/
///    pause too" nudge banner to everyone else — a coordination aid, not
///    remote control. Each participant still has to tap their own video.
///  - A simple heuristic ("does the current URL look like a login page?")
///    to nudge someone who hasn't signed into this platform yet.
class WebviewRoomPlayer extends StatefulWidget {
  final String? videoUrl;
  final String? title;
  final bool compact;
  // When true, fills whatever box the parent gives it (party_screen.dart's
  // immersive OTT layout hands this an Expanded slot) instead of boxing
  // itself into a 16:9/21:9 crop. Unlike YouTube/Drive, this player is a
  // whole embedded website, not a single video element — letting it use the
  // full available space (not just full width) is a truer "full view" for
  // it than an artificial aspect-ratio crop would be.
  final bool fillHeight;
  final bool isHost;
  final Map<String, dynamic>? playback;
  final void Function(double position) onPlay;
  final void Function(double position) onPause;
  final VoidCallback onRequestState;
  // Same skip contract as sync_video_player.dart/drive_video_player.dart —
  // "skip" here just means "move to the next queued item" (a real,
  // well-defined queue operation) rather than anything about the current
  // item's playback position, which OTT never had control over anyway.
  // isHost gets onSkip (always immediate); everyone else gets onVoteSkip,
  // same "one consistent player control" treatment across every source.
  final VoidCallback? onSkip;
  final VoidCallback? onVoteSkip;
  final int skipVoteCount;
  final int skipVoteRequired;

  const WebviewRoomPlayer({
    super.key,
    required this.videoUrl,
    this.title,
    this.compact = false,
    this.fillHeight = false,
    required this.isHost,
    required this.playback,
    required this.onPlay,
    required this.onPause,
    required this.onRequestState,
    this.onSkip,
    this.onVoteSkip,
    this.skipVoteCount = 0,
    this.skipVoteRequired = 1,
  });

  @override
  State<WebviewRoomPlayer> createState() => _WebviewRoomPlayerState();
}

class _WebviewRoomPlayerState extends State<WebviewRoomPlayer> {
  InAppWebViewController? _controller;
  Timer? _tickTimer;
  Timer? _nudgeDismissTimer;
  String? _nudgeBanner;
  bool _onLoginPage = false;

  @override
  void initState() {
    super.initState();
    // Same as the YouTube/Drive players — ask the room for the current
    // state on join so a late joiner's elapsed-time estimate starts
    // correct instead of at zero.
    if (!widget.isHost) widget.onRequestState();
    // Forces the elapsed-time display to keep advancing even when no new
    // playback:state has arrived — purely cosmetic, doesn't affect
    // anything sent to the backend.
    _tickTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant WebviewRoomPlayer old) {
    super.didUpdateWidget(old);
    final wasPlaying = old.playback?['isPlaying'] as bool?;
    final isPlaying = widget.playback?['isPlaying'] as bool?;
    if (!widget.isHost && isPlaying != null && isPlaying != wasPlaying) {
      _showNudge(isPlaying
          ? 'Host pressed play — press play in your app too'
          : 'Host paused — pause yours too');
    }
  }

  void _showNudge(String text) {
    _nudgeDismissTimer?.cancel();
    setState(() => _nudgeBanner = text);
    _nudgeDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _nudgeBanner = null);
    });
  }

  // Not a real video position — position + elapsed wall-clock time since
  // the host's last play/pause, same correction pattern
  // sync_video_player.dart/drive_video_player.dart use for the real thing.
  // Purely a display estimate; nothing here can seek anyone's actual video.
  double get _elapsedSeconds {
    final p = widget.playback;
    if (p == null) return 0;
    var position = (p['position'] as num?)?.toDouble() ?? 0;
    final updatedAt = p['updatedAt'] == null ? null : (p['updatedAt'] as num);
    if (p['isPlaying'] == true && updatedAt != null) {
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - updatedAt) / 1000;
      if (elapsed > 0) position += elapsed;
    }
    return position;
  }

  bool get _isPlaying => widget.playback?['isPlaying'] == true;

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _hostTogglePlay() {
    if (_isPlaying) {
      widget.onPause(_elapsedSeconds);
    } else {
      widget.onPlay(_elapsedSeconds);
    }
  }

  // Best-effort only — platforms don't expose a stable "you're logged out"
  // signal, so this just looks for the obvious login/signin URL patterns
  // most of them share.
  void _checkLoginUrl(Uri? url) {
    final path = url?.toString().toLowerCase() ?? '';
    final looksLikeLogin = path.contains('login') ||
        path.contains('signin') ||
        path.contains('sign-in');
    if (looksLikeLogin != _onLoginPage) {
      setState(() => _onLoginPage = looksLikeLogin);
    }
  }

  // Asks the page's own <video> element to go fullscreen, so the site's
  // surrounding chrome (nav bar, recommendations, search UI — whatever page
  // the room's URL happens to be) visually disappears and only the video
  // itself is left on screen. NOT guaranteed to work: browsers generally
  // require the Fullscreen API to be triggered by a genuine on-page user
  // gesture, and a script injected from Flutter isn't always treated as
  // one — this is the best available attempt without DRM-level access to
  // the video itself, but confirm on a real device before relying on it.
  Future<void> _requestFullscreen() async {
    await _controller?.evaluateJavascript(source: '''
      (function() {
        var v = document.querySelector('video');
        if (v && v.requestFullscreen) { v.requestFullscreen(); }
        else if (v && v.webkitRequestFullscreen) { v.webkitRequestFullscreen(); }
      })();
    ''');
  }

  // Pins the page's own <video> element edge-to-edge over everything else,
  // via plain CSS rather than the Fullscreen API above — confirmed live:
  // on non-DRM sites (Aha, and similar), the page stays in its normal
  // in-page layout (header, related-videos, description text) around a
  // centered player instead of filling the screen, leaving visible "extra
  // space" around the actual video. CSS positioning doesn't need a genuine
  // user gesture the way requestFullscreen does, so it applies
  // automatically on load instead of waiting for a tap. Content-only
  // styling — doesn't read or control playback state, so it's a no-op on
  // DRM pages (Netflix/Prime) whose player isn't a plain <video> tag in
  // the same way; harmless to run there regardless.
  Future<void> _injectFullBleedVideoCss() async {
    await _controller?.evaluateJavascript(source: '''
      (function() {
        if (document.getElementById('__fling_fullbleed__')) return;
        var style = document.createElement('style');
        style.id = '__fling_fullbleed__';
        style.innerHTML = `
          video {
            position: fixed !important;
            top: 0 !important; left: 0 !important;
            width: 100vw !important; height: 100vh !important;
            object-fit: contain !important;
            background: #000 !important;
            z-index: 2147483647 !important;
          }
          html, body { overflow: hidden !important; margin: 0 !important; padding: 0 !important; }
        `;
        document.head.appendChild(style);
      })();
    ''');
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _nudgeDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.videoUrl;
    if (url == null) {
      final placeholder = Container(
          color: AppColors.surface2,
          alignment: Alignment.center,
          child: const Text('No video',
              style: TextStyle(color: AppColors.textFaint)));
      return widget.fillHeight
          ? SizedBox.expand(child: placeholder)
          : AspectRatio(aspectRatio: 16 / 9, child: placeholder);
    }
    // No rounded-corner card/box — the video now runs edge-to-edge at full
    // screen width right under the header, so a "boxed" look doesn't apply.
    final webview = ClipRect(
        child: Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          // Mobile UA here, not desktop: actual DRM video playback
          // (Widevine) only works reliably in this WebView when Netflix
          // thinks it's talking to mobile Chrome — a desktop UA makes it
          // pick a playback path the WebView can't fulfill, surfacing as
          // Netflix error M7701-1003 (confirmed live). Desktop mode stays
          // on the browse/catalog screen (no DRM decode happens there);
          // only the actual playback WebView needs to stay mobile.
          initialSettings: mobileWebViewSettings,
          onWebViewCreated: (controller) => _controller = controller,
          onLoadStop: (controller, url) {
            _checkLoginUrl(url);
            _injectFullBleedVideoCss();
          },
          // Same "don't error out on a custom app-deeplink scheme" guard
          // as webview_browse_screen.dart — see its comment for why.
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final scheme = navigationAction.request.url?.scheme;
            if (scheme != null && scheme != 'http' && scheme != 'https') {
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          // Android WebView denies DRM (Widevine) permission requests by
          // default — without granting this, Netflix/Prime's player
          // can't initialize EME at all and fails with a generic
          // HTML5-player error (confirmed live: Netflix's M7701-1003)
          // regardless of user agent or anything else being right.
          onPermissionRequest: (controller, request) async {
            return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT);
          },
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _requestFullscreen,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle),
              child: const Icon(Icons.fullscreen_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        if (_onLoginPage)
          Positioned(
            top: 8,
            left: 8,
            right: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text(
                'Log in here, then come back to catch up with the room.',
                style: TextStyle(color: Colors.white, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (_nudgeBanner != null)
          Positioned(
            top: 44,
            left: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _nudgeBanner!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                Row(
                  children: [
                    if (widget.isHost)
                      GestureDetector(
                        onTap: _hostTogglePlay,
                        child: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 22),
                      ),
                    if (widget.isHost) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isHost
                            ? 'Tap play/pause to nudge everyone — room is at ${_formatTime(_elapsedSeconds)}'
                            : 'Room is roughly ${_formatTime(_elapsedSeconds)} in — scrub to match, then press play together.',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Same skip control every source's player shows now — host
                    // gets an immediate skip to the next queued item, everyone
                    // else gets the same vote-to-skip pill YouTube/Drive use.
                    if (widget.isHost && widget.onSkip != null)
                      GestureDetector(
                        onTap: widget.onSkip,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.skip_next_rounded,
                              color: Colors.white, size: 20),
                        ),
                      )
                    else if (!widget.isHost && widget.onVoteSkip != null)
                      GestureDetector(
                        onTap: widget.onVoteSkip,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.skip_next_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.skipVoteCount}/${widget.skipVoteRequired}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ));
    return widget.fillHeight
        ? SizedBox.expand(child: webview)
        : AspectRatio(
            aspectRatio: widget.compact ? 21 / 9 : 16 / 9, child: webview);
  }
}
