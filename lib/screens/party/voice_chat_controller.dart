import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
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

/// Surfaced to callers instead of the previous silent no-op (see git
/// history — every failure path used to disappear into a bare `catch (_) {}`
/// with no way for party_screen.dart, or anyone, to tell "voice is still
/// connecting" from "voice permanently failed this session and the mic
/// button should say so" from "the user said no to the mic permission
/// prompt, which needs different messaging than a network/server failure").
enum VoiceChatStatus { idle, connecting, connected, permissionDenied, failed }

class VoiceChatController extends ChangeNotifier {
  final String roomId;
  RtcEngine? _engine;
  bool _joined = false;
  bool _micEnabled = false;
  Future<void>? _initFuture;
  VoiceChatStatus _status = VoiceChatStatus.idle;

  VoiceChatStatus get status => _status;

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
  //
  // Note this only protects against the crash happening at all — it can't
  // make that specific failure mode catchable or reportable via `status`
  // below if it does happen, since a native crash takes the process down
  // before any Dart catch clause (or this class) runs again. Every OTHER
  // failure path (permission denied, token fetch failing, joinChannel
  // rejecting, a post-join connection error) is a real Dart exception or
  // engine callback, and those are what `status` now actually reports.
  Future<void> ensureInitialized() {
    if (kAgoraAppId.isEmpty) return Future.value();
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    _setStatus(VoiceChatStatus.connecting);
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _setStatus(VoiceChatStatus.permissionDenied);
      return;
    }
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: kAgoraAppId));
      await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await engine.disableVideo();
      await engine.enableAudio();
      await engine.muteLocalAudioStream(true);
      // Previously unregistered entirely — a connection that dropped or
      // errored out *after* a successful join had no way to tell this
      // controller (or anything downstream of it) that voice had actually
      // stopped working; `_joined` would stay true forever.
      engine.registerEventHandler(RtcEngineEventHandler(
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
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      _joined = true;
      _setStatus(VoiceChatStatus.connected);
    } catch (_) {
      // Still a real possibility even with the lazy-init deferral above
      // (e.g. engine.initialize() throwing a catchable Dart exception
      // rather than crashing natively, or the token fetch/joinChannel
      // failing) — voice just won't work this session, not fatal to the
      // room, but now at least observable via `status` instead of silent.
      _setStatus(VoiceChatStatus.failed);
    }
  }

  void _setStatus(VoiceChatStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  Future<void> setMicEnabled(bool enabled) async {
    if (!_joined || enabled == _micEnabled) return;
    _micEnabled = enabled;
    await _engine?.muteLocalAudioStream(!enabled);
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }
}
