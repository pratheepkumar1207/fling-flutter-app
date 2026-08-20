import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/avatar.dart';
import 'direct_call_controller.dart';

/// Full-screen 1:1 call UI — audio or video, direct (not room-scoped).
/// See calls.js's direct-invite/accept/decline/cancel/end and
/// DirectCallController for the Agora side. [isCaller] only changes the
/// "Calling…" copy shown before the other side's video/audio actually
/// joins the channel (see DirectCallController.remoteUid) — both sides
/// already have a live token by the time this screen opens (caller gets
/// one from direct-invite, callee from direct-accept), so there's no
/// separate "waiting for my own token" state to render.
class CallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final int uid;
  final bool video;
  final bool isCaller;
  final String peerName;
  final String? peerAvatarUrl;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.video,
    required this.isCaller,
    required this.peerName,
    this.peerAvatarUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final DirectCallController _controller;
  String? _endReason;

  @override
  void initState() {
    super.initState();
    _controller = DirectCallController(channelName: widget.channelName, token: widget.token, uid: widget.uid, video: widget.video);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocket());
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
      if (data is Map && data['channelName'] == widget.channelName) onDone('${widget.peerName} declined');
    });
    socket?.on('call:cancelled', (data) {
      if (data is Map && data['channelName'] == widget.channelName) onDone('Call cancelled');
    });
    socket?.on('call:ended', (data) {
      if (data is Map && data['channelName'] == widget.channelName) onDone('Call ended');
    });
  }

  Future<void> _hangUp() async {
    // If I'm the caller and the other side never actually joined media
    // (_controller.remoteUid is still null), this is a cancel — the callee
    // may still be looking at their incoming-call dialog (see
    // app_shell.dart's _showIncomingCall) and needs the distinct
    // call:cancelled event to dismiss it, not call:ended.
    final neverConnected = widget.isCaller && _controller.remoteUid == null;
    final endpoint = neverConnected ? '/calls/direct-cancel' : '/calls/direct-end';
    ApiClient.post(endpoint, body: {'channelName': widget.channelName}).catchError((_) => null);
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
                  if (widget.video && connected)
                    _remoteVideo()
                  else
                    Container(
                      color: AppColors.bg,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Avatar(src: widget.peerAvatarUrl, name: widget.peerName, size: AvatarSize.lg),
                          const SizedBox(height: 16),
                          Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            _endReason ?? (connected ? (widget.video ? 'Connecting video…' : 'Connected') : (widget.isCaller ? 'Calling…' : 'Connecting…')),
                            style: const TextStyle(color: AppColors.textFaint, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  if (widget.video && _controller.joined && _controller.cameraEnabled)
                    Positioned(
                      top: 16,
                      right: 16,
                      width: 100,
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AgoraVideoView(controller: VideoViewController(rtcEngine: _controller.engine!, canvas: const VideoCanvas(uid: 0))),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _circleButton(
                          icon: _controller.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                          onTap: _controller.toggleMic,
                          colors: const [AppColors.accent2, AppColors.primary],
                          glowColor: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 20),
                        _circleButton(
                          icon: Icons.call_end_rounded,
                          onTap: _hangUp,
                          colors: const [AppColors.danger, AppColors.accent],
                          glowColor: AppColors.danger.withValues(alpha: 0.4),
                          size: 64,
                        ),
                        if (widget.video) ...[
                          const SizedBox(width: 20),
                          _circleButton(
                            icon: _controller.cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                            onTap: _controller.toggleCamera,
                            colors: const [AppColors.accent2, AppColors.primary],
                            glowColor: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ],
                      ],
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

  Widget _circleButton({required IconData icon, required VoidCallback onTap, required List<Color> colors, required Color glowColor, double size = 52}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassIcon.circle(
        size: size,
        colors: colors,
        glowColor: glowColor,
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
