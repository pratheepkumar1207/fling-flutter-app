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
class WebviewRoomPlayer extends StatelessWidget {
  final String? videoUrl;
  final String? title;
  final bool compact;

  const WebviewRoomPlayer({super.key, required this.videoUrl, this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final url = videoUrl;
    if (url == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: AppColors.surface2, alignment: Alignment.center, child: const Text('No video', style: TextStyle(color: AppColors.textFaint))),
      );
    }
    return AspectRatio(
      aspectRatio: compact ? 21 / 9 : 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(url)),
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
