import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/mobile_webview_settings.dart';
import '../../theme/app_colors.dart';

/// Netflix/Prime "browse together" sibling of sync_video_player.dart /
/// drive_video_player.dart — but unlike those two, there is NO sync
/// contract here at all (no onPlay/onPause/onSeek, no host-vs-guest
/// distinction). DRM blocks reading play/pause/seek state from either
/// platform's video element, so there's nothing to synchronize; this just
/// keeps everyone's WebView pointed at the same URL the host started the
/// room with. Room chat/mic/queue keep working normally alongside it —
/// only the video itself isn't sync-able.
class WebviewRoomPlayer extends StatefulWidget {
  final String? videoUrl;
  final String? title;
  final bool compact;

  const WebviewRoomPlayer({super.key, required this.videoUrl, this.title, this.compact = false});

  @override
  State<WebviewRoomPlayer> createState() => _WebviewRoomPlayerState();
}

class _WebviewRoomPlayerState extends State<WebviewRoomPlayer> {
  @override
  Widget build(BuildContext context) {
    final url = widget.videoUrl;
    if (url == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: AppColors.surface2, alignment: Alignment.center, child: const Text('No video', style: TextStyle(color: AppColors.textFaint))),
      );
    }
    // No rounded-corner card/box — the video now runs edge-to-edge at full
    // screen width right under the header, so a "boxed" look doesn't apply.
    return AspectRatio(
      aspectRatio: widget.compact ? 21 / 9 : 16 / 9,
      child: ClipRect(
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
                  return PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT);
                },
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: Colors.black54,
                child: const Text(
                  "No auto-sync here — everyone presses play together.",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
