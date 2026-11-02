import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../theme/app_colors.dart';
import 'create_flow.dart';
import 'story_editor_screen.dart';

/// Colours a text post can sit on; the name is what's saved on the post.
const kTextPostColours = <String, Color>{
  'purple': Color(0xFF6D3FD0),
  'pink': Color(0xFFE0569B),
  'night': Color(0xFF1C1926),
  'orange': Color(0xFFE8833A),
  'green': Color(0xFF2FA67F),
  'blue': Color(0xFF2F7FD6),
};

/// Aa: type straight on a colour. A post can also carry a poll or a voice
/// note; a story goes on to the sticker editor, which has its own poll.
class TextPostScreen extends StatefulWidget {
  final CreateMode mode;
  final VoidCallback? onPosted;
  const TextPostScreen({super.key, required this.mode, this.onPosted});

  @override
  State<TextPostScreen> createState() => _TextPostScreenState();
}

enum _Extra { none, poll, voice }

class _TextPostScreenState extends State<TextPostScreen> {
  final _text = TextEditingController();
  final _frame = GlobalKey();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  final _recorder = AudioRecorder();
  String _colour = 'purple';
  _Extra _extra = _Extra.none;
  bool _recording = false;
  int _seconds = 0;
  Timer? _ticker;
  String? _voice;
  bool _working = false;

  bool get _story => widget.mode == CreateMode.story;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _text.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleRecording() async {
    if (_recording) {
      _ticker?.cancel();
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      if (bytes.length * 4 / 3 > 4000000) {
        _snack('That voice note is too long. Keep it to a few minutes.');
        return;
      }
      setState(() => _voice = 'data:audio/mp4;base64,${base64Encode(bytes)}');
      return;
    }
    if (!await _recorder.hasPermission()) {
      _snack('Allow the microphone to record a voice note.');
      return;
    }
    final dir = await getTemporaryDirectory();
    await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
        path:
            '${dir.path}/post_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
    if (!mounted) return;
    setState(() {
      _recording = true;
      _seconds = 0;
      _voice = null;
      _extra = _Extra.voice;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _next() async {
    final text = _text.text.trim();
    if (_recording) await _toggleRecording();
    if (!mounted) return;
    if (_story) return _toStory(text);

    final body = <String, dynamic>{'textBackground': _colour};
    if (_extra == _Extra.poll) {
      final options = _options
          .map((o) => o.text.trim())
          .where((o) => o.isNotEmpty)
          .toList();
      if (options.length < 2) return _snack('Add at least two options.');
      body['mediaType'] = 'poll';
      body['pollOptions'] = options;
    } else if (_extra == _Extra.voice && _voice != null) {
      body['mediaType'] = 'voice';
      body['voiceData'] = _voice;
    } else {
      if (text.isEmpty) return _snack('Write something first.');
      body['mediaType'] = 'text';
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateCaptionScreen(
              path: '',
              isVideo: false,
              mode: CreateMode.post,
              onPosted: widget.onPosted,
              textPost: body,
              textPostText: text,
              textPostColour: kTextPostColours[_colour],
            )));
  }

  // A story is a picture of the text, ready for stickers.
  Future<void> _toStory(String text) async {
    if (text.isEmpty) return _snack('Write something first.');
    FocusScope.of(context).unfocus();
    setState(() => _working = true);
    final navigator = Navigator.of(context);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final box =
          _frame.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await box.toImage(pixelRatio: 720 / box.size.width);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/story_text_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      await navigator.push(MaterialPageRoute(
          builder: (_) => StoryEditorScreen(
                path: file.path,
                isVideo: false,
                onPosted: widget.onPosted,
              )));
    } catch (_) {
      if (mounted) _snack('Couldn’t make that. Try again.');
    }
    if (mounted) setState(() => _working = false);
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap, bool on) =>
      Semantics(
        button: true,
        label: label,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: on ? AppColors.gold : Colors.white, size: 26),
        ),
      );

  Widget _poll() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < _options.length; i++)
            TextField(
              controller: _options[i],
              maxLength: 40,
              style: const TextStyle(color: Color(0xFF241338)),
              decoration: InputDecoration(
                  hintText: 'Option ${i + 1}',
                  hintStyle: const TextStyle(color: Color(0xFF8A8399)),
                  counterText: ''),
            ),
          if (_options.length < 6)
            TextButton(
              onPressed: () =>
                  setState(() => _options.add(TextEditingController())),
              child: const Text('Add option'),
            ),
        ]),
      );

  Widget _voiceChip() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xCC0B0912),
            borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_recording ? Icons.fiber_manual_record : Icons.check_rounded,
              color: _recording ? const Color(0xFFE0364F) : AppColors.success,
              size: 18),
          const SizedBox(width: 8),
          Text(
              _recording
                  ? 'Recording ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}. Tap the mic to stop.'
                  : 'Voice note added',
              style: const TextStyle(color: Colors.white)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final colour = kTextPostColours[_colour]!;
    return Scaffold(
      backgroundColor: colour,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _working ? null : _next,
            child: const Text('Next',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(children: [
          RepaintBoundary(
            key: _frame,
            child: Container(
              color: colour,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _text,
                  autofocus: true,
                  maxLines: null,
                  maxLength: 1000,
                  textAlign: TextAlign.center,
                  cursorColor: Colors.white,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 1.2),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'Type something…',
                      hintStyle: TextStyle(color: Colors.white60)),
                ),
              ]),
            ),
          ),
          if (_extra != _Extra.none)
            Positioned(
              left: 0,
              right: 0,
              bottom: 70,
              child: _extra == _Extra.poll ? _poll() : _voiceChip(),
            ),
          if (!_story)
            Positioned(
              right: 4,
              top: 4,
              child: Column(children: [
                _tool(
                    Icons.bar_chart_rounded,
                    'Poll',
                    () => setState(() => _extra =
                        _extra == _Extra.poll ? _Extra.none : _Extra.poll),
                    _extra == _Extra.poll),
                _tool(
                    _recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                    _recording ? 'Stop recording' : 'Voice note',
                    _toggleRecording,
                    _extra == _Extra.voice),
              ]),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final e in kTextPostColours.entries)
                    Semantics(
                      button: true,
                      selected: e.key == _colour,
                      label: e.key,
                      child: GestureDetector(
                        onTap: () => setState(() => _colour = e.key),
                        child: Container(
                          width: e.key == _colour ? 32 : 26,
                          height: e.key == _colour ? 32 : 26,
                          decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2)),
                        ),
                      ),
                    ),
                ]),
          ),
        ]),
      ),
    );
  }
}
