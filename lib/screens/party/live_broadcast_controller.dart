import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api_client.dart';
import 'voice_chat_controller.dart' show kAgoraAppId;

/// Real camera-video broadcast for 'live' rooms — Dart port of
/// useLiveBroadcast.js. Same join pattern as VoiceChatController (the
/// /calls/token route already scopes who's allowed into the room), but the
/// host also publishes a camera track, and every client can render whoever
/// is currently broadcasting via [remoteUid]/[engine].
class LiveBroadcastController extends ChangeNotifier {
  final String roomId;
  final bool isHost;
  RtcEngine? _engine;
  bool _joined = false;
  int? _remoteUid;

  RtcEngine? get engine => _engine;
  bool get joined => _joined;
  int? get remoteUid => _remoteUid;

  LiveBroadcastController({required this.roomId, required this.isHost}) {
    if (kAgoraAppId.isNotEmpty) _init();
  }

  Future<void> _init() async {
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
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
      notifyListeners();
    } catch (_) {
      // Live video just won't work this session — not fatal to the rest of the room.
    }
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }
}
