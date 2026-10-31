import 'dart:ui' show ColorFilter;

import 'package:flutter/services.dart';

/// A look for a clip or photo. [matrix] is a 3x3 colour matrix, by row;
/// the camera previews it live and Android bakes it into the saved file.
class MediaFilter {
  final String name;
  final List<double>? matrix;
  final bool cartoon;
  const MediaFilter(this.name, {this.matrix, this.cartoon = false});

  /// Null when this filter can't be previewed on a live picture.
  ColorFilter? get preview {
    final m = matrix;
    if (m == null) return null;
    return ColorFilter.matrix([
      m[0], m[1], m[2], 0, 0, //
      m[3], m[4], m[5], 0, 0, //
      m[6], m[7], m[8], 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  static const none = MediaFilter('Normal');
  static const cartoonLook = MediaFilter('Cartoon', cartoon: true);

  static const colour = [
    none,
    MediaFilter('Warm', matrix: [1.1, 0, 0, 0, 1, 0, 0, 0, 0.88]),
    MediaFilter('Cool', matrix: [0.9, 0, 0, 0, 1, 0, 0, 0, 1.12]),
    MediaFilter('Vivid', matrix: [
      1.25, -0.2, -0.05, //
      -0.08, 1.15, -0.07, //
      -0.08, -0.2, 1.28,
    ]),
    MediaFilter('B&W', matrix: [
      0.299, 0.587, 0.114, //
      0.299, 0.587, 0.114, //
      0.299, 0.587, 0.114,
    ]),
    MediaFilter('Vintage', matrix: [
      0.6, 0.35, 0.1, //
      0.2, 0.7, 0.1, //
      0.15, 0.25, 0.55,
    ]),
    MediaFilter('Fade', matrix: [
      0.75, 0.15, 0.05, //
      0.1, 0.8, 0.05, //
      0.1, 0.15, 0.7,
    ]),
  ];

  static const all = [...colour, cartoonLook];
}

/// Edits on the phone itself (VideoEditChannel.kt); nothing leaves it here.
class VideoEdit {
  static const _channel = MethodChannel('com.fling.app/video_edit');

  /// Longest clip that fits the current upload limit at this quality.
  static const maxClip = Duration(seconds: 30);

  static Future<String> processVideo({
    required String input,
    required Duration start,
    required Duration end,
    required MediaFilter filter,
    bool mute = false,
  }) async {
    final out = await _channel.invokeMethod<String>('processVideo', {
      'input': input,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
      'matrix': filter.matrix,
      'cartoon': filter.cartoon,
      'mute': mute,
    });
    return out!;
  }

  static Future<String> processPhoto(
      {required String input, required MediaFilter filter}) async {
    final out = await _channel.invokeMethod<String>('processPhoto', {
      'input': input,
      'matrix': filter.matrix,
      'cartoon': filter.cartoon,
    });
    return out!;
  }
}
