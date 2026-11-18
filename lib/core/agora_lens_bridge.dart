import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import 'snap_lens_engine.dart';

/// Snap lenses in an Agora video call or live stream.
///
/// With a lens on, Agora's own camera is switched off and the phone camera
/// goes to Snap instead (SnapLensEngine). Snap's output is shown locally as
/// a Flutter texture ([textureId]) and its frames are sent into the call as
/// a custom video track, so everyone else sees the lens too. "No lens"
/// turns all of that off and gives the camera back to Agora.
///
/// Frames are 540×960 at 15 a second, a bit softer than the plain camera,
/// to keep it light on the phone.
class AgoraLensBridge extends ChangeNotifier {
  final RtcEngine engine;
  AgoraLensBridge(this.engine);

  final _snap = SnapLensEngine.instance;
  int? _trackId;
  int? _textureId;
  StreamSubscription<SnapFrame>? _frames;
  bool _busy = false;

  /// Shows the lens camera locally while a lens is on; null otherwise.
  int? get textureId => _textureId;
  bool get active => _trackId != null;
  SnapLens? get lens => _snap.current.value;
  List<SnapLens> get lenses => _snap.lenses;

  Future<bool> supported() => _snap.supported();

  /// Turns [lens] on (starting the lens camera if needed); null turns
  /// lenses off and gives the camera back to Agora.
  Future<void> choose(SnapLens? lens, {bool front = true}) async {
    if (_busy) return;
    _busy = true;
    try {
      if (lens == null) {
        await _off();
      } else {
        if (_trackId == null) await _on(front);
        await _snap.apply(lens);
      }
    } catch (e) {
      debugPrint('AGORA lens: $e');
      await _off();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Loads the lens list (starts nothing).
  Future<List<SnapLens>> loadLenses() async {
    final list = await _snap.loadLenses();
    notifyListeners();
    return list;
  }

  Future<void> flip() async {
    if (_trackId != null) await _snap.flip();
  }

  Future<void> _on(bool front) async {
    // Agora lets go of the camera first; two can't hold it at once.
    await engine.stopPreview();
    await engine.enableLocalVideo(false);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final track = await engine.createCustomVideoTrack();
    _trackId = track;
    _textureId = await _snap.start(front: front, width: 720, height: 1280);
    await _snap.startFrames(width: 540, height: 960, fps: 15);
    final media = engine.getMediaEngine();
    _frames = _snap.frames.listen((f) {
      media.pushVideoFrame(
        frame: ExternalVideoFrame(
          type: VideoBufferType.videoBufferRawData,
          format: VideoPixelFormat.videoPixelRgba,
          buffer: f.rgba,
          stride: f.width,
          height: f.height,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        videoTrackId: track,
      );
    });
    await engine.updateChannelMediaOptions(ChannelMediaOptions(
      publishCameraTrack: false,
      publishCustomVideoTrack: true,
      customVideoTrackId: track,
    ));
  }

  Future<void> _off() async {
    final track = _trackId;
    _trackId = null;
    _textureId = null;
    await _frames?.cancel();
    _frames = null;
    if (track == null) return;
    try {
      await _snap.stopFrames();
      await _snap.stop();
      await engine.updateChannelMediaOptions(const ChannelMediaOptions(
        publishCameraTrack: true,
        publishCustomVideoTrack: false,
      ));
      await engine.destroyCustomVideoTrack(track);
    } finally {
      await engine.enableLocalVideo(true);
      await engine.startPreview();
    }
  }

  /// Call before the engine is released.
  Future<void> shutdown() async {
    if (_trackId != null) {
      await _frames?.cancel();
      _frames = null;
      _trackId = null;
      _textureId = null;
      await _snap.stopFrames();
      await _snap.stop();
    }
  }
}
