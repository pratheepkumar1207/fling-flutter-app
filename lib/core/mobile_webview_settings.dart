import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Shared settings for every embedded "browse together" WebView (source
/// picker + in-room player — see lobby/webview_browse_screen.dart and
/// party/webview_room_player.dart). Fixes a real, common Android WebView
/// rendering bug, unrelated to anything about login/bot-detection: unlike
/// a normal mobile browser, Android's WebView doesn't auto-fit pages to
/// the screen by default, so a genuinely responsive site can still render
/// as a zoomed-out desktop layout inside a WebView. useWideViewPort +
/// loadWithOverviewMode are the standard fix. The user agent here
/// truthfully describes what this actually is — a mobile Android Chrome
/// WebView — so sites branch to their mobile-responsive layout instead of
/// their desktop one; it doesn't misrepresent the browser as anything it
/// isn't, and has nothing to do with the sign-in bot-detection limitation
/// documented in webview_browse_screen.dart (that's about identity/fraud
/// scoring at login, this is about CSS layout selection).
final mobileWebViewSettings = InAppWebViewSettings(
  useWideViewPort: true,
  loadWithOverviewMode: true,
  javaScriptEnabled: true,
  domStorageEnabled: true,
  userAgent: 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
);
