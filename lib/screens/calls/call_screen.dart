import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/gift_bottom_sheet.dart';
import 'direct_call_controller.dart';

/// Full-screen 1:1 call UI — audio or video, direct (not room-scoped).
/// Matches AudioCallDark.dc.html / VideoCallDark.dc.html: translucent
/// circle buttons on a soft gradient background, a centered "Calling…"
/// avatar for audio, and for video a top status bar (name + live duration)
/// with a camera-flip button plus a gift button alongside mic/camera/
/// speaker/end-call. See calls.js's direct-invite/accept/decline/cancel/
/// end and DirectCallController for the Agora side. [isCaller] only
/// changes the "Calling…" copy shown before the other side's video/audio
/// actually joins the channel (see DirectCallController.remoteUid) — both
/// sides already have a live token by the time this screen opens (caller
/// gets one from direct-invite, callee from direct-accept), so there's no
/// separate "waiting for my own token" state to render.
class CallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final int uid;
  final bool video;
  final bool isCaller;
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.video,
    required this.isCaller,
    required this.peerId,
    required this.peerName,
    this.peerAvatarUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final DirectCallController _controller;
  String? _endReason;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  bool _wasConnected = false;

  @override
  void initState() {
    super.initState();
    _controller = DirectCallController(
        channelName: widget.channelName,
        token: widget.token,
        uid: widget.uid,
        video: widget.video);
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocket());
  }

  void _onControllerChanged() {
    final connected = _controller.remoteUid != null;
    if (connected && !_wasConnected) {
      _wasConnected = true;
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _bindSocket() {
    final socket = context.read<SocketService>().socket;
    void onDone(String reason) {
      if (!mounted) return;
      setState(() => _endReason = reason);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop();
      });
    }

    socket?.on('call:declined', (data) {
      if (data is Map && data['channelName'] == widget.channelName) {
        onDone('${widget.peerName} declined');
      }
    });
    socket?.on('call:cancelled', (data) {
      if (data is Map && data['channelName'] == widget.channelName) {
        onDone('Call cancelled');
      }
    });
    socket?.on('call:ended', (data) {
      if (data is Map && data['channelName'] == widget.channelName) {
        onDone('Call ended');
      }
    });
  }

  Future<void> _hangUp() async {
    // If I'm the caller and the other side never actually joined media
    // (_controller.remoteUid is still null), this is a cancel — the callee
    // may still be looking at their incoming-call dialog (see
    // app_shell.dart's _showIncomingCall) and needs the distinct
    // call:cancelled event to dismiss it, not call:ended.
    final neverConnected = widget.isCaller && _controller.remoteUid == null;
    final endpoint =
        neverConnected ? '/calls/direct-cancel' : '/calls/direct-end';
    ApiClient.post(endpoint, body: {'channelName': widget.channelName})
        .catchError((_) => null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final connected = _controller.remoteUid != null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                          center: Alignment(0, -0.4),
                          radius: 1,
                          colors: [Color(0xFF3A1A5A), AppColors.bg]),
                    ),
                  ),
                  if (widget.video && connected)
                    _remoteVideo()
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.video)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                _endReason ??
                                    (connected
                                        ? 'Connected'
                                        : (widget.isCaller
                                            ? 'Calling…'
                                            : 'Connecting…')),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppGradients.brandDiagonal,
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.purple
                                        .withValues(alpha: 0.18),
                                    spreadRadius: 14),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: AppColors.bg, shape: BoxShape.circle),
                              child: SizedBox(
                                width: 124,
                                height: 124,
                                child: FittedBox(
                                  child: Avatar(
                                      src: widget.peerAvatarUrl,
                                      name: widget.peerName,
                                      size: AvatarSize.lg),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const SizedBox(height: 16),
                          Text(widget.peerName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          if (!widget.video) ...[
                            const SizedBox(height: 4),
                            const Text('Audio call',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12.5)),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _endReason ??
                                    (widget.isCaller
                                        ? 'Calling…'
                                        : 'Connecting…'),
                                style: const TextStyle(
                                    color: AppColors.textFaint, fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.video &&
                      _controller.joined &&
                      _controller.cameraEnabled)
                    Positioned(
                      top: 70,
                      right: 16,
                      width: 96,
                      height: 136,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AgoraVideoView(
                            controller: VideoViewController(
                                rtcEngine: _controller.engine!,
                                canvas: const VideoCanvas(uid: 0))),
                      ),
                    ),
                  if (widget.video)
                    Positioned(
                      top: 18,
                      left: 20,
                      right: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.peerName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (connected)
                                      Container(
                                          width: 6,
                                          height: 6,
                                          margin:
                                              const EdgeInsets.only(right: 5),
                                          decoration: const BoxDecoration(
                                              color: AppColors.success,
                                              shape: BoxShape.circle)),
                                    Text(
                                      connected
                                          ? _formatDuration(_elapsed)
                                          : (_endReason ??
                                              (widget.isCaller
                                                  ? 'Calling…'
                                                  : 'Connecting…')),
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _controller.switchCamera,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.12)),
                              alignment: Alignment.center,
                              child: const InIcon(InIcons.flip,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xE616141D),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        runSpacing: 14,
                        children: [
                          _control(
                              icon: InIcons.speaker,
                              label: 'Speaker',
                              active: _controller.speakerEnabled,
                              onTap: _controller.toggleSpeaker),
                          _control(
                              icon: _controller.micEnabled
                                  ? InIcons.mic
                                  : InIcons.micoff,
                              label: _controller.micEnabled ? 'Mute' : 'Unmute',
                              active: !_controller.micEnabled,
                              onTap: _controller.toggleMic),
                          if (widget.video) ...[
                            _control(
                                icon: InIcons.video,
                                label: _controller.cameraEnabled
                                    ? 'Video'
                                    : 'Video off',
                                active: !_controller.cameraEnabled,
                                onTap: _controller.toggleCamera),
                            _control(
                                icon: InIcons.flip,
                                label: 'Flip',
                                onTap: _controller.switchCamera),
                          ],
                          _control(
                              icon: InIcons.gift,
                              label: 'Gift',
                              color: AppColors.gold,
                              tile: const Color(0xFF2A2310),
                              onTap: () => showGiftBottomSheet(context,
                                  toUserId: widget.peerId)),
                          _control(
                              icon: InIcons.phoneoff,
                              label: 'End',
                              color: Colors.white,
                              tile: AppColors.danger,
                              onTap: _hangUp),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _remoteVideo() {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _controller.engine!,
        canvas: VideoCanvas(uid: _controller.remoteUid),
        connection: RtcConnection(channelId: widget.channelName),
      ),
    );
  }

  Widget _control(
      {required InIconData icon,
      required String label,
      required VoidCallback onTap,
      bool active = false,
      Color color = Colors.white,
      Color? tile}) {
    return SizedBox(
      width: 72,
      child: Semantics(
        button: true,
        toggled: active,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 34,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    tile ?? (active ? Colors.white : const Color(0xFF2A2436)),
              ),
              alignment: Alignment.center,
              child: InIcon(icon,
                  size: 24,
                  color: tile == null && active ? AppColors.bg : color),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }
}
