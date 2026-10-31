import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Inside a room the phone's volume buttons change the volume without
/// Android's on-screen bar; [level] drives a small line that fades instead,
/// so you can still see how loud it is. See MainActivity.dispatchKeyEvent.
class VolumeKeys {
  static const _channel = MethodChannel('com.fling.app/volume_keys');

  /// 0 to 1 just after a press, null once it has faded.
  static final level = ValueNotifier<double?>(null);
  static int _press = 0;
  static bool _listening = false;

  static Future<void> setEnabled(bool on) async {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'changed') return;
        level.value = (call.arguments as num).toDouble();
        final mine = ++_press;
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mine == _press) level.value = null;
      });
    }
    try {
      await _channel.invokeMethod('setEnabled', on);
    } catch (_) {
      // Android's own bar keeps working where this isn't available.
    }
  }
}
