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
  final bool isHost;
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
      {required this.roomId, required this.isHost, this.myUserId}) {
    if (kAgoraAppId.isNotEmpty) _init();
  }

  Future<void> _init() async {
    _setStatus(VoiceChatStatus.connecting);
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    // Only the host has to grant both up front (they publish straight
    // away); a viewer only needs them once they join the stage.
    if (isHost && (!camStatus.isGranted || !micStatus.isGranted)) {
      _setStatus(VoiceChatStatus.permissionDenied);
      return;
    }
    try {
      final engine = createAgoraRtcEngineEx();
      await engine.initialize(RtcEngineContext(appId: kAgoraAppId));
      await engine.enableVideo();
      await engine.enableAudio();
      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (connection, uid, elapsed) {
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
          }
          notifyListeners();
        },
        // A connection that errors out after a successful join must be
        // observable — see VOICE.md.
        onError: (ErrorCodeType err, String msg) {
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
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: isHost,
          publishMicrophoneTrack: isHost,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );
      if (isHost) {
        await engine.startPreview();
      }
      _joined = true;
      _setStatus(VoiceChatStatus.connected);
      if (_guest) await _publish(true);
    } catch (_) {
      // Video just won't work this session — not fatal to the rest of the
      // room, but now observable via `status` instead of silent.
      _setStatus(VoiceChatStatus.failed);
    }
  }

  /// Puts a viewer on (or takes them off) the video stage. Safe to call on
  /// every build: it only acts when the state actually changes.
  Future<void> setGuest(bool on) async {
    if (isHost || on == _guest) return;
    _guest = on;
    notifyListeners();
    if (on) {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
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
          publishCameraTrack: on, publishMicrophoneTrack: on));
      on ? await engine.startPreview() : await engine.stopPreview();
    } catch (_) {
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
