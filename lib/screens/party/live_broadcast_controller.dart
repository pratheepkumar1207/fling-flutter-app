import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api_client.dart';
import 'voice_chat_controller.dart' show VoiceChatStatus, kAgoraAppId;

/// The Agora uid a user broadcasts with in live rooms. Derived from the user
/// id (FNV-1a) so every viewer can tell whose video is whose — the host, each
/// stage guest, and the other host in a PK — without an extra lookup.
int liveUidFor(String userId) {
  var h = 0x811c9dc5;
  for (final c in userId.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  final uid = h & 0x7fffffff;
  return uid == 0 ? 1 : uid;
}

/// Real camera-video broadcast for 'live' rooms — Dart port of
/// useLiveBroadcast.js. Same join pattern as VoiceChatController (the
/// /calls/token route already scopes who's allowed into the room), but the
/// host also publishes a camera track, and every client can render whoever
/// is currently broadcasting via [remoteUids]/[engine].
///
/// Stage guests (multi-guest live) publish through this same engine via
/// [setGuest] — a second engine for in-room voice would fight this one for
/// the one native Agora instance. During a PK battle, [watchOpponent] adds a
/// receive-only connection to the other live room's channel.
///
/// Unlike VoiceChatController, `_init()` runs eagerly from the constructor
/// rather than being deferred until a user action — a 'live' room is about
/// video from the moment it's entered (see VOICE.md for the silent-failure
/// fix this keeps).
class LiveBroadcastController extends ChangeNotifier {
  final String roomId;
  bool _isHost;
  final String? myUserId;
  RtcEngineEx? _engine;
  bool _joined = false;
  bool _guest = false;
  final Set<int> _remoteUids = {};
  VoiceChatStatus _status = VoiceChatStatus.idle;
  late final int myUid =
      myUserId != null ? liveUidFor(myUserId!) : Random().nextInt(1000000) + 1;

  String? _opponentRoomId;
  int? _opponentUid;

  bool get isHost => _isHost;

  bool _cameraOn = true;
  bool _micOn = true;
  final Set<int> _cameraOffUids = {};
  final Set<int> _micOffUids = {};
  bool get cameraOn => _cameraOn;
  bool get micOn => _micOn;
  bool isCameraOff(int uid) => _cameraOffUids.contains(uid);
  bool isMicOff(int uid) => _micOffUids.contains(uid);

  Future<void> setCameraOn(bool on) async {
    _cameraOn = on;
    notifyListeners();
    await _engine?.muteLocalVideoStream(!on);
  }

  Future<void> setMicOn(bool on) async {
    _micOn = on;
    notifyListeners();
    await _engine?.muteLocalAudioStream(!on);
  }

  Future<void> flipCamera() async => _engine?.switchCamera();
  RtcEngine? get engine => _engine;
  bool get joined => _joined;
  bool get isGuest => _guest;
  Set<int> get remoteUids => _remoteUids;

  /// Any one remote broadcaster — what a viewer shows when they can't tell
  /// who the host is (e.g. an older host build with a random uid).
  int? get remoteUid => _remoteUids.isEmpty ? null : _remoteUids.first;
  VoiceChatStatus get status => _status;
  String? get opponentRoomId => _opponentRoomId;
  int? get opponentUid => _opponentUid;

  LiveBroadcastController(
      {required this.roomId, required bool isHost, this.myUserId})
      : _isHost = isHost {
    if (kAgoraAppId.isNotEmpty) _init();
  }

  Future<void> _init() async {
    _setStatus(VoiceChatStatus.connecting);
    final asHost = _isHost;
    // Only the host is asked up front (they publish straight away); a
    // viewer is asked in setGuest once they join the stage.
    if (asHost) {
      final camStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      if (!camStatus.isGranted || !micStatus.isGranted) {
        _setStatus(VoiceChatStatus.permissionDenied);
        return;
      }
    }
    try {
      final engine = createAgoraRtcEngineEx();
      await engine.initialize(RtcEngineContext(appId: kAgoraAppId));
      await engine.enableVideo();
      await engine.enableAudio();
      engine.registerEventHandler(RtcEngineEventHandler(
        // Shows up in the phone's log, for diagnosing connection problems.
        onLocalVideoStateChanged: (source, state, reason) =>
            debugPrint('AGORA live my camera: $state because $reason'),
        onLocalAudioStateChanged: (connection, state, reason) =>
            debugPrint('AGORA live my mic: $state because $reason'),
        onRemoteVideoStateChanged: (connection, uid, state, reason, elapsed) =>
            debugPrint('AGORA live their video: $state because $reason'),
        onRemoteAudioStateChanged: (connection, uid, state, reason, elapsed) =>
            debugPrint('AGORA live their audio: $state because $reason'),
        onConnectionStateChanged: (connection, state, reason) =>
            debugPrint('AGORA live: $state because $reason'),
        onUserMuteVideo: (connection, uid, muted) {
          muted ? _cameraOffUids.add(uid) : _cameraOffUids.remove(uid);
          notifyListeners();
        },
        onUserMuteAudio: (connection, uid, muted) {
          muted ? _micOffUids.add(uid) : _micOffUids.remove(uid);
          notifyListeners();
        },
        onUserJoined: (connection, uid, elapsed) {
          debugPrint('AGORA live someone joined');
          if (connection.channelId == _opponentRoomId) {
            _opponentUid = uid;
          } else if (connection.channelId == roomId) {
            _remoteUids.add(uid);
          }
          notifyListeners();
        },
        onUserOffline: (connection, uid, reason) {
          if (connection.channelId == _opponentRoomId) {
            if (_opponentUid == uid) _opponentUid = null;
          } else {
            _remoteUids.remove(uid);
            _cameraOffUids.remove(uid);
            _micOffUids.remove(uid);
          }
          notifyListeners();
        },
        // A connection that errors out after a successful join must be
        // observable — see VOICE.md.
        onError: (ErrorCodeType err, String msg) {
          debugPrint('AGORA live error: $err');
          _joined = false;
          _setStatus(VoiceChatStatus.failed);
        },
      ));
      _engine = engine;

      final data = await ApiClient.post('/calls/token',
          body: {'roomId': roomId, 'uid': myUid}) as Map<String, dynamic>;
      await engine.joinChannel(
        token: data['token'] as String,
        channelId: data['channelName'] as String,
        uid: myUid,
        options: ChannelMediaOptions(
          // Only people on camera are broadcasters; a viewer joined as one
          // would look like a performer to everyone else in the room.
          clientRoleType: asHost
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: asHost,
          publishMicrophoneTrack: asHost,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );
      if (asHost) {
        await engine.startPreview();
      }
      _joined = true;
      _setStatus(VoiceChatStatus.connected);
      if (_isHost != asHost) {
        await _setCamera(_isHost);
      } else if (_guest) {
        await _publish(true);
      }
    } catch (e) {
      debugPrint('AGORA live could not start: $e');
      // Video just won't work this session — not fatal to the rest of the
      // room, but now observable via `status` instead of silent.
      _setStatus(VoiceChatStatus.failed);
    }
  }

  /// Follows who the room says is host: that's only known once the room's
  /// socket reports it, which can be after this controller started, and the
  /// host can hand over mid-live.
  Future<void> setHost(bool on) async {
    if (on == _isHost) return;
    _isHost = on;
    notifyListeners();
    if (_joined) await _setCamera(on);
  }

  Future<void> _setCamera(bool on) async {
    if (on) {
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      if (!cam.isGranted || !mic.isGranted) {
        _setStatus(VoiceChatStatus.permissionDenied);
        return;
      }
    }
    await _publish(on);
  }

  /// Puts a viewer on (or takes them off) the video stage. Safe to call on
  /// every build: it only acts when the state actually changes.
  Future<void> setGuest(bool on) async {
    if (_isHost || on == _guest) return;
    _guest = on;
    notifyListeners();
    if (on) {
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      if (!cam.isGranted || !mic.isGranted) {
        _guest = false;
        notifyListeners();
        return;
      }
    }
    if (_joined) await _publish(on);
  }

  Future<void> _publish(bool on) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.updateChannelMediaOptions(ChannelMediaOptions(
          clientRoleType: on
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          publishCameraTrack: on,
          publishMicrophoneTrack: on));
      // A new turn on stage starts with both on.
      _cameraOn = true;
      _micOn = true;
      await engine.muteLocalVideoStream(false);
      await engine.muteLocalAudioStream(false);
      notifyListeners();
      on ? await engine.startPreview() : await engine.stopPreview();
    } catch (e) {
      debugPrint('AGORA live could not publish: $e');
      // Stays a viewer; the stage tile shows their avatar instead.
    }
  }

  /// PK: watch the other live room's host next to ours.
  Future<void> watchOpponent(String? otherRoomId) async {
    if (otherRoomId == _opponentRoomId) return;
    final engine = _engine;
    final previous = _opponentRoomId;
    _opponentRoomId = otherRoomId;
    _opponentUid = null;
    hearingOpponent = false;
    notifyListeners();
    if (engine == null) return;
    try {
      if (previous != null) {
        await engine.leaveChannelEx(
            connection: RtcConnection(channelId: previous, localUid: myUid));
      }
      if (otherRoomId == null) return;
      final data = await ApiClient.post('/calls/token',
          body: {'roomId': otherRoomId, 'uid': myUid}) as Map<String, dynamic>;
      await engine.joinChannelEx(
        token: data['token'] as String,
        connection: RtcConnection(channelId: otherRoomId, localUid: myUid),
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeVideo: true,
          // Only the host's room audio, so two lives don't talk over each
          // other for viewers.
          autoSubscribeAudio: false,
        ),
      );
    } catch (_) {
      // The PK bar still works; the other side shows their avatar.
    }
  }

  /// Battle: whether we hear the other live's host. Off unless asked, so
  /// two lives don't talk over each other.
  bool hearingOpponent = false;

  Future<void> setHearOpponent(bool on) async {
    final engine = _engine;
    final room = _opponentRoomId;
    hearingOpponent = on;
    notifyListeners();
    if (engine == null || room == null) return;
    try {
      await engine.updateChannelMediaOptionsEx(
        options: ChannelMediaOptions(autoSubscribeAudio: on),
        connection: RtcConnection(channelId: room, localUid: myUid),
      );
      await engine.muteAllRemoteAudioStreamsEx(
        mute: !on,
        connection: RtcConnection(channelId: room, localUid: myUid),
      );
    } catch (_) {}
  }

  void _setStatus(VoiceChatStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }
}
