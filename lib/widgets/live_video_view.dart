import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../screens/party/live_broadcast_controller.dart';

/// Renders the live broadcast's video surface — Dart port of
/// LiveVideoView.jsx. Host sees their own camera preview; viewers see the
/// host's remote video once they've joined the channel.
class LiveVideoView extends StatelessWidget {
  final LiveBroadcastController controller;
  final bool isHost;

  const LiveVideoView({super.key, required this.controller, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final engine = controller.engine;
        Widget? surface;
        if (engine != null && controller.joined) {
          if (isHost) {
            surface = AgoraVideoView(controller: VideoViewController(rtcEngine: engine, canvas: const VideoCanvas(uid: 0)));
          } else if (controller.remoteUid != null) {
            surface = AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: controller.remoteUid),
                connection: RtcConnection(channelId: controller.roomId),
              ),
            );
          }
        }

        return AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                if (surface != null)
                  surface
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📹', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text(
                          !controller.joined ? 'Connecting…' : (isHost ? 'Turning on your camera…' : 'Waiting for the host to go live'),
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(999)),
                    child: const Text('🔴 LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
