import '../theme/insync_icons.dart';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/room_person_scope.dart';
import '../models/room_models.dart';
import 'app_image.dart';
import 'avatar.dart';

/// "Static Bloom" style audio-only now-playing card — Dart port of
/// StaticBloomPlayer.jsx. A blooming gradient halo pulses behind a slowly
/// spinning disc while playing (sits still when paused, hence "static"
/// bloom), with a vertical drag-to-set volume rail instead of a horizontal
/// Slider.
class StaticBloomPlayer extends StatefulWidget {
  final bool playing;
  final String? title;
  final String? thumbnail;
  final int volume;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback? onTogglePlay;
  final double currentTime;
  final double duration;
  final bool isHost;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;
  final bool compact;
  final VoidCallback? onSkip;
  final VoidCallback? onSkipPrevious;
  // Compact (room) bar only: like, and a listener's skip vote.
  final bool liked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onVoteSkip;
  // The lobby card: who added the song, what's next, who's here.
  final String? subtitle;
  final String? nextTitle;
  final VoidCallback? onOpenQueue;
  final List<RosterEntry> listeners;

  const StaticBloomPlayer({
    super.key,
    required this.playing,
    this.title,
    this.thumbnail,
    required this.volume,
    required this.onVolumeChange,
    this.onTogglePlay,
    this.currentTime = 0,
    this.duration = 0,
    this.isHost = false,
    this.onSeekChanged,
    this.onSeekEnd,
    this.compact = false,
    this.onSkip,
    this.onSkipPrevious,
    this.liked = false,
    this.onToggleLike,
    this.onVoteSkip,
    this.subtitle,
    this.nextTitle,
    this.onOpenQueue,
    this.listeners = const [],
  });

  @override
  State<StaticBloomPlayer> createState() => _StaticBloomPlayerState();
}

class _StaticBloomPlayerState extends State<StaticBloomPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant StaticBloomPlayer old) {
    super.didUpdateWidget(old);
    if (_spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_spinning) {
      _controller.stop();
    }
  }

  // A listener's play/pause only silences their own phone (the room keeps
  // playing for everyone) — remembers the volume to come back to.
  int? _volumeBeforeMute;
  bool get _mutedHere => !widget.isHost && widget.volume == 0;
  bool get _spinning => widget.playing && !_mutedHere;

  void _toggleHere() {
    if (_mutedHere) {
      widget.onVolumeChange(_volumeBeforeMute ?? 80);
    } else {
      _volumeBeforeMute = widget.volume;
      widget.onVolumeChange(0);
    }
    setState(() {});
  }

  /// The slim one-line room bar: spinning CD, name and time, like,
  /// play/pause and skip, with a hairline progress line the host can drag.
  Widget _slim(BuildContext context) {
    final hasTime = widget.duration > 0;
    final progress =
        hasTime ? (widget.currentTime / widget.duration).clamp(0.0, 1.0) : 0.0;
    final playIcon = _spinning ? InIcons.pause : InIcons.play;
    final onPlay = widget.isHost ? widget.onTogglePlay : _toggleHere;
    final onSkip = widget.isHost ? widget.onSkip : widget.onVoteSkip;
    Widget icon(InIconData i, String label, VoidCallback? onTap,
            {Color? color, bool filled = false}) =>
        Semantics(
          button: true,
          label: label,
          child: InkResponse(
            onTap: onTap,
            radius: 20,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                  child: InIcon(i,
                      size: 17,
                      filled: filled,
                      color: onTap == null
                          ? AppColors.textFaint
                          : (color ?? AppColors.text))),
            ),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: AppColors.surface2,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
            child: Row(children: [
              // The cover as a CD: spins while playing, stops on pause.
              RotationTransition(
                turns: _controller,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface3,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(fit: StackFit.expand, children: [
                    if (widget.thumbnail != null &&
                        widget.thumbnail!.isNotEmpty)
                      AppImage(source: widget.thumbnail, fit: BoxFit.cover)
                    else
                      const Center(
                          child: InIcon(InIcons.music,
                              size: 14, color: AppColors.lilac)),
                    Center(
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.surface2),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.title ?? 'Music',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
              if (hasTime) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                        '${_formatTime(widget.currentTime)}/${_formatTime(widget.duration)}',
                        style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 11,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ],
              icon(InIcons.heart, widget.liked ? 'Unlike' : 'Like',
                  widget.onToggleLike,
                  color: widget.liked ? AppColors.pink : null,
                  filled: widget.liked),
              Semantics(
                button: true,
                label: _spinning ? 'Pause' : 'Play',
                child: InkResponse(
                  onTap: onPlay,
                  radius: 18,
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onPlay == null ? Colors.white38 : Colors.white),
                    child: Center(
                        child: InIcon(playIcon,
                            size: 13, color: Colors.black, filled: true)),
                  ),
                ),
              ),
              icon(InIcons.skipNext, widget.isHost ? 'Skip' : 'Vote to skip',
                  onSkip),
            ]),
          ),
          // Hairline progress; the host can tap or drag it to jump.
          LayoutBuilder(builder: (context, box) {
            void seekTo(double dx, {bool end = false}) {
              if (!widget.isHost || !hasTime) return;
              final t = (dx / box.maxWidth).clamp(0.0, 1.0) * widget.duration;
              widget.onSeekChanged?.call(t);
              if (end) widget.onSeekEnd?.call(t);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => seekTo(d.localPosition.dx, end: true),
              onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
              onHorizontalDragEnd: (_) =>
                  widget.onSeekEnd?.call(widget.currentTime),
              child: SizedBox(
                height: widget.isHost ? 8 : 2,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Stack(children: [
                    Container(height: 2, color: AppColors.surface3),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(height: 2, color: AppColors.lilac),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ]),
      ),
    );
  }

  String _formatTime(double seconds) {
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _full = false;

  /// The song's thumbnail as a spinning CD; tap it for the full player.
  Widget _cd(double size) {
    final still = MediaQuery.disableAnimationsOf(context);
    final thumb = widget.thumbnail;
    return Semantics(
      button: true,
      label: _full ? 'Close full player' : 'Open full player',
      child: GestureDetector(
        onTap: () => setState(() => _full = !_full),
        child: RotationTransition(
          turns: still ? kAlwaysDismissedAnimation : _controller,
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.lilac),
            child: ClipOval(
              child: Stack(fit: StackFit.expand, children: [
                if (thumb != null && thumb.isNotEmpty)
                  AppImage(source: thumb, fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: const Color(0xFF6D3FD0),
                    child: Align(
                      alignment: const Alignment(0, -0.6),
                      child: InIcon(InIcons.music,
                          size: size * 0.2, color: Colors.white),
                    ),
                  ),
                Center(
                  child: Container(
                    width: size * 0.24,
                    height: size * 0.24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bg,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nowPlaying() {
    final still = MediaQuery.disableAnimationsOf(context) || !_spinning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFF3A2A66),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 13,
          height: 11,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 3,
                    height: still
                        ? 4
                        : 3 +
                            8 *
                                (0.5 +
                                    0.5 *
                                        math.sin(
                                            _controller.value * math.pi * 16 +
                                                i * 1.4)),
                    decoration: BoxDecoration(
                        color: AppColors.lilac,
                        borderRadius: BorderRadius.circular(2)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Flexible(
          child: Text('Now playing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFFD8C9FF), fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _timeline() {
    final hasTime = widget.duration > 0;
    final canDrag = widget.isHost && hasTime;
    return Column(children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape:
              RoundSliderThumbShape(enabledThumbRadius: canDrag ? 5 : 0),
          disabledThumbColor: Colors.transparent,
          disabledActiveTrackColor: AppColors.lilac,
          disabledInactiveTrackColor: Colors.white24,
        ),
        child: Slider(
          value: hasTime ? widget.currentTime.clamp(0, widget.duration) : 0,
          max: hasTime ? widget.duration : 1,
          activeColor: AppColors.lilac,
          inactiveColor: Colors.white24,
          onChanged: canDrag ? widget.onSeekChanged : null,
          onChangeEnd: canDrag ? widget.onSeekEnd : null,
        ),
      ),
      const SizedBox(height: 3),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_formatTime(widget.currentTime),
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(hasTime ? _formatTime(widget.duration) : '--:--',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    ]);
  }

  Widget _controls(double playSize) {
    Widget side(InIconData icon, String label, VoidCallback? onTap,
            {Color color = Colors.white, bool filled = false}) =>
        IconButton(
          tooltip: label,
          onPressed: onTap,
          icon: InIcon(icon, size: 22, color: color, filled: filled),
        );
    final onPlay = widget.isHost ? widget.onTogglePlay : _toggleHere;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (widget.onToggleLike != null)
        side(InIcons.heart, widget.liked ? 'Unlike' : 'Like',
            widget.onToggleLike,
            color: widget.liked ? AppColors.pink : Colors.white,
            filled: widget.liked),
      Semantics(
        button: true,
        label: _spinning ? 'Pause' : 'Play',
        child: GestureDetector(
          onTap: onPlay,
          child: Container(
            width: playSize,
            height: playSize,
            decoration: const BoxDecoration(
                color: Color(0xFFF3F0FA), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: InIcon(_spinning ? InIcons.pause : InIcons.play,
                size: playSize * 0.45,
                color: const Color(0xFF17141F),
                filled: true),
          ),
        ),
      ),
      if (widget.isHost && widget.onSkip != null)
        side(InIcons.skipNext, 'Skip', widget.onSkip)
      else if (widget.onVoteSkip != null)
        side(InIcons.skipNext, 'Vote to skip', widget.onVoteSkip),
    ]);
  }

  Widget _listeners() {
    final people = widget.listeners;
    if (people.isEmpty) return const SizedBox.shrink();
    final shown = people.take(3).toList();
    final more = people.length - shown.length;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final r in shown)
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: GestureDetector(
            onTap: () => openRoomPerson(context, r.userId),
            child: SizedBox.square(
              dimension: 24,
              child: FittedBox(
                child:
                    Avatar(src: r.avatarUrl, name: r.name, size: AvatarSize.sm),
              ),
            ),
          ),
        ),
      if (more > 0)
        Text(' +$more',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  /// The lobby's music card, tinted from the song's own thumbnail.
  Widget _card(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    final thumb = widget.thumbnail;
    final title = Text(widget.title ?? 'Playing audio',
        maxLines: _full ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        textAlign: _full ? TextAlign.center : TextAlign.start,
        style: TextStyle(
            color: Colors.white,
            fontSize: _full ? 18 : 16,
            fontWeight: FontWeight.w700));
    final subtitle = widget.subtitle == null
        ? null
        : Text(widget.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12));
    final next = widget.nextTitle == null
        ? null
        : InkWell(
            onTap: widget.onOpenQueue,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Next: ${widget.nextTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          );
    final body = _full
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            _cd((screen * 0.22).clamp(120.0, 200.0)),
            const SizedBox(height: 12),
            title,
            if (subtitle != null) subtitle,
            const SizedBox(height: 10),
            _timeline(),
            const SizedBox(height: 6),
            _controls(52),
            if (next != null) next,
          ])
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                _cd(92),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _nowPlaying(),
                      const SizedBox(height: 6),
                      title,
                      if (subtitle != null) subtitle,
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _timeline(),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [_listeners(), _controls(42)],
              ),
              if (next != null) next,
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          Positioned.fill(
            child: thumb != null && thumb.isNotEmpty
                ? ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: AppImage(source: thumb, fit: BoxFit.cover),
                  )
                : const ColoredBox(color: Color(0xFF2A1F4D)),
          ),
          Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _full
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screen * 0.62),
                    child: SingleChildScrollView(child: body))
                : body,
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard being up tucks the card down to the slim bar for chat.
    if (widget.compact || MediaQuery.viewInsetsOf(context).bottom > 0) {
      return _slim(context);
    }
    return _card(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
