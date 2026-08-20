import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Real Android Picture-in-Picture — a native Activity-level window mode
/// change, not something achievable in pure Dart. See MainActivity.kt's
/// PIP channel. Only meaningful when actually leaving the app (home
/// button, switching to another app) — Android has no equivalent concept
/// for navigating between screens *within* one Flutter app, since that's
/// all a single Activity to it.
class PipService {
  static const _channel = MethodChannel('com.fling.app/pip');

  static final ValueNotifier<bool> isInPip = ValueNotifier(false);

  static bool _listening = false;
  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        isInPip.value = call.arguments as bool? ?? false;
      }
    });
  }

  /// party_screen.dart calls this true while a watch-party video is up, and
  /// false on dispose — so pressing home only pops into PIP when there's
  /// actually something worth watching in the little window, not from
  /// every screen in the app.
  static Future<void> setAutoPipEnabled(bool enabled) async {
    _ensureListening();
    try {
      await _channel.invokeMethod('setAutoPipEnabled', {'enabled': enabled});
    } on PlatformException {
      // iOS/other platforms have no handler registered for this channel —
      // harmless no-op there.
    } on MissingPluginException {
      // ignore
    }
  }

  /// Manual trigger, e.g. a "PIP" button in the room's UI, separate from
  /// the automatic on-leave behavior above.
  static Future<bool> enterPip() async {
    _ensureListening();
    // Set optimistically, not just via the onPipModeChanged callback above
    // — confirmed live: entering PIP triggers Flutter's own
    // didChangeAppLifecycleState(inactive) around the same moment, and
    // that arrives synchronously while onPipModeChanged has to make an
    // extra native round trip first. The video players' backgrounded
    // guards (see sync_video_player.dart / drive_video_player.dart) check
    // isInPip at that exact instant, so if it's still false because the
    // round trip hasn't landed yet, they wrongly treat entering PIP as a
    // real background and pause — this is why PIP was pausing the video
    // the moment it opened.
    isInPip.value = true;
    try {
      final entered = await _channel.invokeMethod<bool>('enterPip') ?? false;
      if (!entered) isInPip.value = false;
      return entered;
    } on PlatformException {
      isInPip.value = false;
      return false;
    } on MissingPluginException {
      isInPip.value = false;
      return false;
    }
  }

  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isPipSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
