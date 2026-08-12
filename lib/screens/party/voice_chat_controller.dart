import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/api_client.dart';

/// Flutter port of src/hooks/useVoiceChat.js — joins the Agora channel as a
/// listener immediately, only publishes the local mic while the server's
/// authoritative call:state says this user is allowed to talk (see
/// RoomSocketController.call / setMicEnabled below), same trust boundary as
/// the web app: the client never decides on its own that it's allowed to
/// publish.
///
/// Set your Agora App ID here — same constraint as the YouTube key: never
/// commit real production secrets to source. An Agora App ID is safe to ship
/// client-side (that's how the RTC SDK is designed to work — the *token* is
/// what's actually access-controlled, minted server-side per src/routes/calls.js),
/// but leave this blank until you've added your own.
const String kAgoraAppId = '8bb5fdf025274326813950466686c483';

class VoiceChatController {
  final String roomId;
  RtcEngine? _engine;
  bool _joined = false;
  bool _micEnabled = false;
  Future<void>? _initFuture;

  VoiceChatController({required this.roomId});

  // Deliberately NOT called from the constructor. Agora's native SDK does
  // real work (dlopen, JNI init) the instant engine.initialize() runs —
  // this app's pinned Agora version (6.3.2, see pubspec.yaml's
  // dependency_overrides comment for the matching build-time namespace
  // collision) has crashed the whole process at that exact call on some
  // devices, identically in debug and release, which a Dart try/catch
  // can't stop since it's a native-side crash, not a Dart exception.
  // Deferring to "only when the user actually touches a mic control"
  // means a broken Agora build no longer takes the entire app down just
  // for opening a room — see ensureInitialized() below, called from
  // party_screen.dart's mic tap handler instead of eagerly here.
  Future<void> ensureInitialized() {
    if (kAgoraAppId.isEmpty) return Future.value();
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      await Permission.microphone.request();
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: kAgoraAppId));
      await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await engine.disableVideo();
      await engine.enableAudio();
      await engine.muteLocalAudioStream(true);
      _engine = engine;

      final uid = Random().nextInt(1000000);
      final data = await ApiClient.post('/calls/token', body: {'roomId': roomId, 'uid': uid}) as Map<String, dynamic>;
      await engine.joinChannel(
        token: data['token'] as String,
        channelId: data['channelName'] as String,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      _joined = true;
    } catch (_) {
      // Voice chat just won't work this session — not fatal to the room.
    }
  }

  Future<void> setMicEnabled(bool enabled) async {
    if (!_joined || enabled == _micEnabled) return;
    _micEnabled = enabled;
    await _engine?.muteLocalAudioStream(!enabled);
  }

  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
  }
}
