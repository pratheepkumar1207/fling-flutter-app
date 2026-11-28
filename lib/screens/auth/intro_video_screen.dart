import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';

/// Signed out, each time the app opens (never once signed in): the brand
/// pack's 16 s features intro (watch, live, chat, call, play and win,
/// match, then the logo), with music. Skip any time; mute with the speaker
/// button.
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
  bool _muted = false;
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
    if (val.isInitialized && val.duration > Duration.zero && val.position >= val.duration - const Duration(milliseconds: 150) && !val.isPlaying) {
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
    final d = ready ? v.value.duration.inMilliseconds : 0;
    final p = ready ? v.value.position.inMilliseconds : 0;
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: [
              Row(children: [
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Skip intro',
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.black,
                    shape: const StadiumBorder(side: BorderSide(color: Colors.white)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _finish,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Skip', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
              ]),
              const Spacer(),
              Row(children: [
                Semantics(
                  button: true,
                  label: _muted ? 'Sound on' : 'Mute',
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.black,
                    shape: const CircleBorder(side: BorderSide(color: Colors.white)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: ready
                          ? () {
                              setState(() => _muted = !_muted);
                              v.setVolume(_muted ? 0 : 1);
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: InIcon(_muted ? InIcons.mute : InIcons.speaker, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: d > 0 ? (p / d).clamp(0.0, 1.0) : 0,
                      minHeight: 3,
                      color: AppColors.primary,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
