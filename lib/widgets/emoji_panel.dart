import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/insync_icons.dart';
import 'animated_emoji.dart';
import 'animated_emoji_bundled.dart';

/// Every emoji in 4 rows that scroll sideways, 5 columns on screen at a
/// time: Recent first, then each group, with search and a strip of group
/// icons to jump. Used for reacting to a chat message and for typing
/// emoji in the chat box.
class EmojiPanel extends StatefulWidget {
  final ValueChanged<String> onPick;
  const EmojiPanel({super.key, required this.onPick});

  static const rows = 4;
  static const columns = 5;

  /// The panel's height for a given width (search line + label + grid).
  static double heightFor(double width) =>
      44 + 18 + _rowHeight(width) * rows + 12;
  static double _rowHeight(double width) => (width / columns) * 0.82;

  static const _prefsKey = 'emoji_recent';
  static List<String> _recent = const [];
  static bool _recentLoaded = false;

  /// Remembers [emoji] at the front of Recent.
  static Future<void> remember(String emoji) async {
    _recent = [emoji, ..._recent.where((e) => e != emoji)].take(24).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _recent);
    } catch (_) {}
  }

  static Future<void> _loadRecent() async {
    if (_recentLoaded) return;
    _recentLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _recent = prefs.getStringList(_prefsKey) ?? const [];
    } catch (_) {}
  }

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

// Group → the icon in the strip (an emoji itself, so it reads at a glance).
const _groupIcons = {
  'Recent': '🕘',
  'Smileys and emotions': '😀',
  'People': '🙋',
  'Animals and nature': '🐶',
  'Food and drink': '🍕',
  'Travel and places': '✈️',
  'Activities and events': '⚽',
  'Objects': '💡',
  'Symbols': '❤️',
  'Flags': '🏁',
};

// Everyday words that should find an emoji its name doesn't say.
const _alsoKnownAs = {
  'lit': 'fire',
  'hot': 'fire',
  'flame': 'fire',
  'lol': 'joy',
  'haha': 'laugh',
  'laugh': 'joy',
  'love': 'heart',
  'wow': 'surprise',
  'omg': 'scream',
  'thanks': 'pray',
  'please': 'pray',
  'yes': 'thumbs up',
  'no': 'thumbs down',
  'cool': 'sunglasses',
  'party': 'party',
  'bday': 'birthday',
  'money': 'money',
  'sad': 'cry',
  'angry': 'rage',
  'sleep': 'sleep',
  'dance': 'danc',
  'music': 'music',
  'clap': 'clap',
  'ok': 'ok',
};

const _defaultRecent = ['❤️', '😂', '🔥', '😮', '😢', '👏', '🥹', '😍'];

class _EmojiPanelState extends State<EmojiPanel> {
  final _scroll = ScrollController();
  final _query = TextEditingController();
  bool _searching = false;
  String _current = 'Recent';
  // Column where each group starts (groups begin on a fresh column).
  Map<String, int> _starts = const {};
  late final Map<String, String> _names = {
    for (final e in AnimatedEmojiRegistry.entries) e.emoji: e.name,
  };

  @override
  void initState() {
    super.initState();
    EmojiPanel._loadRecent().then((_) {
      if (mounted) setState(() {});
    });
    _scroll.addListener(_trackGroup);
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  List<(String, List<String>)> _groups() {
    final byGroup = <String, List<String>>{};
    for (final e in AnimatedEmojiRegistry.entries) {
      byGroup.putIfAbsent(e.category, () => []).add(e.emoji);
    }
    return [
      (
        'Recent',
        EmojiPanel._recent.isNotEmpty ? EmojiPanel._recent : _defaultRecent
      ),
      for (final g in byGroup.entries) (g.key, g.value),
    ];
  }

  List<String> _results() {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final terms = {q, if (_alsoKnownAs[q] != null) _alsoKnownAs[q]!};
    return [
      for (final e in AnimatedEmojiRegistry.entries)
        if (terms.any((t) => e.name.toLowerCase().contains(t))) e.emoji,
    ];
  }

  double _colWidth = 60;

  void _trackGroup() {
    if (_searching || !_scroll.hasClients) return;
    final col = (_scroll.offset / _colWidth).round();
    var now = 'Recent';
    for (final s in _starts.entries) {
      if (s.value <= col) now = s.key;
    }
    if (now != _current) setState(() => _current = now);
  }

  void _jump(String group) {
    final col = _starts[group];
    if (col == null || !_scroll.hasClients) return;
    _scroll.animateTo(
      (col * _colWidth).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    setState(() => _current = group);
  }

  void _pick(String e) {
    EmojiPanel.remember(e);
    widget.onPick(e);
  }

  Widget _cell(String e, double rowH) {
    final file = AnimatedEmojiRegistry.fileFor(e);
    final bundled = file != null && kBundledEmojiFiles.contains(file);
    final size = rowH * 0.7;
    return Semantics(
      button: true,
      label: _names[e] ?? e,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => _pick(e),
        radius: rowH * 0.55,
        child: Center(
          child: bundled
              ? SizedBox.square(
                  dimension: size,
                  child: Lottie.asset(
                      '${AnimatedEmojiRegistry.assetDir}$file',
                      repeat: false,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(e,
                          style: TextStyle(fontSize: size * 0.8, height: 1))),
                )
              : Text(e,
                  style: TextStyle(fontSize: size * 0.8, height: 1),
                  textScaler: TextScaler.noScaling),
        ),
      ),
    );
  }

  Widget _topLine() {
    if (_searching) {
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF272727),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFFFFF)),
        ),
        child: Row(children: [
          IconButton(
            tooltip: 'Back to all emoji',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              _searching = false;
              _query.clear();
            }),
            icon: const InIcon(InIcons.back, size: 16, color: Colors.white70),
          ),
          Expanded(
            child: TextField(
              controller: _query,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search emoji',
                hintStyle: TextStyle(color: Color(0xFF939393)),
              ),
            ),
          ),
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              visualDensity: VisualDensity.compact,
              onPressed: _query.clear,
              icon:
                  const InIcon(InIcons.close, size: 15, color: Colors.white70),
            ),
        ]),
      );
    }
    return SizedBox(
      height: 36,
      child: Row(children: [
        Semantics(
          button: true,
          label: 'Search emoji',
          child: InkResponse(
            onTap: () => setState(() => _searching = true),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                  color: Color(0xFF2F2F2F), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const InIcon(InIcons.search, size: 16, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final g in _groupIcons.entries)
                if (g.key == 'Recent' || _starts.containsKey(g.key))
                  Semantics(
                    button: true,
                    selected: _current == g.key,
                    label: g.key,
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => _jump(g.key),
                      radius: 18,
                      child: Opacity(
                        opacity: _current == g.key ? 1 : 0.45,
                        child: Text(g.value,
                            style: const TextStyle(fontSize: 16, height: 1),
                            textScaler: TextScaler.noScaling),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      _colWidth = w / EmojiPanel.columns;
      final rowH = EmojiPanel._rowHeight(w);
      final cells = <String?>[];
      final starts = <String, int>{};
      String label;
      if (_searching) {
        cells.addAll(_results());
        label = _query.text.trim().isEmpty
            ? 'Type to search'
            : cells.isEmpty
                ? 'No emoji found'
                : 'Results';
      } else {
        for (final (name, list) in _groups()) {
          if (list.isEmpty) continue;
          starts[name] = cells.length ~/ EmojiPanel.rows;
          cells.addAll(list);
          while (cells.length % EmojiPanel.rows != 0) {
            cells.add(null);
          }
        }
        _starts = starts;
        label = _current == 'Smileys and emotions' ? 'Smileys' : _current;
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
            child: _topLine(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: Text(label,
                style: const TextStyle(color: Color(0xFF939393), fontSize: 11)),
          ),
          SizedBox(
            height: rowH * EmojiPanel.rows,
            child: GridView.builder(
              key: ValueKey(_searching),
              controller: _searching ? null : _scroll,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: EmojiPanel.rows,
                mainAxisExtent: _colWidth,
              ),
              itemCount: cells.length,
              itemBuilder: (context, i) {
                final e = cells[i];
                return e == null ? const SizedBox.shrink() : _cell(e, rowH);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    });
  }
}

/// The long-press sheet's emoji: 7 across, 4 rows showing, scrolling down,
/// with a search bar on top. [leading] go first (e.g. watch emoji on Now
/// Playing), then Recent, then everything else.
class EmojiSheetGrid extends StatefulWidget {
  final ValueChanged<String> onPick;
  final List<String> leading;
  const EmojiSheetGrid(
      {super.key, required this.onPick, this.leading = const []});

  static const columns = 7;
  static const rows = 4;

  @override
  State<EmojiSheetGrid> createState() => _EmojiSheetGridState();
}

class _EmojiSheetGridState extends State<EmojiSheetGrid> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    EmojiPanel._loadRecent().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<String> _all() {
    final q = _query.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final terms = {q, if (_alsoKnownAs[q] != null) _alsoKnownAs[q]!};
      return [
        for (final e in AnimatedEmojiRegistry.entries)
          if (terms.any((t) => e.name.toLowerCase().contains(t))) e.emoji,
      ];
    }
    final seen = <String>{};
    return [
      for (final e in [
        ...widget.leading,
        ...(EmojiPanel._recent.isNotEmpty
            ? EmojiPanel._recent
            : _defaultRecent),
        ...AnimatedEmojiRegistry.entries.map((x) => x.emoji),
      ])
        if (seen.add(e)) e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cell = box.maxWidth / EmojiSheetGrid.columns;
      final items = _all();
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 40,
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixIcon: Padding(
                padding: EdgeInsets.only(right: 8),
                child: InIcon(InIcons.search, size: 20, color: Colors.white),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 30),
              hintText: 'Search',
              hintStyle: TextStyle(color: Color(0xFF939393), fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: cell * EmojiSheetGrid.rows,
          child: items.isEmpty
              ? const Center(
                  child: Text('No emoji found',
                      style: TextStyle(color: Color(0xFF939393))))
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: EmojiSheetGrid.columns,
                    mainAxisExtent: cell,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    final file = AnimatedEmojiRegistry.fileFor(e);
                    final bundled =
                        file != null && kBundledEmojiFiles.contains(file);
                    final size = cell * 0.72;
                    return InkResponse(
                      radius: cell * 0.5,
                      onTap: () {
                        EmojiPanel.remember(e);
                        widget.onPick(e);
                      },
                      child: Center(
                        child: bundled
                            ? SizedBox.square(
                                dimension: size,
                                child: Lottie.asset(
                                    '${AnimatedEmojiRegistry.assetDir}$file',
                                    repeat: false,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Text(e,
                                        style: TextStyle(
                                            fontSize: size * 0.8, height: 1))),
                              )
                            : Text(e,
                                style:
                                    TextStyle(fontSize: size * 0.8, height: 1),
                                textScaler: TextScaler.noScaling),
                      ),
                    );
                  },
                ),
        ),
      ]);
    });
  }
}
