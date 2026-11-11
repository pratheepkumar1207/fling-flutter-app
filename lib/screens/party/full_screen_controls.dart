import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/room_prefs.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';

/// Back to upright, then following the phone again.
void exitFullScreen() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  Future<void>.delayed(const Duration(seconds: 2),
      () => SystemChrome.setPreferredOrientations([]));
}

/// The room player's controls in full screen (phone turned sideways). The
/// picture alone, with a thin light line along the bottom edge for how far
/// it has played; a tap shows the controls over it for 3 seconds. The tap
/// reaches this layer, never the site's own player underneath.
///
/// The host plays, pauses, jumps 10s, drags the line and moves to the next
/// title; everyone else votes to skip and catches up with the host. Like,
/// chat, the menu (three dots) and leaving full screen are everyone's.
class RoomFullScreenControls extends StatefulWidget {
  final String? title;
  final bool isHost;
  final bool playing;
  final double elapsed;
  final double? duration;
  final VoidCallback? onTogglePlay;
  final ValueChanged<double>? onSeekTo;
  final VoidCallback? onSkip;
  final bool liked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onVoteSkip;
  final int skipVoteCount;
  final int skipVoteRequired;
  final VoidCallback onSettings;
  final VoidCallback? onCatchUp;

  /// Start with the controls showing (tests).
  final bool initiallyShown;

  const RoomFullScreenControls({
    super.key,
    required this.title,
    required this.isHost,
    required this.playing,
    required this.elapsed,
    required this.duration,
    required this.onSettings,
    this.onTogglePlay,
    this.onSeekTo,
    this.onSkip,
    this.liked = false,
    this.onToggleLike,
    this.onVoteSkip,
    this.skipVoteCount = 0,
    this.skipVoteRequired = 1,
    this.onCatchUp,
    this.initiallyShown = false,
  });

  @override
  State<RoomFullScreenControls> createState() => _RoomFullScreenControlsState();
}

class _RoomFullScreenControlsState extends State<RoomFullScreenControls> {
  late bool _shown = widget.initiallyShown;
  Timer? _hide;
  double? _drag;

  void _show() {
    _hide?.cancel();
    setState(() => _shown = true);
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _drag == null) setState(() => _shown = false);
    });
  }

  void _toggle() {
    if (_shown) {
      _hide?.cancel();
      setState(() => _shown = false);
    } else {
      _show();
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  static String _time(double s) {
    final d = Duration(seconds: s.isFinite ? s.round().clamp(0, 359999) : 0);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$sec' : '$m:$sec';
  }

  // A button on the controls: does its job and keeps them showing.
  Widget _icon(InIconData i, String label, VoidCallback? onTap,
          {double size = 20, Color color = Colors.white}) =>
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap == null
              ? null
              : () {
                  onTap();
                  if (mounted) _show();
                },
          radius: size + 4,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: InIcon(i, size: size, color: color),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final elapsed = _drag ?? w.elapsed;
    final duration = w.duration;
    final max = (duration ?? 0) > elapsed ? duration! : elapsed + 1;
    final fraction = duration != null && duration > 0
        ? (elapsed / duration).clamp(0.0, 1.0)
        : 0.0;
    final line = IgnorePointer(
      child: SizedBox(
        height: 3,
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.white24),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: const ColoredBox(color: Color(0xE6FFFFFF)),
          ),
        ]),
      ),
    );
    return Stack(children: [
      // Every tap on the picture lands here, never on the site's player.
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
        ),
      ),
      if (!_shown) Positioned(left: 0, right: 0, bottom: 0, child: line),
      if (_shown) ...[
        const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Color(0x61000000)))),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                _icon(InIcons.down, 'Leave full screen', exitFullScreen),
                Expanded(
                  child: Text(w.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                ),
                if (w.onToggleLike != null)
                  _icon(InIcons.heart, w.liked ? 'Unlike' : 'Like',
                      w.onToggleLike,
                      color: w.liked ? AppColors.pink : Colors.white),
                ListenableBuilder(
                  listenable: RoomPrefs.instance,
                  builder: (context, _) {
                    final on = RoomPrefs.instance.chatOverVideo;
                    return _icon(InIcons.chat, on ? 'Hide chat' : 'Show chat',
                        () => RoomPrefs.instance.setChatOverVideo(!on),
                        color: on ? AppColors.lilac : Colors.white);
                  },
                ),
                _icon(InIcons.more, 'Settings', w.onSettings),
              ]),
            ),
          ),
        ),
        if (w.isHost)
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (w.onSeekTo != null)
                _icon(InIcons.back10, 'Back 10 seconds',
                    () => w.onSeekTo!((w.elapsed - 10).clamp(0, max)),
                    size: 26),
              const SizedBox(width: 40),
              _icon(
                  w.playing ? InIcons.pause : InIcons.play,
                  w.playing ? 'Pause for everyone' : 'Play for everyone',
                  w.onTogglePlay,
                  size: 40),
              const SizedBox(width: 40),
              if (w.onSeekTo != null)
                _icon(InIcons.forward10, 'Forward 10 seconds',
                    () => w.onSeekTo!((w.elapsed + 10).clamp(0, max)),
                    size: 26),
            ]),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
                child: Row(children: [
                  Text(
                      '${_time(elapsed)} / ${duration != null ? _time(duration) : '--:--'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const Spacer(),
                  if (!w.isHost && w.onCatchUp != null)
                    _icon(InIcons.sync, 'Catch up with host', w.onCatchUp),
                  if (!w.isHost && w.onVoteSkip != null)
                    Semantics(
                      button: true,
                      label:
                          'Vote to skip, ${w.skipVoteCount} of ${w.skipVoteRequired}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () {
                          w.onVoteSkip!();
                          _show();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16)),
                          child: Text(
                              'Vote skip ${w.skipVoteCount}/${w.skipVoteRequired}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  if (w.isHost && w.onSkip != null)
                    _icon(InIcons.skipNext, 'Next title', w.onSkip),
                  _icon(InIcons.exitFullscreen, 'Leave full screen',
                      exitFullScreen),
                ]),
              ),
              // The line itself; the host drags it to move the room.
              SizedBox(
                height: 14,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: w.isHost ? 6 : 0,
                        disabledThumbRadius: 0),
                    overlayShape: SliderComponentShape.noOverlay,
                    trackShape: const RectangularSliderTrackShape(),
                    disabledActiveTrackColor: const Color(0xE6FFFFFF),
                    disabledInactiveTrackColor: Colors.white24,
                  ),
                  child: Slider(
                    value: elapsed.clamp(0, max),
                    max: max,
                    activeColor: const Color(0xE6FFFFFF),
                    inactiveColor: Colors.white24,
                    onChanged: w.isHost && w.onSeekTo != null
                        ? (v) {
                            _hide?.cancel();
                            setState(() => _drag = v);
                          }
                        : null,
                    onChangeEnd: w.isHost && w.onSeekTo != null
                        ? (v) {
                            setState(() => _drag = null);
                            w.onSeekTo!(v);
                            _show();
                          }
                        : null,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }
}
