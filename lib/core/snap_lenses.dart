import 'dart:io';

import 'package:flutter/services.dart';

/// A photo or clip taken in Snap's lens camera.
class SnapCapture {
  final String path;
  final bool isVideo;
  const SnapCapture(this.path, {required this.isVideo});
}

/// Real Snapchat lenses through Snap Camera Kit (SnapLensChannel.kt), opened
/// as Snap's own camera screen. Our own face filters stay the default; this
/// is the extra "Snap" tile in the camera's face tray. Android only for now,
/// like the face filters.
///
/// Needs two things from the Snap developer portal before the tile shows:
/// - the API token, in android/local.properties as snap.camerakit.apiToken
///   (a staging token works but puts a Snap watermark on the camera)
/// - at least one Lens Group ID (My Lenses → Lens Scheduler), in [groupIds]
class SnapLenses {
  static const _channel = MethodChannel('com.fling.app/snap_lenses');

  /// Lens groups shown in Snap's lens carousel, e.g. 'a1b2c3d4-…'.
  /// For now: Snap's "Camera Kit Mobile Sample Lenses" group. Swap in an
  /// InSync group of our own lenses once it exists in Lens Scheduler.
  static const List<String> groupIds = [
    '171b40cc-2807-445e-816b-900a1945847b',
  ];

  static bool? _configured;

  /// Whether the "Snap" tile should show: on Android, with a token and groups.
  static Future<bool> available() async {
    if (!Platform.isAndroid || groupIds.isEmpty) return false;
    try {
      return _configured ??=
          await _channel.invokeMethod<bool>('isConfigured') ?? false;
    } on MissingPluginException {
      return _configured = false;
    }
  }

  /// Opens Snap's lens camera; null if the person backs out without a shot.
  static Future<SnapCapture?> open({bool frontCamera = true}) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
        'open', {'groupIds': groupIds, 'frontCamera': frontCamera});
    final path = result?['path'] as String?;
    if (path == null) return null;
    return SnapCapture(path, isVideo: result?['isVideo'] == true);
  }
}
