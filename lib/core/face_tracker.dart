import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Where a face is in an upright, unmirrored picture. [x], [y] are the point
/// between the eyes and [width] the face's width, all as fractions of the
/// picture's width or height; [angle] is its tilt in radians, clockwise.
class FacePose {
  final double x;
  final double y;
  final double width;
  final double angle;
  const FacePose(this.x, this.y, this.width, this.angle);

  /// Eases towards [next] so stickers don't shake with the tracker's noise.
  FacePose smoothedTo(FacePose next, {double amount = 0.55}) => FacePose(
        x + (next.x - x) * amount,
        y + (next.y - y) * amount,
        width + (next.width - width) * amount,
        angle + (next.angle - angle) * amount,
      );

  List<double> toRow(int ms) => [ms.toDouble(), x, y, width, angle];
}

/// Finds the face on the phone itself (FaceFilterChannel.kt); no picture
/// leaves it. Android only for now, like the rest of the video editing.
class FaceTracker {
  static const _channel = MethodChannel('com.fling.app/face_filter');

  static bool get supported => Platform.isAndroid;

  bool _busy = false;
  int _lastMs = 0;

  /// Longest wait between frames we look at, about 15 a second.
  static const _gapMs = 66;

  /// Null when the frame was skipped or shows no face.
  Future<FacePose?> detect(CameraImage image, int sensorOrientation) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_busy || now - _lastMs < _gapMs) return null;
    _busy = true;
    _lastMs = now;
    try {
      final luma = image.planes.first;
      final out = await _channel.invokeMethod<List<Object?>>('detect', {
        'luma': Uint8List.fromList(luma.bytes),
        'width': image.width,
        'height': image.height,
        'rowStride': luma.bytesPerRow,
        'rotation': sensorOrientation,
        'timeMs': now,
      });
      if (out == null) return null;
      final v = out.cast<num>();
      return FacePose(v[0].toDouble(), v[1].toDouble(), v[2].toDouble(),
          v[3].toDouble());
    } finally {
      _busy = false;
    }
  }

  static Future<void> release() => _channel.invokeMethod<void>('release');

  /// Null when the photo has no face to put the sticker on.
  static Future<String?> bakePhoto(
          {required String input, required String sticker}) =>
      _channel.invokeMethod<String>(
          'bakePhoto', {'input': input, 'sticker': sticker});

  /// [track] holds one [FacePose.toRow] per tracked moment of the clip.
  static Future<String> bakeVideo({
    required String input,
    required String sticker,
    required List<List<double>> track,
  }) async {
    final out = await _channel.invokeMethod<String>('bakeVideo', {
      'input': input,
      'sticker': sticker,
      'track': track,
    });
    return out!;
  }
}
