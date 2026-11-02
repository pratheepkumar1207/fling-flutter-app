import 'dart:ui' show ColorFilter;

import 'package:flutter/services.dart';

/// A look for a clip or photo. [matrix] is a 3x3 colour matrix, by row;
/// the camera previews it live and Android bakes it into the saved file.
class MediaFilter {
  final String name;
  final List<double>? matrix;
  final bool cartoon;

  /// Added to each colour, as a share of full brightness.
  final double offset;
  const MediaFilter(this.name,
      {this.matrix, this.cartoon = false, this.offset = 0});

  /// This filter with the Adjust sliders applied, each -1 to 1.
  MediaFilter adjusted(
      {double brightness = 0,
      double contrast = 0,
      double warmth = 0,
      double saturation = 0,
      double fade = 0}) {
    if (brightness == 0 &&
        contrast == 0 &&
        warmth == 0 &&
        saturation == 0 &&
        fade == 0) {
      return this;
    }
    final base = matrix ?? const [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
    final c = (1 + contrast * .6) * (1 - fade * .35);
    final s = 1 + saturation;
    const lr = 0.299, lg = 0.587, lb = 0.114;
    final sat = [
      lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), //
      lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), //
      lr * (1 - s), lg * (1 - s), lb * (1 - s) + s,
    ];
    final warm = [1 + warmth * .18, 1.0, 1 - warmth * .18];
    final out = List<double>.filled(9, 0);
    for (var r = 0; r < 3; r++) {
      for (var col = 0; col < 3; col++) {
        var v = 0.0;
        for (var k = 0; k < 3; k++) {
          v += sat[r * 3 + k] * base[k * 3 + col];
        }
        out[r * 3 + col] = v * c * warm[r];
      }
    }
    return MediaFilter(name,
        matrix: out,
        cartoon: cartoon,
        offset: offset + brightness * .25 + (1 - c) * .5);
  }

  /// Null when this filter can't be previewed on a live picture.
  ColorFilter? get preview {
    final m = matrix;
    if (m == null) return null;
    return ColorFilter.matrix([
      m[0], m[1], m[2], 0, offset * 255, //
      m[3], m[4], m[5], 0, offset * 255, //
      m[6], m[7], m[8], 0, offset * 255, //
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
    double speed = 1,
    double volume = 1,
    String? overlay,
  }) async {
    final out = await _channel.invokeMethod<String>('processVideo', {
      'input': input,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
      'matrix': filter.matrix,
      'cartoon': filter.cartoon,
      'mute': mute,
      'speed': speed,
      'volume': volume,
      'offset': filter.offset,
      'overlay': overlay,
    });
    return out!;
  }

  /// A small picture from a clip, for its cover.
  static Future<String> videoFrame(
      {required String input, required Duration at}) async {
    final out = await _channel.invokeMethod<String>(
        'videoFrame', {'input': input, 'atMs': at.inMilliseconds});
    return out!;
  }

  /// Saves to the phone's gallery. [overlay] is a transparent PNG of a story's
  /// stickers; [storyShape] crops to the story's 9:16 first, so they line up.
  static Future<void> saveToGallery({
    required String input,
    required bool isVideo,
    String? overlay,
    bool storyShape = false,
  }) async {
    await _channel.invokeMethod<void>('saveToGallery', {
      'input': input,
      'isVideo': isVideo,
      'overlay': overlay,
      'storyShape': storyShape,
    });
  }

  static Future<String> processPhoto(
      {required String input,
      required MediaFilter filter,
      int turns = 0,
      double? aspect}) async {
    final out = await _channel.invokeMethod<String>('processPhoto', {
      'input': input,
      'turns': turns,
      'aspect': aspect,
      'offset': filter.offset,
      'matrix': filter.matrix,
      'cartoon': filter.cartoon,
    });
    return out!;
  }
}
