import '../../theme/insync_icons.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/youtube_util.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../lobby/source_picker_screen.dart';
import '../lobby/youtube_browse_screen.dart';

/// Full-screen (not a bottom sheet) — "Now playing" (current track,
/// play-icon thumbnail) and "Up next" section labels, drag-handle +
/// thumbnail + title/subtitle + remove per row. The inline source-picker
/// search (real, necessary — this app has no other add-a-song entry point)
/// sits right under the header instead of behind a separate AppBar search
/// icon. Section labels are rendered as part of each row (not separate list
/// entries) so the single ReorderableListView over the full item list — and
/// its existing fromIndex/toIndex wire-format to queue:reorder — stays
/// exactly as it was; splitting into two separately-reorderable lists would
/// have needed a local-to-real index translation with no way to verify it
/// against the live multiplayer sync without real testing. Swipe-left-to-
/// right still closes it, mirroring the swipe that opens it from the room.
class QueueSheetScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> queue;
  final bool isHost;
  final int participantCount;
  final void Function(Map<String, dynamic> item, {String position}) onAdd;
  final void Function(int index) onJump;
  final void Function(int index) onRemove;
  final void Function(int fromIndex, int toIndex) onReorder;
  final VoidCallback onOpenRoster;
  final Future<void> Function(String sourceType, String videoUrl,
      {String? videoTitle, String? videoThumbnail}) onSwitchSource;
  // Voice/Game rooms — queued items are tagged mediaMode:'audio' (see
  // _addToQueue), and the picker below only offers YouTube Music instead
  // of the full video-source grid (see SourcePickerBody.audioOnly).
  final bool audioOnly;
  final bool canPin;
  final bool canAddSongs;
  // Whole playlist at once, starting now — see SourcePickerBody.onPlayAll.
  final void Function(List<Map<String, dynamic>> items)? onAddMany;
  // userId → display name, for "added by Ravi".
  final String? Function(String userId)? nameFor;

  const QueueSheetScreen({
    super.key,
    required this.roomId,
    required this.queue,
    required this.isHost,
    required this.participantCount,
    required this.onAdd,
    required this.onJump,
    required this.onRemove,
    required this.onReorder,
    required this.onOpenRoster,
    required this.onSwitchSource,
    this.audioOnly = false,
    bool? canPin,
    this.canAddSongs = true,
    this.onAddMany,
    this.nameFor,
  }) : canPin = canPin ?? isHost;

  @override
  State<QueueSheetScreen> createState() => _QueueSheetScreenState();
}

class _QueueSheetScreenState extends State<QueueSheetScreen> {
  // The one choke point every picker entry point (YouTube, Drive, OTT/
  // YouTube Surf, Liked, History, Playlists) funnels through. Used to show
  // a blocking "where should this go?" dialog before adding anything —
  // replaced with adding straight away (bottom of the queue, or "starts
  // now" when it's empty) plus a snackbar with icon actions for the two
  // things that dialog used to ask about: move it to the top instead, or
  // undo the add entirely.
  void _openYoutubeMusic() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (route) => YoutubeBrowseScreen(
        visibility: 'public',
        music: true,
        onSelectOverride: (item) {
          Navigator.of(route).pop();
          _addToQueue(
            videoUrl: 'https://www.youtube.com/watch?v=${item['videoId']}',
            title: item['title'] as String? ?? '',
            thumbnail: item['thumbnail'] as String?,
            mediaMode: 'audio',
          );
        },
      ),
    ));
  }

  Future<void> _addToQueue(
      {required String videoUrl,
      required String title,
      String? thumbnail,
      required String mediaMode,
      String sourceType = 'youtube'}) async {
    final items = (widget.queue['items'] as List?) ?? [];
    // "Queue empty" means nothing queued *after* whatever's currently
    // playing — the currently-playing item itself doesn't count. Since
    // items always includes the current item at currentIndex, that's
    // exactly items.length <= 1 (0 = truly nothing, 1 = only the item
    // that's already playing).
    final queueWasEmpty = items.length <= 1;
    final item = {
      'sourceType': sourceType,
      'videoUrl': videoUrl,
      'title': title,
      'thumbnail': thumbnail,
      'mediaMode': widget.audioOnly ? 'audio' : mediaMode,
    };
    widget.onAdd(item, position: 'bottom');
    if (!mounted) return;
    _showQueuedSnackBar(item, queueWasEmpty: queueWasEmpty);
  }

  // Best-effort match against the live queue — videoUrl is unique enough
  // in practice (the rare case of the exact same song queued twice just
  // means these two actions could target either copy, which is a fine
  // trade-off for not blocking on a dialog anymore). Matches from the end
  // since we always add to the bottom.
  int? _findQueueIndex(Map<String, dynamic> item) {
    final items = (widget.queue['items'] as List?) ?? [];
    for (var i = items.length - 1; i >= 0; i--) {
      if ((items[i] as Map)['videoUrl'] == item['videoUrl']) return i;
    }
    return null;
  }

  void _showQueuedSnackBar(Map<String, dynamic> item,
      {required bool queueWasEmpty}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Expanded(
              child: Text(queueWasEmpty ? 'Playing now' : 'Added to queue',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            if (!queueWasEmpty)
              IconButton(
                tooltip: 'Move to top',
                icon: const InIcon(InIcons.arrowup,
                    color: Colors.white, size: 20),
                onPressed: () {
                  final index = _findQueueIndex(item);
                  if (index != null && index > 0) {
                    widget.onReorder(index, 0);
                  }
                },
              ),
            IconButton(
              tooltip: 'Remove',
              icon: const InIcon(InIcons.close, color: Colors.white, size: 20),
              onPressed: () {
                final index = _findQueueIndex(item);
                if (index != null) widget.onRemove(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _close() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // Which chip is open: the queue itself, or suggestions/sources to add from.
  bool _suggested = false;
  // "Audio only" chip: new adds come in as audio (always on in music rooms).
  late bool _audioOnly = widget.audioOnly;
  final _search = TextEditingController();
  bool _searching = false;
  String? _searchError;
  List<Map<String, dynamic>>? _results;
  // Results added from this sheet, so they show "Added".
  final _addedUrls = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) {
      setState(() => _results = null);
      return;
    }
    // A pasted link goes straight in.
    final id = extractYouTubeId(q);
    if (id != null) {
      await _add({
        'videoUrl': 'https://www.youtube.com/watch?v=$id',
        'title': await _titleFor(id) ?? 'YouTube video',
        'thumbnail': 'https://img.youtube.com/vi/$id/hqdefault.jpg',
      });
      _search.clear();
      if (mounted) setState(() => _results = null);
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final data = await ApiClient.get(
              '/youtube/search?q=${Uri.encodeQueryComponent(q)}${widget.audioOnly ? '&music=1' : ''}')
          as List;
      if (!mounted) return;
      setState(() => _results = [
            for (final r in data)
              {
                'videoUrl':
                    'https://www.youtube.com/watch?v=${(r as Map)['videoId']}',
                'title': r['title'],
                'channel': r['channelTitle'],
                'thumbnail': r['thumbnail'],
              }
          ]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _searchError = 'Search didn’t work — try again');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<String?> _titleFor(String videoId) async {
    try {
      final d = await ApiClient.get('/youtube/embed-size?v=$videoId');
      return d is Map ? d['title'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _add(Map<String, dynamic> r, {bool playNow = false}) async {
    final items = (widget.queue['items'] as List?) ?? [];
    final current = widget.queue['currentIndex'] as int? ?? 0;
    final item = {
      'sourceType': 'youtube',
      'videoUrl': r['videoUrl'],
      'title': r['title'] ?? 'YouTube video',
      'thumbnail': r['thumbnail'],
      'mediaMode': _audioOnly ? 'audio' : 'video',
    };
    if (playNow) {
      widget.onAdd(item, position: 'top');
      if (items.isNotEmpty) widget.onJump(current + 1);
    } else {
      widget.onAdd(item, position: 'bottom');
      _showQueuedSnackBar(item, queueWasEmpty: items.isEmpty);
    }
    setState(() => _addedUrls.add(r['videoUrl'] as String));
  }

  static String _sourceLabel(String? t) => switch (t) {
        'youtube' || 'youtube_surf' || null => 'YouTube',
        'drive' => 'Drive',
        'netflix' => 'Netflix',
        'amazon' => 'Prime Video',
        'hotstar' => 'Hotstar',
        'sonyliv' => 'SonyLIV',
        'zee5' => 'ZEE5',
        'sunnxt' => 'Sun NXT',
        'aha' => 'aha',
        _ => t[0].toUpperCase() + t.substring(1),
      };

  String _who(Map<String, dynamic> item) {
    final id = item['addedBy'] as String?;
    final name = id == null ? null : widget.nameFor?.call(id);
    return [
      _sourceLabel(item['sourceType'] as String?),
      if (item['mediaMode'] == 'audio') 'audio only',
      if (name != null) 'added by ${name.split(' ').first}',
    ].join(' · ');
  }

  Widget _chip(String label, bool on, VoidCallback onTap, {InIconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? AppColors.primary : AppColors.surface,
          shape: StadiumBorder(
              side:
                  BorderSide(color: on ? AppColors.primary : AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  InIcon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6)),
      );

  Widget _thumb(String? src, double w, double h) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: w,
          height: h,
          color: AppColors.surface3,
          child: src != null
              ? AppImage(source: src, fit: BoxFit.cover)
              : const Center(
                  child:
                      InIcon(InIcons.tv, size: 18, color: AppColors.textFaint)),
        ),
      );

  Widget _iconBtn(InIconData icon, String label, VoidCallback onTap) =>
      IconButton(
        tooltip: label,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        icon: InIcon(icon, size: 17, color: AppColors.textDim),
      );

  Widget _queueList(List items, int current) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const InIcon(InIcons.queue, size: 30, color: AppColors.textFaint),
          const SizedBox(height: 10),
          const Text('Nothing queued yet',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              widget.canAddSongs
                  ? 'Search above or open Suggested to add something'
                  : 'The host picks what plays here',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
        ]),
      );
    }
    final now = current < items.length
        ? Map<String, dynamic>.from(items[current] as Map)
        : null;
    final upNext = [
      for (var i = current + 1; i < items.length; i++) i,
    ];
    final played = [for (var i = 0; i < current && i < items.length; i++) i];
    Widget row(int i, {bool dim = false}) {
      final item = Map<String, dynamic>.from(items[i] as Map);
      final host = widget.isHost;
      return Opacity(
        key: ValueKey('q-$i-${item['videoUrl']}'),
        opacity: dim ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            if (host && !dim)
              const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: InIcon(InIcons.menu,
                      size: 18, color: AppColors.textFaint)),
            _thumb(item['thumbnail'] as String?, 80, 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'] as String? ?? 'Video',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_who(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 11)),
                  ]),
            ),
            if (dim && widget.canPin)
              _iconBtn(InIcons.repeat, 'Play again', () => widget.onJump(i)),
            if (!dim && widget.canPin)
              _iconBtn(InIcons.play, 'Play now', () => widget.onJump(i)),
            if (!dim && host && i > current + 1)
              _iconBtn(InIcons.arrowup, 'Move to top',
                  () => widget.onReorder(i, current + 1)),
            if (!dim && host)
              _iconBtn(InIcons.close, 'Remove', () => widget.onRemove(i)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        if (now != null) ...[
          _section('NOW PLAYING'),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1028),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A2A55)),
            ),
            child: Row(children: [
              _thumb(now['thumbnail'] as String?, 92, 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(now['title'] as String? ?? 'Video',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(_who(now),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ]),
              ),
              const InIcon(InIcons.chart, size: 20, color: AppColors.lilac),
            ]),
          ),
        ],
        if (upNext.isNotEmpty) ...[
          _section('UP NEXT · ${upNext.length}'),
          if (widget.isHost)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorderItem: (from, to) => widget.onReorder(
                  upNext[from], upNext[to.clamp(0, upNext.length - 1)]),
              children: [for (final i in upNext) row(i)],
            )
          else
            for (final i in upNext) row(i),
        ],
        if (played.isNotEmpty) ...[
          _section('PLAYED'),
          for (final i in played.reversed) row(i, dim: true),
        ],
      ],
    );
  }

  Widget _resultsList() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_searchError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim))));
    }
    final r = _results ?? const [];
    if (r.isEmpty) {
      return const Center(
          child:
              Text('No results', style: TextStyle(color: AppColors.textDim)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        _section('RESULTS'),
        for (final v in r)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              _thumb(v['thumbnail'] as String?, 80, 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v['title'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(v['channel'] as String? ?? 'YouTube',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 11)),
                    ]),
              ),
              const SizedBox(width: 6),
              if (_addedUrls.contains(v['videoUrl']))
                const Text('✓ Added',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12))
              else ...[
                if (widget.canPin)
                  TextButton(
                      onPressed: () => _add(v, playNow: true),
                      child: const Text('Play now')),
                FilledButton.tonal(
                    onPressed: () => _add(v),
                    style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    child: const Text('Add')),
              ],
            ]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.queue['items'] as List?) ?? [];
    final current = widget.queue['currentIndex'] as int? ?? 0;
    final showResults = _results != null || _searching || _searchError != null;
    return Material(
      color: const Color(0xFF121019),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF3A3548),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 6),
            child: Row(children: [
              const Expanded(
                child: Text('Up next',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: widget.onOpenRoster,
                icon: const InIcon(InIcons.users,
                    size: 16, color: AppColors.textDim),
                label: Text('${widget.participantCount}',
                    style: const TextStyle(color: AppColors.textDim)),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _close,
                icon: const InIcon(InIcons.close, color: AppColors.textDim),
              ),
            ]),
          ),
          if (widget.canAddSongs)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: TextField(
                controller: _search,
                // Voice, game and music rooms: straight to YouTube Music.
                readOnly: widget.audioOnly,
                onTap: widget.audioOnly ? _openYoutubeMusic : null,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                onChanged: (v) {
                  if (v.isEmpty) setState(() => _results = null);
                },
                decoration: InputDecoration(
                  hintText: widget.audioOnly
                      ? 'Search songs on YouTube Music'
                      : 'Search YouTube or paste a link',
                  prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: InIcon(InIcons.search,
                          size: 18, color: AppColors.textFaint)),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () => setState(() {
                                _search.clear();
                                _results = null;
                                _searchError = null;
                              }),
                          icon: const InIcon(InIcons.close,
                              size: 16, color: AppColors.textFaint)),
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Row(children: [
              _chip(
                  'Queue · ${items.length}',
                  !_suggested && !showResults,
                  () => setState(() {
                        _suggested = false;
                        _results = null;
                        _searchError = null;
                      })),
              if (widget.canAddSongs)
                _chip(
                    'Suggested',
                    _suggested && !showResults,
                    () => setState(() {
                          _suggested = true;
                          _results = null;
                          _searchError = null;
                        })),
              if (widget.canAddSongs && !widget.audioOnly)
                _chip(
                    'Audio only',
                    _audioOnly,
                    widget.audioOnly
                        ? () {}
                        : () => setState(() => _audioOnly = !_audioOnly),
                    icon: InIcons.music),
            ]),
          ),
          Expanded(
            child: showResults
                ? _resultsList()
                : _suggested && widget.canAddSongs
                    ? SingleChildScrollView(
                        child: SourcePickerBody(
                          compact: true,
                          roomId: widget.roomId,
                          onAddToQueue: _addToQueue,
                          onSwitchSource: widget.onSwitchSource,
                          audioOnly: widget.audioOnly,
                          onPlayAll: widget.onAddMany,
                        ),
                      )
                    : _queueList(items, current),
          ),
        ]),
      ),
    );
  }
}

/// Opens the room's search and queue as a sheet over the room (the room
/// stays visible, dimmed, above it).
Future<void> showQueueSheet(BuildContext context, {required Widget sheet}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: sheet),
  );
}
