import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this device has Widevine, the copy protection Netflix, Prime,
/// Hotstar and similar services need to play. Asked once from Android
/// (MainActivity.kt) and remembered. Anywhere it can't be asked (iOS,
/// tests) counts as supported, so nothing is hidden by mistake.
class DrmSupport {
  static const _channel = MethodChannel('com.fling.app/drm');
  static Future<bool>? _widevine;

  static Future<bool> hasWidevine() => _widevine ??= _ask();

  static Future<bool> _ask() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('hasWidevine') ?? true;
    } catch (_) {
      return true;
    }
  }
}
