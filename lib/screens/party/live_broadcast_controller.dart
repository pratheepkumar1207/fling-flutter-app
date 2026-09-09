import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api_client.dart';
import 'voice_chat_controller.dart' show VoiceChatStatus, kAgoraAppId;

/// Real camera-video broadcast for 'live' rooms — Dart port of
/// useLiveBroadcast.js. Same join pattern as VoiceChatController (the
/// /calls/token route already scopes who's allowed into the room), but the
/// host also publishes a camera track, and every client can render whoever
/// is currently broadcasting via [remoteUid]/[engine].
///
/// Unlike VoiceChatController, `_init()` runs eagerly from the constructor
/// rather than being deferred until a user action — a 'live' room is about
/// video from the moment it's entered, not an optional add-on most
/// participants never touch the way in-room voice is. That eager-init
/// choice is unchanged here; only the same silent-failure gap
/// VoiceChatController had is fixed (see VOICE.md for the full reasoning —
/// this is the identical bug in the identical shape, flagged there and
/// fixed here in its own phase).
class LiveBroadcastController extends ChangeNotifier {
  final String roomId;
  final bool isHost;
  RtcEngine? _engine;
  bool _joined = false;
  int? _remoteUid;
  VoiceChatStatus _status = VoiceChatStatus.idle;

  RtcEngine? get engine => _engine;
  bool get joined => _joined;
  int? get remoteUid => _remoteUid;
  VoiceChatStatus get status => _status;

  LiveBroadcastController({required this.roomId, required this.isHost}) {
    if (kAgoraAppId.isNotEmpty) _init();
  }

  Future<void> _init() async {
    _setStatus(VoiceChatStatus.connecting);
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    // Only the host actually needs both granted (they publish); a viewer
    // just subscribes to the broadcast and never asked for camera access
    // in the first place — requesting it above is what surfaces an OS
    // permission prompt to non-hosts unnecessarily, but *failing* here for
    // a viewer who denied a camera prompt they had no reason to see would
    // be wrong. Only gate on it for the host.
    if (isHost && (!camStatus.isGranted || !micStatus.isGranted)) {
      _setStatus(VoiceChatStatus.permissionDenied);
      return;
    }
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: kAgoraAppId));
      await engine.enableVideo();
      await engine.enableAudio();
      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (connection, uid, elapsed) {
          if (!isHost && _remoteUid == null) {
            _remoteUid = uid;
            notifyListeners();
          }
        },
        onUserOffline: (connection, uid, reason) {
          if (_remoteUid == uid) {
            _remoteUid = null;
            notifyListeners();
          }
        },
        // Previously unregistered — a connection that errored out after a
        // successful join (see VOICE.md) had no way to tell this
        // controller voice/video had actually stopped working; `_joined`
        // would stay true forever.
        onError: (ErrorCodeType err, String msg) {
          _joined = false;
          _setStatus(VoiceChatStatus.failed);
        },
      ));
      _engine = engine;

      final uid = Random().nextInt(1000000);
      final data = await ApiClient.post('/calls/token', body: {'roomId': roomId, 'uid': uid}) as Map<String, dynamic>;
      await engine.joinChannel(
        token: data['token'] as String,
        channelId: data['channelName'] as String,
        uid: uid,
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
    } catch (_) {
      // Voice/video just won't work this session — not fatal to the rest
      // of the room, but now observable via `status` instead of silent.
      _setStatus(VoiceChatStatus.failed);
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
