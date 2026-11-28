import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// Signed out, each time the app opens (never once signed in): the brand
/// pack's 16 s features intro (watch, live, chat, call, play and win,
/// match, then the logo), with music. Plays to the end, no buttons over it.
class IntroVideoScreen extends StatefulWidget {
  final VoidCallback onDone;
  const IntroVideoScreen({super.key, required this.onDone});

  static const _seenKey = 'seen_intro_video_v1';

  static Future<bool> hasSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_seenKey) == true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  VideoPlayerController? _video;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final v = VideoPlayerController.asset('assets/brand/intro.mp4');
    try {
      await v.initialize();
    } catch (_) {
      // No video on this device (or in tests): straight on.
      await v.dispose();
      _finish();
      return;
    }
    if (!mounted) {
      await v.dispose();
      return;
    }
    v.addListener(_tick);
    setState(() => _video = v);
    await v.play();
  }

  void _tick() {
    final v = _video;
    if (v == null) return;
    final val = v.value;
    if (val.isInitialized &&
        val.duration > Duration.zero &&
        val.position >= val.duration - const Duration(milliseconds: 150) &&
        !val.isPlaying) {
      _finish();
    }
    if (mounted) setState(() {});
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    IntroVideoScreen.markSeen();
    widget.onDone();
  }

  @override
  void dispose() {
    _video?.removeListener(_tick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final ready = v != null && v.value.isInitialized;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Stack(fit: StackFit.expand, children: [
        if (ready)
          FittedBox(
            // Whole video, black above and below on tall phones (cover cut the
            // sides off: "together" lost its last letter).
            fit: BoxFit.contain,
            child: SizedBox(
              width: v.value.size.width,
              height: v.value.size.height,
              child: VideoPlayer(v),
            ),
          ),
      ]),
    );
  }
}
