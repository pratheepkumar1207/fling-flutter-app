import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'snap_lenses.dart';

/// One Snap lens, as listed by Camera Kit.
class SnapLens {
  final String id;
  final String groupId;
  final String name;
  final String? icon;
  const SnapLens(
      {required this.id, required this.groupId, required this.name, this.icon});

  factory SnapLens.fromMap(Map m) => SnapLens(
        id: m['id'] as String,
        groupId: m['groupId'] as String? ?? '',
        name: (m['name'] as String?)?.trim().isNotEmpty == true
            ? m['name'] as String
            : 'Lens',
        icon: m['icon'] as String?,
      );
}

/// A camera frame with the lens on, for sending into a call.
class SnapFrame {
  final int width;
  final int height;
  final Uint8List rgba;
  const SnapFrame(this.width, this.height, this.rgba);
}

/// Snap lenses inside our own screens (SnapLensEngine.kt): the camera shows
/// in a [textureId] Texture under our buttons, and with [startFrames] its
/// frames can go into an Agora call. Android only.
class SnapLensEngine {
  SnapLensEngine._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'videoDone') {
        _videoDone?.complete(call.arguments as String?);
        _videoDone = null;
      }
    });
    _frames.setMessageHandler((data) async {
      if (data == null || data.lengthInBytes < 8) return ByteData(0);
      final w = data.getInt32(0);
      final h = data.getInt32(4);
      _frameOut.add(SnapFrame(
          w, h, data.buffer.asUint8List(data.offsetInBytes + 8, w * h * 4)));
      return ByteData(0);
    });
  }

  static final SnapLensEngine instance = SnapLensEngine._();

  static const _channel = MethodChannel('com.fling.app/snap_engine');
  static const _frames =
      BasicMessageChannel<ByteData>('com.fling.app/snap_frames', BinaryCodec());

  final _frameOut = StreamController<SnapFrame>.broadcast();
  Completer<String?>? _videoDone;

  /// Which lens is on (null: none), for anyone showing the lens row.
  final ValueNotifier<SnapLens?> current = ValueNotifier(null);

  List<SnapLens> _lenses = const [];
  List<SnapLens> get lenses => _lenses;

  bool? _supported;

  /// True on Android with a Camera Kit token, lens groups and a phone that
  /// can run lenses.
  Future<bool> supported() async {
    if (!Platform.isAndroid || SnapLenses.groupIds.isEmpty) return false;
    try {
      return _supported ??=
          await _channel.invokeMethod<bool>('supported') ?? false;
    } on MissingPluginException {
      return _supported = false;
    } on PlatformException {
      return _supported = false;
    }
  }

  /// Starts the lens camera; returns the Flutter texture id to show.
  Future<int> start(
      {bool front = true, int width = 720, int height = 1280}) async {
    final r = await _channel.invokeMapMethod<String, Object?>(
        'start', {'front': front, 'width': width, 'height': height});
    if (_lenses.isEmpty) await loadLenses();
    final lens = current.value;
    if (lens != null) await apply(lens);
    return r!['textureId'] as int;
  }

  /// The lens list (works without the camera running).
  Future<List<SnapLens>> loadLenses() async {
    if (_lenses.isNotEmpty) return _lenses;
    final list = await _channel
        .invokeListMethod<Map>('lenses', {'groupIds': SnapLenses.groupIds});
    return _lenses = (list ?? const []).map(SnapLens.fromMap).toList();
  }

  Future<void> stop() async {
    current.value = null;
    await _channel.invokeMethod('stop');
  }

  /// Turns [lens] on; null turns lenses off.
  Future<bool> apply(SnapLens? lens) async {
    current.value = lens;
    return await _channel.invokeMethod<bool>('apply', {'id': lens?.id}) ??
        false;
  }

  Future<bool> flip() async =>
      await _channel.invokeMethod<bool>('flip') ?? true;

  Future<void> flash(bool on) => _channel.invokeMethod('flash', {'on': on});

  /// A photo with the lens on; the JPEG's path.
  Future<String> takePhoto() async =>
      (await _channel.invokeMethod<String>('takePhoto'))!;

  Future<void> startVideo() async {
    _videoDone = Completer<String?>();
    await _channel.invokeMethod('startVideo');
  }

  /// Stops recording; the clip's path once it's written.
  Future<String?> stopVideo() async {
    final done = _videoDone;
    await _channel.invokeMethod('stopVideo');
    return done?.future
        .timeout(const Duration(seconds: 15), onTimeout: () => null);
  }

  /// Lens frames for a call, about [fps] a second.
  Stream<SnapFrame> get frames => _frameOut.stream;

  Future<void> startFrames({int width = 480, int height = 640, int fps = 15}) =>
      _channel.invokeMethod(
          'startFrames', {'width': width, 'height': height, 'fps': fps});

  Future<void> stopFrames() => _channel.invokeMethod('stopFrames');

  // ---- saved lenses (this phone only)

  static const _savedKey = 'snap_saved_lenses';

  Future<Set<String>> savedIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_savedKey) ?? const []).toSet();
  }

  Future<void> toggleSaved(String id) async {
    final p = await SharedPreferences.getInstance();
    final ids = (p.getStringList(_savedKey) ?? <String>[]).toList();
    ids.contains(id) ? ids.remove(id) : ids.insert(0, id);
    await p.setStringList(_savedKey, ids);
  }
}
