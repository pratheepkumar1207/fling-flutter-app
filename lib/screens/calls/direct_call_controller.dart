import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../party/voice_chat_controller.dart' show kAgoraAppId;

/// Agora engine for a direct (non-room) 1:1 call — see calls.js's
/// direct-invite/accept/decline/cancel/end routes for the signaling side.
/// Initialized eagerly in the constructor rather than lazily like
/// VoiceChatController: unlike a room (opened for lots of reasons that
/// don't need voice), CallScreen only ever exists because the user just
/// explicitly placed or accepted a call, so there's no "opened it for an
/// unrelated reason" case to protect against — same reasoning as
/// LiveBroadcastController.
class DirectCallController extends ChangeNotifier {
  final String channelName;
  final String token;
  final int uid;
  final bool video;

  RtcEngine? _engine;
  bool _joined = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  int? _remoteUid;

  bool get joined => _joined;
  bool get micEnabled => _micEnabled;
  bool get cameraEnabled => _cameraEnabled;
  int? get remoteUid => _remoteUid;
  RtcEngine? get engine => _engine;

  DirectCallController({required this.channelName, required this.token, required this.uid, required this.video}) {
    if (kAgoraAppId.isNotEmpty) _init();
  }

  Future<void> _init() async {
    try {
      await Permission.microphone.request();
      if (video) await Permission.camera.request();

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: kAgoraAppId));
      await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      if (video) {
        await engine.enableVideo();
      } else {
        await engine.disableVideo();
      }
      await engine.enableAudio();
      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          _remoteUid = remoteUid;
          notifyListeners();
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (_remoteUid == remoteUid) {
            _remoteUid = null;
            notifyListeners();
          }
        },
      ));
      _engine = engine;

      await engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: video,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: video,
          autoSubscribeAudio: true,
        ),
      );
      if (video) await engine.startPreview();
      _joined = true;
      notifyListeners();
    } catch (_) {
      // The call just won't connect this session.
    }
  }

  Future<void> toggleMic() async {
    _micEnabled = !_micEnabled;
    await _engine?.muteLocalAudioStream(!_micEnabled);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    _cameraEnabled = !_cameraEnabled;
    await _engine?.muteLocalVideoStream(!_cameraEnabled);
    notifyListeners();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }
}
