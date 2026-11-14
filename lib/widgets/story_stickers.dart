import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/profile_nav.dart';
import '../screens/feed/hashtag_screen.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// Stories are shown in one fixed shape, so a sticker sits in the same place
/// on every phone. Sticker positions are shares of this frame.
const double kStoryAspect = 9 / 16;

/// The story's picture area: as large as fits, in the story shape.
class StoryFrame extends StatelessWidget {
  final Widget child;
  const StoryFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: AspectRatio(
          aspectRatio: kStoryAspect,
          child: ClipRect(child: child),
        ),
      );
}

const kStickerColors = <String, Color>{
  'white': Colors.white,
  'black': Color(0xFF0B0912),
  'lilac': Color(0xFFC4A8FF),
  'pink': Color(0xFFFF7AA8),
  'amber': Color(0xFFFFC35A),
  'green': Color(0xFF5AD6A8),
  'blue': Color(0xFF62A8FF),
};

/// Text styles offered in the editor, by the name saved on the sticker.
TextStyle stickerFont(String? font, Color color) => switch (font) {
      'bold' => TextStyle(
          color: color, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1),
      'neon' => TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.1,
          shadows: [Shadow(color: color, blurRadius: 14)]),
      'type' => TextStyle(
          color: color, fontSize: 24, fontFamily: 'monospace', height: 1.2),
      _ => TextStyle(
          color: color,
          fontSize: 26,
          fontWeight: FontWeight.w500,
          height: 1.15),
    };

/// A freehand line, drawn from flat x,y shares of the frame.
class StoryDrawingPainter extends CustomPainter {
  final List<Map<String, dynamic>> drawings;
  const StoryDrawingPainter(this.drawings);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in drawings) {
      final points = (d['points'] as List).cast<num>();
      if (points.length < 2) continue;
      final paint = Paint()
        ..color = kStickerColors[d['color']] ?? Colors.white
        ..strokeWidth = ((d['width'] as num?) ?? 6).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(points[0] * size.width, points[1] * size.height);
      for (var i = 2; i + 1 < points.length; i += 2) {
        path.lineTo(points[i] * size.width, points[i + 1] * size.height);
      }
      if (points.length == 2) {
        path.lineTo(points[0] * size.width + 0.01, points[1] * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(StoryDrawingPainter old) => true;
}

/// The look of one sticker, shared by the editor and the viewer. Without
/// [onAnswer] it is a picture of itself, as in the editor.
class StickerBody extends StatelessWidget {
  final Map<String, dynamic> sticker;
  final Map<String, dynamic>? result;
  final void Function(Object value)? onAnswer;
  final VoidCallback? onAskQuestion;
  final VoidCallback? onTap;
  // Add Yours: the list of people who joined.
  final VoidCallback? onSeeAll;
  const StickerBody({
    super.key,
    required this.sticker,
    this.result,
    this.onAnswer,
    this.onAskQuestion,
    this.onTap,
    this.onSeeAll,
  });

  static const _ink = Color(0xFF241338);

  Widget _card(
      {required Widget child, Color header = AppColors.lilac, String? title}) {
    return Container(
      width: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (title != null && title.isNotEmpty)
          Container(
            width: double.infinity,
            color: header,
            padding: const EdgeInsets.all(12),
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        child,
      ]),
    );
  }

  Widget _options() {
    final options = (sticker['options'] as List).cast<String>();
    final counts = (result?['counts'] as List?)?.cast<num>();
    final mine = result?['mine'] as String?;
    final answer = result?['answer'] as int? ?? sticker['answer'] as int?;
    final total = (result?['total'] as num?)?.toInt() ?? 0;
    final answered = mine != null;
    final quiz = sticker['type'] == 'quiz';
    return Column(children: [
      for (var i = 0; i < options.length; i++)
        Semantics(
          button: !answered,
          label: options[i],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: answered || onAnswer == null ? null : () => onAnswer!(i),
            child: Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE4DEF0)))),
              child: Stack(children: [
                if (answered && total > 0 && counts != null)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: counts[i] / total,
                      child: ColoredBox(
                          color: quiz && answer == i
                              ? const Color(0xFFBDF0DA)
                              : const Color(0xFFE9DEFC)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                      child: Text(options[i],
                          style: TextStyle(
                              color: _ink,
                              fontWeight: mine == '$i'
                                  ? FontWeight.w800
                                  : FontWeight.w500)),
                    ),
                    if (answered && total > 0 && counts != null)
                      Text('${(counts[i] / total * 100).round()}%',
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _slider() {
    final mine = double.tryParse('${result?['mine'] ?? ''}');
    final average = (result?['average'] as num?)?.toDouble();
    final emoji = sticker['emoji'] as String? ?? '😍';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      child: Column(children: [
        _EmojiSlider(
          emoji: emoji,
          fixed: mine,
          onDone: onAnswer == null ? null : (v) => onAnswer!(v.round()),
        ),
        if (average != null && mine != null)
          Text('Average $average%'.replaceAll('.0%', '%'),
              style: const TextStyle(color: _ink, fontSize: 12)),
      ]),
    );
  }

  Widget _chip(String text, IconData icon) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: const Color(0xFF6D3FD0)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF6D3FD0),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    switch (sticker['type']) {
      case 'emoji':
        return Text(sticker['emoji'] as String,
            style: const TextStyle(fontSize: 64));
      case 'text':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(sticker['text'] as String,
              textAlign: TextAlign.center,
              style: stickerFont(sticker['font'] as String?,
                  kStickerColors[sticker['color']] ?? Colors.white)),
        );
      case 'poll':
      case 'quiz':
        return _card(title: sticker['question'] as String?, child: _options());
      case 'slider':
        return _card(
            title: sticker['question'] as String?,
            header: const Color(0xFFFFC35A),
            child: _slider());
      case 'question':
        return _card(
          title: sticker['question'] as String?,
          child: GestureDetector(
            onTap: onAskQuestion,
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: const Color(0xFFF0ECF8),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                  result?['mine'] != null ? 'Answer sent' : 'Type something…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B6480))),
            ),
          ),
        );
      case 'addyours':
        final joined = (result?['total'] as num?)?.toInt() ?? 0;
        return _card(
          title: sticker['question'] as String?,
          header: const Color(0xFFFF7AA8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Center(
                  child: Text('Add yours',
                      style:
                          TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            if (joined > 0)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                      joined == 1 ? '1 person joined' : '$joined people joined',
                      style: const TextStyle(
                          color: Color(0xFF6B6480),
                          fontSize: 12,
                          decoration: TextDecoration.underline)),
                ),
              ),
          ]),
        );
      case 'countdown':
        return _card(
          title: sticker['title'] as String?,
          header: const Color(0xFFFF7AA8),
          child: _Countdown(at: DateTime.parse(sticker['at'] as String)),
        );
      case 'mention':
        return _chip('@${sticker['username']}', Icons.alternate_email_rounded);
      case 'hashtag':
        return _chip('#${sticker['tag']}', Icons.tag_rounded);
      case 'location':
        return _chip(sticker['place'] as String, Icons.place_rounded);
      case 'link':
        final label = sticker['label'] as String? ?? '';
        final host = Uri.tryParse(sticker['url'] as String)?.host ?? '';
        return _chip(label.isNotEmpty ? label : host, Icons.link_rounded);
    }
    return const SizedBox.shrink();
  }
}

class _EmojiSlider extends StatefulWidget {
  final String emoji;
  final double? fixed;
  final ValueChanged<double>? onDone;
  const _EmojiSlider({required this.emoji, this.fixed, this.onDone});

  @override
  State<_EmojiSlider> createState() => _EmojiSliderState();
}

class _EmojiSliderState extends State<_EmojiSlider> {
  double _value = 50;

  @override
  Widget build(BuildContext context) {
    final locked = widget.fixed != null;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: const Color(0xFFFF7AA8),
        inactiveTrackColor: const Color(0xFFEDE7F7),
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: _EmojiThumb(widget.emoji),
        disabledActiveTrackColor: const Color(0xFFFF7AA8),
        disabledInactiveTrackColor: const Color(0xFFEDE7F7),
      ),
      child: SizedBox(
        height: 46,
        child: Slider(
          min: 0,
          max: 100,
          value: widget.fixed ?? _value,
          onChanged: locked || widget.onDone == null
              ? null
              : (v) => setState(() => _value = v),
          onChangeEnd: locked ? null : widget.onDone,
        ),
      ),
    );
  }
}

class _EmojiThumb extends SliderComponentShape {
  final String emoji;
  const _EmojiThumb(this.emoji);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(36, 36);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 30)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(context.canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}

class _Countdown extends StatelessWidget {
  final DateTime at;
  const _Countdown({required this.at});

  String _left() {
    final d = at.difference(DateTime.now());
    if (d.isNegative) return 'Time’s up';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes.clamp(1, 59)}m';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_left(),
            style: const TextStyle(
                color: Color(0xFF241338),
                fontSize: 24,
                fontWeight: FontWeight.w800)),
      );
}

/// Places a sticker at its saved spot, size and tilt inside [StoryFrame].
class PlacedSticker extends StatelessWidget {
  final Map<String, dynamic> sticker;
  final Size frame;
  final Widget child;
  const PlacedSticker(
      {super.key,
      required this.sticker,
      required this.frame,
      required this.child});

  @override
  Widget build(BuildContext context) {
    // Sized against a phone-width frame, so it looks the same on every screen.
    final unit = frame.width / 360;
    return Positioned(
      left: (sticker['x'] as num) * frame.width,
      top: (sticker['y'] as num) * frame.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: ((sticker['rotation'] as num?) ?? 0).toDouble(),
          child: Transform.scale(
            scale: ((sticker['scale'] as num?) ?? 1).toDouble() * unit,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A story's stickers for someone watching it: votes, answers and links work.
class StoryStickerLayer extends StatefulWidget {
  final String storyId;
  final List<Map<String, dynamic>> stickers;
  final bool isAuthor;

  /// Holds the story's timer while someone is typing or reading.
  final VoidCallback onPause;
  final VoidCallback onResume;
  final void Function(String prompt, String? chainId)? onAddYours;
  const StoryStickerLayer({
    super.key,
    required this.storyId,
    required this.stickers,
    required this.isAuthor,
    required this.onPause,
    required this.onResume,
    this.onAddYours,
  });

  @override
  State<StoryStickerLayer> createState() => _StoryStickerLayerState();
}

class _StoryStickerLayerState extends State<StoryStickerLayer> {
  Map<String, dynamic> _results = const {};

  static const _answerable = {'poll', 'quiz', 'slider', 'question'};

  @override
  void initState() {
    super.initState();
    if (widget.stickers.any((s) => _answerable.contains(s['type']))) _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/feed/${widget.storyId}/stickers');
      if (mounted) setState(() => _results = Map.from(data as Map));
    } catch (_) {
      // The stickers still show; answering will report any real problem.
    }
  }

  Future<void> _answer(String id, Object value) async {
    try {
      final data = await ApiClient.post(
          '/feed/${widget.storyId}/stickers/$id/respond',
          body: {'value': value});
      if (mounted) {
        setState(() => _results = {..._results, id: data});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.message
                : 'Couldn’t send that. Try again.')));
      }
    }
  }

  Future<void> _askQuestion(Map<String, dynamic> s) async {
    final messenger = ScaffoldMessenger.of(context);
    widget.onPause();
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s['question'] as String,
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 300,
            decoration: const InputDecoration(hintText: 'Your answer'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Send')),
          ),
        ]),
      ),
    );
    controller.dispose();
    widget.onResume();
    if (text != null && text.isNotEmpty) {
      await _answer(s['id'] as String, text);
      messenger.showSnackBar(const SnackBar(content: Text('Answer sent')));
    }
  }

  Future<void> _openLink(Map<String, dynamic> s) async {
    final url = s['url'] as String;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    widget.onPause();
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open this link?'),
        content: Text('You’re leaving the app for ${uri.host}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open')),
        ],
      ),
    );
    widget.onResume();
    if (open == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // The story stays paused behind whatever opens.
  void _leaveTo(VoidCallback open) {
    widget.onPause();
    open();
  }

  // The author taps a sticker to see who answered what.
  // Everyone who answered this Add Yours prompt; tap someone for their
  // profile.
  Future<void> _showJoined(Map<String, dynamic> s) async {
    final people =
        ((_results[s['id']] as Map?)?['people'] as List? ?? []).cast<Map>();
    widget.onPause();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text('${s['question']}',
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          if (people.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Text('Nobody has joined yet. Be the first.',
                  style: TextStyle(color: AppColors.textDim)),
            ),
          for (final p in people)
            ListTile(
              leading: Avatar(
                  src: p['avatarUrl'] as String?,
                  name: p['name'] as String?,
                  size: AvatarSize.sm),
              title: Text('${p['name']}',
                  style: const TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.of(ctx).pop();
                _leaveTo(() => openProfile(context, p['userId'] as String));
              },
            ),
        ]),
      ),
    );
    widget.onResume();
  }

  Future<void> _showResponses(Map<String, dynamic> s) async {
    final r = _results[s['id']] as Map?;
    final rows = (r?['responses'] as List? ?? []).cast<Map>();
    final options = (s['options'] as List?)?.cast<String>();
    String label(Map row) {
      final v = '${row['value']}';
      if (options != null) return options[int.parse(v)];
      return s['type'] == 'slider' ? '$v%' : v;
    }

    widget.onPause();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      builder: (ctx) => SafeArea(
        child: rows.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(28),
                child: Text('No answers yet.',
                    style: TextStyle(color: AppColors.textDim)))
            : ListView(shrinkWrap: true, children: [
                for (final row in rows)
                  ListTile(
                    title: Text('${row['name']}',
                        style: const TextStyle(color: AppColors.text)),
                    subtitle: Text(label(row),
                        style: const TextStyle(color: AppColors.textDim)),
                  ),
              ]),
      ),
    );
    widget.onResume();
  }

  @override
  Widget build(BuildContext context) {
    final drawings =
        widget.stickers.where((s) => s['type'] == 'drawing').toList();
    final others =
        widget.stickers.where((s) => s['type'] != 'drawing').toList();
    return LayoutBuilder(builder: (context, box) {
      final frame = box.biggest;
      return Stack(fit: StackFit.expand, children: [
        if (drawings.isNotEmpty)
          IgnorePointer(
              child: CustomPaint(painter: StoryDrawingPainter(drawings))),
        for (final s in others)
          PlacedSticker(
            sticker: s,
            frame: frame,
            child: _body(s),
          ),
      ]);
    });
  }

  Widget _body(Map<String, dynamic> s) {
    final id = s['id'] as String;
    final type = s['type'];
    final answerable = _answerable.contains(type);
    final body = StickerBody(
      sticker: s,
      result: _results[id] as Map<String, dynamic>?,
      onAnswer: widget.isAuthor ? null : (v) => _answer(id, v),
      onAskQuestion: widget.isAuthor || _results[id]?['mine'] != null
          ? null
          : () => _askQuestion(s),
      onTap: switch (type) {
        'link' => () => _openLink(s),
        'mention' when s['userId'] != null => () =>
            _leaveTo(() => openProfile(context, s['userId'] as String)),
        'hashtag' => () => _leaveTo(() => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => HashtagScreen(tag: s['tag'] as String)))),
        'addyours' => widget.onAddYours == null
            ? null
            : () => widget.onAddYours!(
                s['question'] as String, s['chainId'] as String?),
        _ => null,
      },
      onSeeAll: type == 'addyours' ? () => _showJoined(s) : null,
    );
    if (widget.isAuthor && answerable) {
      return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showResponses(s),
          child: AbsorbPointer(child: body));
    }
    return body;
  }
}
