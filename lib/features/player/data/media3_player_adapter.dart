import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/playback_state.dart';
import '../domain/video_player_adapter.dart';
import '../domain/video_source.dart';

/// Concrete VideoPlayerAdapter (spec section 14) talking to the native
/// Media3PlayerView platform view (android/.../media3/Media3PlayerView.kt)
/// over its per-instance method/event channel pair. One adapter per
/// AndroidView — see Media3PlayerView widget below, which is what actually
/// creates the platform view and constructs this once Flutter hands back
/// its viewId.
///
/// `position`/`duration`/`isPlaying` are declared as synchronous getters by
/// the shared interface, but a platform channel call is inherently async —
/// resolved the same way sync_video_player.dart's own position tracking
/// already works: cache the latest value from the continuous event stream
/// (native side ticks every 500ms — see Media3PlayerView.kt's
/// tickIntervalMs) and serve the getters from that cache rather than
/// round-tripping the channel on every read.
class Media3PlayerAdapter implements VideoPlayerAdapter {
  Media3PlayerAdapter(int viewId)
      : _methodChannel = MethodChannel('fling/media3_player_$viewId'),
        _eventChannel = EventChannel('fling/media3_player_events_$viewId') {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onEventError);
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<PlaybackStateSnapshot> _controller = StreamController<PlaybackStateSnapshot>.broadcast();

  PlayerLifecycleState _state = PlayerLifecycleState.idle;
  Duration _position = Duration.zero;
  Duration? _duration;
  Duration _bufferedPosition = Duration.zero;
  bool _isPlaying = false;

  @override
  Future<void> initialize(VideoSource source) {
    _state = PlayerLifecycleState.loading;
    return _methodChannel.invokeMethod<void>('initialize', source.toChannelArgs());
  }

  @override
  Future<void> play() => _methodChannel.invokeMethod<void>('play');

  @override
  Future<void> pause() => _methodChannel.invokeMethod<void>('pause');

  @override
  Future<void> seek(Duration position) => _methodChannel.invokeMethod<void>('seekTo', {'positionMs': position.inMilliseconds});

  @override
  Future<void> setPlaybackRate(double rate) => _methodChannel.invokeMethod<void>('setPlaybackRate', {'rate': rate});

  /// Not part of the shared VideoPlayerAdapter interface (spec section 14
  /// doesn't list volume), but every provider that has real playback
  /// control also needs it — exposed as an adapter-specific extra rather
  /// than forcing every implementation (including future YouTube/
  /// authorized-provider adapters that may not support it) to carry it.
  Future<void> setVolume(double volume) => _methodChannel.invokeMethod<void>('setVolume', {'volume': volume.clamp(0.0, 1.0)});

  @override
  Future<void> dispose() async {
    _state = PlayerLifecycleState.disposed;
    await _eventSubscription?.cancel();
    await _controller.close();
    // No explicit "dispose" channel call — see Media3PlayerView.kt: the
    // platform view's own dispose() (triggered when the AndroidView widget
    // is removed from the tree) releases the ExoPlayer instance exactly
    // once. Calling a redundant channel method here could race it.
  }

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<PlaybackStateSnapshot> get playbackState => _controller.stream;

  void _onEvent(dynamic event) {
    final map = Map<Object?, Object?>.from(event as Map);
    switch (map['type']) {
      case 'stateChanged':
        _position = _durationFromMs(map['positionMs']) ?? _position;
        _duration = _durationFromMs(map['durationMs']);
        _state = _stateFromString(map['state'] as String?);
        _isPlaying = _state == PlayerLifecycleState.playing;
        _emit();
      case 'tick':
        _position = _durationFromMs(map['positionMs']) ?? _position;
        _duration = _durationFromMs(map['durationMs']);
        _bufferedPosition = _durationFromMs(map['bufferedPositionMs']) ?? _bufferedPosition;
        _isPlaying = map['isPlaying'] as bool? ?? _isPlaying;
        _emit();
      case 'error':
        _state = PlayerLifecycleState.error;
        _emit(errorMessage: map['message'] as String?);
    }
  }

  void _onEventError(Object error) {
    _state = PlayerLifecycleState.error;
    _emit(errorMessage: error.toString());
  }

  void _emit({String? errorMessage}) {
    if (_controller.isClosed) return;
    _controller.add(
      PlaybackStateSnapshot(
        state: _state,
        position: _position,
        duration: _duration,
        bufferedPosition: _bufferedPosition,
        errorMessage: errorMessage,
      ),
    );
  }

  static Duration? _durationFromMs(Object? value) => value is num ? Duration(milliseconds: value.toInt()) : null;

  static PlayerLifecycleState _stateFromString(String? value) {
    switch (value) {
      case 'idle':
        return PlayerLifecycleState.idle;
      case 'buffering':
        return PlayerLifecycleState.buffering;
      case 'ended':
        return PlayerLifecycleState.ended;
      case 'playing':
        return PlayerLifecycleState.playing;
      case 'paused':
        return PlayerLifecycleState.paused;
      default:
        return PlayerLifecycleState.idle;
    }
  }
}
