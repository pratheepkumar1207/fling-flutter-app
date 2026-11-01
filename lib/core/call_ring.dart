import 'package:flutter/services.dart';

/// Ringing around a call (CallRingChannel.kt). A phone that can't ring still
/// takes the call, so failures are ignored.
class CallRing {
  static const _channel = MethodChannel('com.fling.app/call_ring');

  static Future<void> _send(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  /// The phone's ringtone and vibration, for a call coming in.
  static Future<void> incoming() => _send('incoming');

  /// The tone a caller hears while the other phone rings.
  static Future<void> ringback() => _send('ringback');

  static Future<void> stop() => _send('stop');

  /// Answered or gone: stops any notification and lets the lock screen back.
  static Future<void> callFinished() => _send('callFinished');

  /// A call opened from its notification, if there's one waiting.
  static Future<Map<String, dynamic>?> pendingCall() async {
    try {
      final call = await _channel.invokeMethod<Map>('pendingCall');
      return call == null ? null : Map<String, dynamic>.from(call);
    } on PlatformException catch (_) {
      return null;
    } on MissingPluginException catch (_) {
      return null;
    }
  }

  /// [onOpened] runs when a call's notification is opened while running.
  static void listen(VoidCallback onOpened) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'callOpened') onOpened();
    });
  }
}
