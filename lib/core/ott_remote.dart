import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What another app's player is doing right now, as Android reports it.
class OttPlayerState {
  final bool playing;
  final double positionSec;
  final bool canSeek;
  final String? title;
  // Total length, when the player reports one.
  final double? durationSec;
  const OttPlayerState(
      {required this.playing,
      required this.positionSec,
      required this.canSeek,
      this.title,
      this.durationSec});
}

/// Plays, pauses and seeks the Netflix / Prime Video app's own player for
/// watch-party sync, through Android's media-session controls (see
/// OttRemoteChannel.kt). Needs Notification access for Insync. Android
/// only — everywhere else [supported] is false and the room falls back to
/// "press play too" nudges.
class OttRemote {
  static const _channel = MethodChannel('com.fling.app/ott_remote');

  static const packages = {
    'netflix': 'com.netflix.mediaclient',
    'amazon': 'com.amazon.avod.thirdpartyclient',
  };

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _call<T>(String method,
      [Map<String, dynamic>? args]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isInstalled(String package) async =>
      await _call<bool>('isInstalled', {'package': package}) ?? false;

  static Future<bool> hasAccess() async =>
      await _call<bool>('hasAccess') ?? false;

  static Future<bool> openAccessSettings() async =>
      await _call<bool>('openAccessSettings') ?? false;

  static Future<bool> launch(String package) async =>
      await _call<bool>('launch', {'package': package}) ?? false;

  static Future<OttPlayerState?> state(String package) async {
    final raw = await _call<Map>('getState', {'package': package});
    if (raw == null) return null;
    return OttPlayerState(
      playing: raw['playing'] == true,
      positionSec: ((raw['positionMs'] as num?) ?? 0) / 1000,
      canSeek: raw['canSeek'] == true,
      title: raw['title'] as String?,
      durationSec: ((raw['durationMs'] as num?) ?? 0) > 0
          ? (raw['durationMs'] as num) / 1000
          : null,
    );
  }

  static Future<void> play(String package) =>
      _call<bool>('play', {'package': package});

  static Future<void> pause(String package) =>
      _call<bool>('pause', {'package': package});

  static Future<void> seekTo(String package, double seconds) => _call<bool>(
      'seekTo', {'package': package, 'positionMs': (seconds * 1000).round()});
}
