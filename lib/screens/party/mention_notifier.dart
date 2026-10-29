import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/room_prefs.dart';
import '../../core/active_room_holder.dart';
import '../../core/app_messenger.dart';
import 'room_socket_controller.dart';

/// Mounted once in AppShell (see persistent_room_audio.dart for the same
/// pattern) — reacts to being @mentioned in the active room's chat
/// regardless of which screen is currently showing. party_screen.dart used
/// to handle this itself, but that only fired while the room screen was
/// actually mounted: a mention while browsing Home/Feed/anywhere else in
/// the app produced no pop-up at all, and didn't even catch up once you
/// came back (the mention was already cleared-or-not with nobody watching
/// for it). Living here instead, alongside ActiveRoomHolder's other
/// app-wide listeners, means it works no matter where you are.
class MentionNotifier extends StatefulWidget {
  const MentionNotifier({super.key});

  @override
  State<MentionNotifier> createState() => _MentionNotifierState();
}

class _MentionNotifierState extends State<MentionNotifier> {
  RoomSocketController? _rs;
  // A short chime for "you were mentioned / replied to" in room chat.
  final _player = AudioPlayer();
  bool _loaded = false;

  Future<void> _ping() async {
    try {
      if (!_loaded) {
        await _player.setAsset('assets/sounds/chat_ping.wav');
        await _player.setVolume(0.8);
        _loaded = true;
      }
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    ActiveRoomHolder.activeLabel.addListener(_onActiveRoomChanged);
    _onActiveRoomChanged();
  }

  // ActiveRoomHolder.controller itself isn't a ValueNotifier (see its own
  // doc comment on why), so activeLabel — which does change alongside it,
  // on every join/leave — is what tells us to check for a new controller
  // to attach to.
  void _onActiveRoomChanged() {
    final rs = ActiveRoomHolder.controller;
    if (identical(rs, _rs)) return;
    _rs?.removeListener(_onRoomStateChanged);
    _rs = rs;
    _rs?.addListener(_onRoomStateChanged);
  }

  void _onRoomStateChanged() {
    final rs = _rs;
    if (rs == null || rs.mention == null) return;
    final fromName = rs.mention!['fromName'] as String? ?? 'Someone';
    final reply = rs.mention!['reply'] == true;
    rs.clearMention();
    if (!RoomPrefs.instance.muteAlerts) _ping();
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content:
          Text(reply ? '$fromName replied to you' : '$fromName mentioned you'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void dispose() {
    _player.dispose();
    ActiveRoomHolder.activeLabel.removeListener(_onActiveRoomChanged);
    _rs?.removeListener(_onRoomStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
