import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../theme/insync_icons.dart';
import 'app_image.dart';

// YouTube-style lists for the source picker and profile: History, Liked
// and Playlists. Black, big 16:9 thumbnails on the left, two-line titles.

const _bg = Color(0xFF0F0F0F);
const _chipBg = Color(0xFF272727);
const _dim = Color(0xFFAAAAAA);

const kSourceNames = {
  'youtube': 'YouTube',
  'youtube_surf': 'YouTube',
  'youtube_music': 'Music',
  'drive': 'Drive',
  'netflix': 'Netflix',
  'amazon': 'Prime Video',
  'hotstar': 'Hotstar',
  'sonyliv': 'SonyLIV',
  'sunnxt': 'SunNXT',
  'aha': 'Aha',
  'airtel': 'Airtel Xstream',
  'crunchyroll': 'Crunchyroll',
};

const _sourceColors = {
  'youtube': Color(0xFFFF0033),
  'youtube_surf': Color(0xFFFF0033),
  'youtube_music': Color(0xFFFF0033),
  'drive': Color(0xFF1E8E3E),
  'netflix': Color(0xFFE50914),
  'amazon': Color(0xFF1A98FF),
  'hotstar': Color(0xFF0F1E5C),
};

String _sourceOf(Map<String, dynamic> m) {
  final s = m['sourceType'] as String? ?? 'youtube';
  return m['music'] == true && s.startsWith('youtube') ? 'youtube_music' : s;
}

Widget _sourceBadge(String source) => Container(
      width: 14,
      height: 10,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
          color: _sourceColors[source] ?? const Color(0xFF4A4560),
          borderRadius: BorderRadius.circular(2)),
    );

/// A 16:9 thumbnail with an optional corner label.
class YtThumb extends StatelessWidget {
  final String? src;
  final double width;
  final String? corner;
  final IconData? cornerIcon;
  final String? rank;
  const YtThumb(
      {super.key,
      required this.src,
      this.width = 128,
      this.corner,
      this.cornerIcon,
      this.rank});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: Color(0xFF222222)),
          if (src != null && src!.isNotEmpty)
            AppImage(source: src, fit: BoxFit.cover)
          else
            const Center(
                child: InIcon(InIcons.music, size: 22, color: Colors.white38)),
          if (rank != null)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: const BoxDecoration(
                    color: Color(0xC0000000),
                    borderRadius:
                        BorderRadius.only(bottomRight: Radius.circular(8))),
                child: Text(rank!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          if (corner != null)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: rank != null
                        ? const Color(0xFFFF0033)
                        : const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(3)),
                child: Text(corner!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }
}

Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
              color: on ? Colors.white : _chipBg,
              borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );

typedef YtAdd = void Function(Map<String, dynamic> song);

/// History or Liked, YouTube style. [rows] are the raw API rows.
class YtSongList extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final bool history;
  final YtAdd? onAdd;
  final void Function(List<Map<String, dynamic>> songs)? onAddAll;
  final Future<void> Function(Map<String, dynamic> song)? onRemove;
  final Future<void> Function()? onClear;
  const YtSongList(
      {super.key,
      required this.rows,
      required this.history,
      this.onAdd,
      this.onAddAll,
      this.onRemove,
      this.onClear});

  @override
  State<YtSongList> createState() => _YtSongListState();
}

class _YtSongListState extends State<YtSongList> {
  String _source = 'all';
  bool _searching = false;
  final _query = TextEditingController();
  late List<Map<String, dynamic>> _rows = [...widget.rows];

  @override
  void didUpdateWidget(covariant YtSongList old) {
    super.didUpdateWidget(old);
    if (old.rows != widget.rows) _rows = [...widget.rows];
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _shown {
    final q = _query.text.trim().toLowerCase();
    return [
      for (final r in _rows)
        if ((_source == 'all' || kSourceNames[_sourceOf(r)] == _source) &&
            (q.isEmpty || '${r['title'] ?? ''}'.toLowerCase().contains(q)))
          r,
    ];
  }

  String _section(DateTime? t) {
    if (t == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    if (diff < 31) return 'This month';
    return 'Earlier';
  }

  int _count(Map<String, dynamic> r) =>
      (r['watchCount'] as num?)?.toInt() ?? 1;

  Future<void> _remove(Map<String, dynamic> r) async {
    setState(() => _rows.remove(r));
    await widget.onRemove?.call(r);
  }

  void _menu(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.onAdd != null)
            ListTile(
              leading: const InIcon(InIcons.queue, color: Colors.white),
              title: const Text('Add to queue',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(sheet).pop();
                widget.onAdd!(r);
              },
            ),
          if (widget.onRemove != null)
            ListTile(
              leading: InIcon(widget.history ? InIcons.close : InIcons.heart,
                  color: Colors.white),
              title: Text(
                  widget.history ? 'Remove from history' : 'Unlike',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(sheet).pop();
                _remove(r);
              },
            ),
        ]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final src = _sourceOf(r);
    final count = _count(r);
    return InkWell(
      onTap: widget.onAdd == null ? null : () => widget.onAdd!(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          YtThumb(src: r['thumbnail'] as String?),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['title'] as String? ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.3)),
                const SizedBox(height: 3),
                Row(children: [
                  _sourceBadge(src),
                  Flexible(
                    child: Text(kSourceNames[src] ?? 'Video',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _dim, fontSize: 11.5)),
                  ),
                ]),
                if (widget.history)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                        count == 1 ? 'Watched once' : 'Watched $count times',
                        style: const TextStyle(color: _dim, fontSize: 11.5)),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'More',
            visualDensity: VisualDensity.compact,
            onPressed: () => _menu(r),
            icon: const InIcon(InIcons.more, size: 18, color: Colors.white70),
          ),
        ]),
      ),
    );
  }

  Widget _mostWatched(List<Map<String, dynamic>> shown) {
    final top = [...shown.where((r) => _count(r) > 1)]
      ..sort((a, b) => _count(b).compareTo(_count(a)));
    if (top.isEmpty) return const SizedBox.shrink();
    final list = top.take(10).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Text('Most watched',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ),
      SizedBox(
        height: 66 + 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final r = list[i];
            return InkWell(
              onTap: widget.onAdd == null ? null : () => widget.onAdd!(r),
              child: SizedBox(
                width: 118,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YtThumb(
                        src: r['thumbnail'] as String?,
                        width: 118,
                        rank: '${i + 1}',
                        corner: '\u{1F441} ${_count(r)}'),
                    const SizedBox(height: 4),
                    Text(r['title'] as String? ?? 'Untitled',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11.5)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final sources = <String>{
      for (final r in _rows) kSourceNames[_sourceOf(r)] ?? 'Video'
    };
    final shown = _shown;
    final children = <Widget>[];
    // Chips (and search) on top.
    children.add(SizedBox(
      height: 44,
      child: _searching
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _chipBg,
                  hintText: widget.history ? 'Search history' : 'Search liked',
                  hintStyle: const TextStyle(color: _dim),
                  prefixIcon: IconButton(
                    tooltip: 'Close search',
                    onPressed: () => setState(() {
                      _searching = false;
                      _query.clear();
                    }),
                    icon: const InIcon(InIcons.back,
                        size: 16, color: Colors.white70),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none),
                ),
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _searching = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                          color: _chipBg,
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const InIcon(InIcons.search,
                          size: 15, color: Colors.white),
                    ),
                  ),
                ),
                _chip('All', _source == 'all',
                    () => setState(() => _source = 'all')),
                for (final s in sources)
                  _chip(s, _source == s, () => setState(() => _source = s)),
                if (widget.history && widget.onClear != null)
                  _chip('Clear history', false, () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Clear your watch history?'),
                        content: const Text("This can't be undone."),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(d).pop(false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.of(d).pop(true),
                              child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (ok == true && mounted) {
                      setState(() => _rows = []);
                      await widget.onClear!();
                    }
                  }),
              ],
            ),
    ));
    if (!widget.history) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        child: Row(children: [
          Text('${shown.length} song${shown.length == 1 ? '' : 's'}',
              style: const TextStyle(color: _dim, fontSize: 12)),
          const Spacer(),
          if (widget.onAddAll != null && shown.isNotEmpty) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact),
              onPressed: () => widget.onAddAll!(shown),
              icon: const InIcon(InIcons.play,
                  size: 15, color: Colors.black, filled: true),
              label: const Text('Play all'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _chipBg,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact),
              onPressed: () => widget.onAddAll!([...shown]..shuffle()),
              icon: const InIcon(InIcons.shuffle,
                  size: 15, color: Colors.white),
              label: const Text('Shuffle'),
            ),
          ],
        ]),
      ));
    }
    if (shown.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
            child: Text('Nothing here yet.', style: TextStyle(color: _dim))),
      ));
    } else if (widget.history) {
      if (_query.text.isEmpty) children.add(_mostWatched(shown));
      String? last;
      for (final r in shown) {
        final sec = _section(
            DateTime.tryParse('${r['watchedAt'] ?? r['createdAt'] ?? ''}')
                ?.toLocal());
        if (sec != last) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Text(sec,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ));
          last = sec;
        }
        children.add(_row(r));
      }
    } else {
      children.addAll(shown.map(_row));
    }
    return ColoredBox(
      color: _bg,
      child: ListView(
          padding: const EdgeInsets.only(bottom: 24), children: children),
    );
  }
}

/// A stacked playlist cover: the first song's thumbnail with two thin
/// layers behind it and the song count in the corner.
class YtPlaylistCover extends StatelessWidget {
  final Playlist playlist;
  final double width;
  const YtPlaylistCover({super.key, required this.playlist, this.width = 128});

  @override
  Widget build(BuildContext context) {
    final thumb = playlist.songs
        .map((s) => s.thumbnail)
        .firstWhere((t) => t != null && t.isNotEmpty, orElse: () => null);
    Widget layer(double inset, double alpha) => Positioned(
          left: inset,
          right: inset,
          top: -inset / 2,
          height: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: alpha),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: width,
        height: width * 9 / 16,
        child: Stack(clipBehavior: Clip.none, children: [
          layer(12, 0.18),
          layer(6, 0.3),
          Positioned.fill(
            child: YtThumb(
                src: thumb, width: width, corner: '≡ ${playlist.songs.length}'),
          ),
        ]),
      ),
    );
  }
}

/// Playlists list (YouTube style). Tap one to open [YtPlaylistScreen].
class YtPlaylistList extends StatelessWidget {
  final List<Playlist> playlists;
  final void Function(Playlist p) onOpen;
  final VoidCallback? onNew;
  final String Function(Playlist p) subtitle;
  const YtPlaylistList(
      {super.key,
      required this.playlists,
      required this.onOpen,
      required this.subtitle,
      this.onNew});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final p in playlists)
        InkWell(
          onTap: () => onOpen(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(children: [
              YtPlaylistCover(playlist: p),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(subtitle(p),
                          style: const TextStyle(color: _dim, fontSize: 11.5)),
                    ]),
              ),
            ]),
          ),
        ),
      if (onNew != null)
        InkWell(
          onTap: onNew,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Container(
                width: 128,
                height: 72,
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF555555)),
                    borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const InIcon(InIcons.plus, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('New playlist',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
    ]);
  }
}

/// One playlist, YouTube style: big cover, Play all / Shuffle, numbered
/// songs. Owner extras come in through [onRemoveSong], [onAddSongs] and
/// [visibilityChip].
class YtPlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  final void Function(Song s)? onAdd;
  final void Function(List<Song> songs)? onAddAll;
  final Future<void> Function(Song s)? onRemoveSong;
  final VoidCallback? onAddSongs;
  final Widget? visibilityChip;
  const YtPlaylistScreen(
      {super.key,
      required this.playlist,
      this.onAdd,
      this.onAddAll,
      this.onRemoveSong,
      this.onAddSongs,
      this.visibilityChip});

  @override
  State<YtPlaylistScreen> createState() => _YtPlaylistScreenState();
}

class _YtPlaylistScreenState extends State<YtPlaylistScreen> {
  late final List<Song> _songs = [...widget.playlist.songs];

  @override
  Widget build(BuildContext context) {
    final thumb = _songs
        .map((s) => s.thumbnail)
        .firstWhere((t) => t != null && t.isNotEmpty, orElse: () => null);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
          backgroundColor: const Color(0xFF26215C),
          foregroundColor: Colors.white,
          elevation: 0),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF26215C), _bg]),
          ),
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(
                builder: (context, box) =>
                    YtThumb(src: thumb, width: box.maxWidth)),
            const SizedBox(height: 12),
            Text(widget.playlist.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('${_songs.length} song${_songs.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _dim, fontSize: 12)),
            if (widget.visibilityChip != null) ...[
              const SizedBox(height: 8),
              widget.visibilityChip!,
            ],
            if (widget.onAddAll != null && _songs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black),
                    onPressed: () {
                      widget.onAddAll!(_songs);
                      Navigator.of(context).maybePop();
                    },
                    icon: const InIcon(InIcons.play,
                        size: 16, color: Colors.black, filled: true),
                    label: const Text('Play all'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _chipBg,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      widget.onAddAll!([..._songs]..shuffle());
                      Navigator.of(context).maybePop();
                    },
                    icon: const InIcon(InIcons.shuffle,
                        size: 16, color: Colors.white),
                    label: const Text('Shuffle'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
        if (widget.onAddSongs != null)
          ListTile(
            leading: const InIcon(InIcons.plus, color: Colors.white),
            title: const Text('Add songs',
                style: TextStyle(color: Colors.white)),
            onTap: widget.onAddSongs,
          ),
        for (var i = 0; i < _songs.length; i++)
          InkWell(
            onTap: widget.onAdd == null ? null : () => widget.onAdd!(_songs[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                SizedBox(
                  width: 18,
                  child: Text('${i + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _dim, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                YtThumb(src: _songs[i].thumbnail, width: 92),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_songs[i].title ?? 'Untitled',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 2),
                        Row(children: [
                          _sourceBadge(_songs[i].sourceType),
                          Text(kSourceNames[_songs[i].sourceType] ?? 'Video',
                              style:
                                  const TextStyle(color: _dim, fontSize: 11.5)),
                        ]),
                      ]),
                ),
                if (widget.onRemoveSong != null)
                  IconButton(
                    tooltip: 'Remove from playlist',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final s = _songs[i];
                      setState(() => _songs.removeAt(i));
                      await widget.onRemoveSong!(s);
                    },
                    icon: const InIcon(InIcons.close,
                        size: 16, color: Colors.white54),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Removes [song] from History or Liked on the server.
Future<void> ytRemove(String endpoint, Map<String, dynamic> song) async {
  final path = endpoint.split('?').first;
  try {
    await ApiClient.delete(path, body: {'videoUrl': song['videoUrl']});
  } catch (_) {}
}
