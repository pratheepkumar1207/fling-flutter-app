import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

/// Photos and voice notes in chats (direct and group). Both travel as
/// data: URIs in the message's mediaUrl — the backend caps them at ~6 MB.

/// Picks a photo from the gallery or camera, scaled down for chat.
Future<String?> pickChatPhoto(
    {ImageSource source = ImageSource.gallery}) async {
  final file = await ImagePicker().pickImage(
      source: source, imageQuality: 75, maxWidth: 1600, maxHeight: 1600);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
  return 'data:image/$ext;base64,${base64Encode(bytes)}';
}

Uint8List? _bytesOf(String dataUri) {
  final comma = dataUri.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUri.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Photo bubble; tap for full screen.
class ChatPhoto extends StatelessWidget {
  final String dataUri;
  const ChatPhoto(this.dataUri, {super.key});

  @override
  Widget build(BuildContext context) {
    final bytes = _bytesOf(dataUri);
    if (bytes == null) {
      return const Text('Photo unavailable',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12));
    }
    return Semantics(
      button: true,
      label: 'Photo, tap to open',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black),
                  body: Center(
                      child: InteractiveViewer(child: Image.memory(bytes))),
                ))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 280),
            child:
                Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }
}

/// Voice note bubble: play/pause, a progress bar and the length.
class ChatVoiceNote extends StatefulWidget {
  final String dataUri;
  final bool mine;
  const ChatVoiceNote(this.dataUri, {super.key, this.mine = false});

  @override
  State<ChatVoiceNote> createState() => _ChatVoiceNoteState();
}

class _ChatVoiceNoteState extends State<ChatVoiceNote> {
  AudioPlayer? _player;
  Duration _pos = Duration.zero;
  Duration? _len;
  bool _playing = false;
  StreamSubscription? _a, _b, _c;

  Future<AudioPlayer?> _ensure() async {
    if (_player != null) return _player;
    final bytes = _bytesOf(widget.dataUri);
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/voice_${widget.dataUri.hashCode}.m4a');
    if (!await file.exists()) await file.writeAsBytes(bytes);
    final p = AudioPlayer();
    _len = await p.setFilePath(file.path);
    _a = p.positionStream
        .listen((d) => mounted ? setState(() => _pos = d) : null);
    _b = p.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        p.pause();
        p.seek(Duration.zero);
      }
      setState(() => _playing =
          s.playing && s.processingState != ProcessingState.completed);
    });
    _c = p.durationStream
        .listen((d) => mounted ? setState(() => _len = d) : null);
    _player = p;
    return p;
  }

  Future<void> _toggle() async {
    final p = await _ensure();
    if (p == null) return;
    _playing ? await p.pause() : await p.play();
  }

  @override
  void dispose() {
    _a?.cancel();
    _b?.cancel();
    _c?.cancel();
    _player?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final len = _len;
    final progress = len == null || len.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / len.inMilliseconds).clamp(0.0, 1.0);
    final fg = widget.mine ? Colors.white : AppColors.text;
    // Played part of the waveform in the accent, the rest dimmed.
    final played = widget.mine ? Colors.white : AppColors.lilac;
    final rest = widget.mine
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF5A5568);
    return SizedBox(
      width: 214,
      child: Row(children: [
        Semantics(
          button: true,
          label: _playing ? 'Pause voice message' : 'Play voice message',
          child: InkResponse(
            onTap: _toggle,
            radius: 24,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: InIcon(_playing ? InIcons.pause : InIcons.play,
                  size: 15,
                  color: widget.mine ? AppColors.primary : AppColors.bg,
                  filled: true),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 26,
            child: CustomPaint(
                painter: _WavePainter(
                    seed: widget.dataUri.hashCode,
                    progress: progress,
                    played: played,
                    rest: rest)),
          ),
        ),
        const SizedBox(width: 8),
        Text(len == null ? 'Voice' : _fmt(_playing ? _pos : len),
            style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 12)),
      ]),
    );
  }
}

/// Bar waveform for a voice note. Heights come from the note itself so a
/// note always looks the same; it's a visual, not real audio levels.
class _WavePainter extends CustomPainter {
  final int seed;
  final double progress;
  final Color played;
  final Color rest;
  _WavePainter(
      {required this.seed,
      required this.progress,
      required this.played,
      required this.rest});

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 3.0, gap = 3.0;
    final n = ((size.width + gap) / (bar + gap)).floor();
    var h = seed & 0x7fffffff;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final level = 0.25 + (h % 1000) / 1000 * 0.75;
      final barH = size.height * level;
      final x = i * (bar + gap);
      paint.color = (i + 0.5) / n <= progress ? played : rest;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, (size.height - barH) / 2, bar, barH),
              const Radius.circular(1.5)),
          paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.seed != seed;
}

/// Hold to record a voice note, release to send, slide away to cancel.
class VoiceRecordButton extends StatefulWidget {
  final void Function(String dataUri) onRecorded;
  final double size;

  /// A filled purple circle (the chat composer) instead of a bare icon.
  final bool filled;
  const VoiceRecordButton(
      {super.key,
      required this.onRecorded,
      this.size = 38,
      this.filled = false});

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final _rec = AudioRecorder();
  bool _recording = false;
  bool _cancel = false;
  DateTime? _started;
  Timer? _tick;
  OverlayEntry? _hint;

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Allow the microphone to send voice notes.')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path: path);
    _started = DateTime.now();
    _cancel = false;
    setState(() => _recording = true);
    _showHint();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _hint?.markNeedsBuild();
      // Voice notes stop at two minutes.
      if (DateTime.now().difference(_started!) > const Duration(minutes: 2)) {
        _stop();
      }
    });
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _tick?.cancel();
    _hint?.remove();
    _hint = null;
    final path = await _rec.stop();
    final long = DateTime.now().difference(_started ?? DateTime.now());
    setState(() => _recording = false);
    if (_cancel || path == null || long < const Duration(milliseconds: 700)) {
      return;
    }
    final bytes = await File(path).readAsBytes();
    widget.onRecorded('data:audio/mp4;base64,${base64Encode(bytes)}');
  }

  void _showHint() {
    _hint = OverlayEntry(builder: (_) {
      final secs =
          _started == null ? 0 : DateTime.now().difference(_started!).inSeconds;
      return Positioned(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 90,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.surface2,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: AppColors.pink, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text('${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_cancel ? 'Release to cancel' : 'Slide left to cancel',
                  style: TextStyle(
                      color: _cancel ? AppColors.pink : AppColors.textDim,
                      fontSize: 13)),
            ]),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_hint!);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _hint?.remove();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hold to record a voice message',
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressMoveUpdate: (d) {
          final cancel = d.offsetFromOrigin.dx < -60;
          if (cancel != _cancel) {
            _cancel = cancel;
            _hint?.markNeedsBuild();
          }
        },
        onLongPressEnd: (_) => _stop(),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hold to record, release to send.'))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _recording
                  ? AppColors.pink
                  : widget.filled
                      ? AppColors.primary
                      : Colors.transparent),
          child: Center(
              child: InIcon(InIcons.mic,
                  size: 21,
                  color: _recording || widget.filled
                      ? Colors.white
                      : AppColors.text)),
        ),
      ),
    );
  }
}
