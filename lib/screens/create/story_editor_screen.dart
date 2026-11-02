import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/video_edit.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mention_text_field.dart';
import '../../widgets/story_stickers.dart';

/// The last step of a story: place stickers, text and drawing on it, save it
/// to the phone, or share it.
class StoryEditorScreen extends StatefulWidget {
  final String path;
  final bool isVideo;
  final VoidCallback? onPosted;

  /// Set when answering someone's Add Yours sticker.
  final String? addYoursPrompt;
  const StoryEditorScreen({
    super.key,
    required this.path,
    required this.isVideo,
    this.onPosted,
    this.addYoursPrompt,
  });

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final _overlayKey = GlobalKey();
  final List<Map<String, dynamic>> _stickers = [];
  VideoPlayerController? _video;
  int _nextId = 0;

  bool _drawing = false;
  String _drawColor = 'white';
  List<double>? _line;

  String? _dragging;
  bool _overBin = false;
  double _startScale = 1;
  double _startRotation = 0;
  Offset? _grabOffset;

  bool _busy = false;

  /// Everything is hidden while the sticker layer is captured for saving.
  bool get _hasDrawing => _stickers.any((s) => s['type'] == 'drawing');

  @override
  void initState() {
    super.initState();
    final prompt = widget.addYoursPrompt;
    if (prompt != null) {
      _add({'type': 'addyours', 'question': prompt, 'y': 0.2});
    }
    if (widget.isVideo) _loadVideo();
  }

  Future<void> _loadVideo() async {
    final v = VideoPlayerController.file(File(widget.path));
    await v.initialize();
    await v.setLooping(true);
    await v.play();
    if (!mounted) {
      await v.dispose();
      return;
    }
    setState(() => _video = v);
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _add(Map<String, dynamic> s) {
    setState(() => _stickers.add({
          'id': 's${_nextId++}',
          'x': 0.5,
          'y': 0.45,
          'scale': 1.0,
          'rotation': 0.0,
          ...s,
        }));
  }

  // ---------- Text ----------

  Future<void> _editText([Map<String, dynamic>? existing]) async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => StoryTextEditor(
          text: existing?['text'] as String? ?? '',
          color: existing?['color'] as String? ?? 'white',
          font: existing?['font'] as String? ?? 'classic',
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (existing != null) {
        if (result['text']!.isEmpty) {
          _stickers.remove(existing);
        } else {
          existing.addAll(result);
        }
      } else if (result['text']!.isNotEmpty) {
        _add(result);
      }
    });
  }

  // ---------- Sticker tray ----------

  Future<void> _openTray() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17141F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _StickerTray(),
    );
    if (picked != null && mounted) _add(picked);
  }

  // ---------- Drawing ----------

  void _startLine(Offset p, Size frame) {
    _line = [p.dx / frame.width, p.dy / frame.height];
    setState(() => _stickers.add({
          'id': 's${_nextId++}',
          'type': 'drawing',
          'color': _drawColor,
          'width': 6.0,
          'points': _line,
        }));
  }

  void _extendLine(Offset p, Size frame) {
    if (_line == null || _line!.length >= 2000) return;
    setState(() => _line!.addAll([
          (p.dx / frame.width).clamp(0.0, 1.0),
          (p.dy / frame.height).clamp(0.0, 1.0),
        ]));
  }

  void _undoLine() {
    final i = _stickers.lastIndexWhere((s) => s['type'] == 'drawing');
    if (i >= 0) setState(() => _stickers.removeAt(i));
  }

  // ---------- Saving and sharing ----------

  Future<String?> _captureOverlay() async {
    if (_stickers.isEmpty) return null;
    final box = _overlayKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (box == null) return null;
    final image = await box.toImage(pixelRatio: 720 / box.size.width);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) return null;
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png.buffer.asUint8List());
    return file.path;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await VideoEdit.saveToGallery(
        input: widget.path,
        isVideo: widget.isVideo,
        overlay: await _captureOverlay(),
        storyShape: true,
      );
      messenger
          .showSnackBar(const SnackBar(content: Text('Saved to your phone')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Couldn’t save this to your phone.')));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _share({required bool closeFriends}) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await File(widget.path).readAsBytes();
      final data = widget.isVideo
          ? 'data:video/mp4;base64,${base64Encode(bytes)}'
          : 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (data.length > (widget.isVideo ? 12000000 : 4000000)) {
        messenger.showSnackBar(SnackBar(
            content: Text(widget.isVideo
                ? 'This clip is too large. Trim it a little and try again.'
                : 'This photo is too large. Try another.')));
        if (mounted) setState(() => _busy = false);
        return;
      }
      await ApiClient.post('/feed', body: {
        'mediaType': widget.isVideo ? 'reel' : 'image',
        'text': '',
        'isStory': true,
        if (widget.isVideo) 'videoData': data else 'imageData': data,
        if (closeFriends) 'audience': 'closeFriends',
        'stickers': _stickers,
      });
      widget.onPosted?.call();
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Shared')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Couldn’t share this. Check your connection and try again.')));
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Building ----------

  Widget _media() {
    if (widget.isVideo) {
      final v = _video;
      if (v == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: v.value.size.width,
          height: v.value.size.height,
          child: VideoPlayer(v),
        ),
      );
    }
    return Image.file(File(widget.path), fit: BoxFit.cover);
  }

  Widget _sticker(Map<String, dynamic> s, Size frame) {
    return PlacedSticker(
      sticker: s,
      frame: frame,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: s['type'] == 'text' ? () => _editText(s) : null,
        onScaleStart: (d) {
          _startScale = (s['scale'] as num).toDouble();
          _startRotation = (s['rotation'] as num).toDouble();
          _grabOffset = null;
          setState(() => _dragging = s['id'] as String);
        },
        onScaleUpdate: (d) {
          final box =
              _overlayKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final at = box.globalToLocal(d.focalPoint);
          // Keeps the sticker under the finger from wherever it was held.
          _grabOffset ??= Offset(at.dx - (s['x'] as num) * frame.width,
              at.dy - (s['y'] as num) * frame.height);
          setState(() {
            s['x'] = ((at.dx - _grabOffset!.dx) / frame.width).clamp(0.0, 1.0);
            s['y'] = ((at.dy - _grabOffset!.dy) / frame.height).clamp(0.0, 1.0);
            s['scale'] = (_startScale * d.scale).clamp(0.3, 5.0);
            s['rotation'] = _startRotation + d.rotation;
            _overBin = at.dy > frame.height - 70 &&
                (at.dx - frame.width / 2).abs() < 60;
          });
        },
        onScaleEnd: (_) {
          setState(() {
            if (_overBin) _stickers.remove(s);
            _dragging = null;
            _overBin = false;
          });
        },
        // Drag anywhere on the sticker, not just its buttons.
        child: AbsorbPointer(child: StickerBody(sticker: s)),
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon,
                color: Colors.white,
                size: 28,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final drawings = _stickers.where((s) => s['type'] == 'drawing').toList();
    final others = _stickers.where((s) => s['type'] != 'drawing').toList();
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(children: [
          StoryFrame(
            child: LayoutBuilder(builder: (context, box) {
              final frame = box.biggest;
              return Stack(fit: StackFit.expand, children: [
                _media(),
                RepaintBoundary(
                  key: _overlayKey,
                  child: Stack(fit: StackFit.expand, children: [
                    if (drawings.isNotEmpty)
                      IgnorePointer(
                        child:
                            CustomPaint(painter: StoryDrawingPainter(drawings)),
                      ),
                    for (final s in others) _sticker(s, frame),
                  ]),
                ),
                if (_drawing)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _startLine(d.localPosition, frame),
                    onPanUpdate: (d) => _extendLine(d.localPosition, frame),
                    onPanEnd: (_) => _line = null,
                  ),
                if (_dragging != null)
                  Positioned(
                    bottom: 18,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: _overBin ? 58 : 44,
                        height: _overBin ? 58 : 44,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _overBin
                                ? const Color(0xFFE0364F)
                                : Colors.black54),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white),
                      ),
                    ),
                  ),
              ]);
            }),
          ),
          if (_drawing) ...[
            Positioned(
              top: 6,
              left: 6,
              right: 6,
              child: Row(children: [
                _tool(Icons.undo_rounded, 'Undo', _undoLine),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _drawing = false),
                  child: const Text('Done',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            Positioned(
              bottom: 24,
              left: 12,
              right: 12,
              child: _ColourRow(
                  selected: _drawColor,
                  onPick: (c) => setState(() => _drawColor = c)),
            ),
          ] else if (_dragging == null) ...[
            Positioned(
              top: 6,
              left: 6,
              child: _tool(Icons.arrow_back_rounded, 'Back',
                  () => Navigator.of(context).maybePop()),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Column(children: [
                _tool(Icons.text_fields_rounded, 'Text', () => _editText()),
                _tool(Icons.emoji_emotions_outlined, 'Stickers', _openTray),
                _tool(Icons.draw_outlined, 'Draw',
                    () => setState(() => _drawing = true)),
                if (_hasDrawing)
                  _tool(Icons.undo_rounded, 'Undo drawing', _undoLine),
                _tool(Icons.download_rounded, 'Save', _busy ? () {} : _save),
              ]),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 14,
              child: Row(children: [
                Expanded(
                  child: _ShareButton(
                    label: 'Your story',
                    filled: true,
                    onTap: _busy ? null : () => _share(closeFriends: false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShareButton(
                    label: 'Close friends',
                    onTap: _busy ? null : () => _share(closeFriends: true),
                  ),
                ),
              ]),
            ),
          ],
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  const _ShareButton({required this.label, this.filled = false, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: filled ? Colors.white : const Color(0xCC0B0912),
              borderRadius: BorderRadius.circular(24)),
          child: Text(label,
              style: TextStyle(
                  color: filled ? const Color(0xFF241338) : Colors.white,
                  fontWeight: FontWeight.w700)),
        ),
      );
}

class _ColourRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const _ColourRow({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final e in kStickerColors.entries)
            Semantics(
              button: true,
              selected: e.key == selected,
              label: e.key,
              child: GestureDetector(
                onTap: () => onPick(e.key),
                child: Container(
                  width: e.key == selected ? 32 : 26,
                  height: e.key == selected ? 32 : 26,
                  decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
            ),
        ],
      );
}

class StoryTextEditor extends StatefulWidget {
  final String text;
  final String color;
  final String font;
  const StoryTextEditor(
      {super.key, required this.text, required this.color, required this.font});

  @override
  State<StoryTextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<StoryTextEditor> {
  late final _controller = TextEditingController(text: widget.text);
  late String _color = widget.color;
  late String _font = widget.font;

  static const _fonts = {
    'classic': 'Classic',
    'bold': 'Bold',
    'neon': 'Neon',
    'type': 'Type',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop({
        'type': 'text',
        'text': _controller.text.trim(),
        'color': _color,
        'font': _font
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _done,
              child: const Text('Done',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  maxLength: 300,
                  textAlign: TextAlign.center,
                  cursorColor: Colors.white,
                  style: stickerFont(
                      _font, kStickerColors[_color] ?? Colors.white),
                  decoration: const InputDecoration(
                      border: InputBorder.none, counterText: ''),
                ),
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final f in _fonts.entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _font = f.key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: f.key == _font ? Colors.white : Colors.black54,
                        borderRadius: BorderRadius.circular(14)),
                    child: Text(f.value,
                        style: TextStyle(
                            color: f.key == _font
                                ? const Color(0xFF241338)
                                : Colors.white)),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: _ColourRow(
                selected: _color, onPick: (c) => setState(() => _color = c)),
          ),
        ]),
      ),
    );
  }
}

class _StickerTray extends StatelessWidget {
  const _StickerTray();

  static const _emoji = [
    '😀',
    '😂',
    '🥹',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤩',
    '🥳',
    '😭',
    '😡',
    '🤔',
    '🔥',
    '✨',
    '🎉',
    '💜',
    '❤️',
    '💔',
    '👑',
    '💯',
    '👏',
    '🙌',
    '🙏',
    '💪',
    '🎬',
    '🎵',
    '🎮',
    '🍿',
    '☕',
    '🍕',
    '🌙',
    '☀️',
    '🌈',
    '⭐',
    '🦋',
    '🐶',
  ];

  Future<void> _form(BuildContext context, String type) async {
    final navigator = Navigator.of(context);
    final result = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _StickerForm(type: type));
    if (result != null) navigator.pop({'type': type, ...result});
  }

  Widget _preview(
          BuildContext context, String type, String label, Color color) =>
      Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () => _form(context, type),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(11)),
            child: Text(label,
                maxLines: 1,
                style: const TextStyle(
                    color: Color(0xFF241338),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [
              _preview(context, 'poll', 'Poll', AppColors.lilac),
              _preview(context, 'question', 'Question', Colors.white),
              _preview(context, 'slider', '😍 Slider', const Color(0xFFFFC35A)),
              _preview(
                  context, 'countdown', 'Countdown', const Color(0xFFFF7AA8)),
              _preview(context, 'quiz', 'Quiz', AppColors.lilac),
              _preview(context, 'addyours', 'Add yours', Colors.white),
              _preview(context, 'mention', '@mention', Colors.white),
              _preview(context, 'hashtag', '#hashtag', const Color(0xFFFFC35A)),
              _preview(context, 'location', 'Location', Colors.white),
              _preview(context, 'link', 'Link', const Color(0xFF5AD6A8)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final e in _emoji)
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pop({'type': 'emoji', 'emoji': e}),
                  child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 30))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for what one sticker needs, and checks it before placing it.
class _StickerForm extends StatefulWidget {
  final String type;
  const _StickerForm({required this.type});

  @override
  State<_StickerForm> createState() => _StickerFormState();
}

class _StickerFormState extends State<_StickerForm> {
  final _main = TextEditingController();
  final _second = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(text: 'Yes'),
    TextEditingController(text: 'No'),
  ];
  int _answer = 0;
  DateTime _at = DateTime.now().add(const Duration(days: 1));
  String? _error;

  @override
  void dispose() {
    _main.dispose();
    _second.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  bool get _hasOptions => widget.type == 'poll' || widget.type == 'quiz';

  String get _title => switch (widget.type) {
        'poll' => 'Poll',
        'quiz' => 'Quiz',
        'question' => 'Question',
        'slider' => 'Slider',
        'countdown' => 'Countdown',
        'addyours' => 'Add yours',
        'mention' => 'Mention someone',
        'hashtag' => 'Hashtag',
        'location' => 'Location',
        _ => 'Link',
      };

  String get _hint => switch (widget.type) {
        'poll' => 'Movie tonight?',
        'quiz' => 'What’s my favourite film?',
        'question' => 'Ask me anything',
        'slider' => 'How much do you like this?',
        'countdown' => 'Party starts in',
        'addyours' => 'Show your pet',
        'mention' => 'username',
        'hashtag' => 'weekend',
        'location' => 'Chennai',
        _ => 'https://example.com',
      };

  void _submit() {
    final text = _main.text.trim();
    Map<String, dynamic>? out;
    String? error;
    switch (widget.type) {
      case 'poll':
      case 'quiz':
        final opts = _options
            .map((o) => o.text.trim())
            .where((o) => o.isNotEmpty)
            .toList();
        if (opts.length < 2) {
          error = 'Add at least two options.';
        } else {
          out = {'question': text, 'options': opts};
          if (widget.type == 'quiz') {
            out['answer'] = _answer.clamp(0, opts.length - 1);
          }
        }
      case 'question':
      case 'addyours':
        if (text.isEmpty) {
          error = 'Write a prompt first.';
        } else {
          out = {'question': text};
        }
      case 'slider':
        out = {'question': text, 'emoji': '😍'};
      case 'countdown':
        out = {'title': text, 'at': _at.toUtc().toIso8601String()};
      case 'mention':
        final name = text.replaceFirst('@', '');
        if (!RegExp(r'^\w{2,32}$').hasMatch(name)) {
          error = 'Enter a username.';
        } else {
          out = {'username': name};
        }
      case 'hashtag':
        final tag = text.replaceFirst('#', '');
        if (tag.isEmpty || tag.contains(' ')) {
          error = 'Enter one word, without spaces.';
        } else {
          out = {'tag': tag};
        }
      case 'location':
        if (text.isEmpty) {
          error = 'Enter a place.';
        } else {
          out = {'place': text};
        }
      case 'link':
        final uri = Uri.tryParse(text);
        if (uri == null ||
            !(uri.scheme == 'https' || uri.scheme == 'http') ||
            uri.host.isEmpty) {
          error = 'Enter a full link, starting with https://';
        } else {
          out = {'url': text, 'label': _second.text.trim()};
        }
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(out);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (time == null || !mounted) return;
    setState(() => _at =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          widget.type == 'mention'
              ? MentionTextField(controller: _main, hintText: '@$_hint')
              : TextField(
                  controller: _main,
                  autofocus: true,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(hintText: _hint),
                ),
          if (_hasOptions) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < _options.length; i++)
              Row(children: [
                if (widget.type == 'quiz')
                  // ignore: deprecated_member_use
                  Radio<int>(
                    value: i,
                    // ignore: deprecated_member_use
                    groupValue: _answer,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => _answer = v ?? 0),
                  ),
                Expanded(
                  child: TextField(
                    controller: _options[i],
                    maxLength: 40,
                    decoration: InputDecoration(
                        hintText: 'Option ${i + 1}', counterText: ''),
                  ),
                ),
              ]),
            if (_options.length < 4)
              TextButton(
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                child: const Text('Add option'),
              ),
            if (widget.type == 'quiz')
              const Text('Select the correct answer.',
                  style: TextStyle(fontSize: 12)),
          ],
          if (widget.type == 'countdown')
            TextButton(
              onPressed: _pickDate,
              child: Text(
                  'Ends ${_at.day}/${_at.month}/${_at.year} at ${TimeOfDay.fromDateTime(_at).format(context)}'),
            ),
          if (widget.type == 'link')
            TextField(
              controller: _second,
              maxLength: 40,
              decoration: const InputDecoration(
                  hintText: 'Button text (optional)', counterText: ''),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
