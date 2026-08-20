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

/// Same WebView, presented as desktop Chrome instead of mobile Chrome.
/// Netflix/Prime/Hotstar and similar OTT sites detect the mobile UA and
/// push an "open in our app" interstitial that a WebView can't dismiss
/// (there's no app to hand off to) — their desktop site skips that
/// entirely and goes straight to browsing.
///
/// Browsing/catalog pages only — NOT for actual DRM video playback.
/// Confirmed live: using this for the in-room player breaks Netflix
/// (error M7701-1003) because the WebView's Widevine path only works when
/// the site thinks it's mobile Chrome. See webview_room_player.dart, which
/// deliberately stays on [mobileWebViewSettings] for that reason. The
/// sign-in bot-detection limitation documented in webview_browse_screen.dart
/// is unrelated to either UA choice.
final desktopWebViewSettings = InAppWebViewSettings(
  useWideViewPort: true,
  loadWithOverviewMode: true,
  javaScriptEnabled: true,
  domStorageEnabled: true,
  userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
);
