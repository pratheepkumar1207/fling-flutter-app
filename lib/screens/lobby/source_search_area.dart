import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/youtube_util.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';

typedef SourcePick = void Function(
    {required String sourceType,
    required String videoUrl,
    required String title,
    String? thumbnail});

/// Top of "What are we watching?": one bar to search YouTube or paste a
/// link, a Continue row from your history, and — while searching — the
/// results (or a preview of the pasted link) in place of the source grid.
class SourceSearchArea extends StatefulWidget {
  /// Adding to a room (buttons say Add) or starting one (Watch).
  final bool inRoom;
  final SourcePick onPick;
  final Widget sources;
  const SourceSearchArea(
      {super.key,
      required this.inRoom,
      required this.onPick,
      required this.sources});

  @override
  State<SourceSearchArea> createState() => _SourceSearchAreaState();
}

class _SourceSearchAreaState extends State<SourceSearchArea> {
  final _c = TextEditingController();
  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>>? _results;
  Map<String, dynamic>? _link; // {sourceType, videoUrl, title, thumbnail}
  List<Song> _continue = const [];
  final _added = <String>{};

  @override
  void initState() {
    super.initState();
    ApiClient.get('/song-history').then((d) {
      if (!mounted) return;
      setState(() => _continue = [
            for (final e in (d as List).take(10))
              Song.fromJson(Map<String, dynamic>.from(e as Map))
          ].where((s) => (s.videoUrl ?? '').isNotEmpty).toList());
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static String? _driveId(String url) =>
      RegExp(r'drive\.google\.com/(?:file/d/|open\?id=)([\w-]{10,})')
          .firstMatch(url)
          ?.group(1);

  void _clear() => setState(() {
        _c.clear();
        _results = null;
        _link = null;
        _error = null;
      });

  Future<void> _submit() async {
    final text = _c.text.trim();
    if (text.isEmpty) return _clear();
    final yt = extractYouTubeId(text);
    if (yt != null) {
      setState(() {
        _results = null;
        _error = null;
        _link = {
          'sourceType': 'youtube',
          'videoUrl': 'https://www.youtube.com/watch?v=$yt',
          'title': 'YouTube video',
          'thumbnail': 'https://img.youtube.com/vi/$yt/hqdefault.jpg',
        };
      });
      try {
        final d = await ApiClient.get('/youtube/embed-size?v=$yt');
        final t = d is Map ? d['title'] as String? : null;
        if (t != null && mounted && _link != null) {
          setState(() => _link = {..._link!, 'title': t});
        }
      } catch (_) {}
      return;
    }
    final drive = _driveId(text);
    if (drive != null) {
      setState(() {
        _results = null;
        _error = null;
        _link = {
          'sourceType': 'drive',
          'videoUrl': drive,
          'title': 'Drive video'
        };
      });
      return;
    }
    if (text.startsWith('http')) {
      setState(() {
        _link = null;
        _results = null;
        _error = 'This link can’t play here — try a YouTube or Drive link';
      });
      return;
    }
    setState(() {
      _searching = true;
      _link = null;
      _error = null;
    });
    try {
      final d = await ApiClient.get(
          '/youtube/search?q=${Uri.encodeQueryComponent(text)}') as List;
      if (!mounted) return;
      setState(() => _results = [
            for (final r in d)
              {
                'sourceType': 'youtube',
                'videoUrl':
                    'https://www.youtube.com/watch?v=${(r as Map)['videoId']}',
                'title': r['title'] ?? 'YouTube video',
                'channel': r['channelTitle'],
                'thumbnail': r['thumbnail'],
              }
          ]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Search didn’t work — try again');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(Map<String, dynamic> v) {
    widget.onPick(
        sourceType: v['sourceType'] as String? ?? 'youtube',
        videoUrl: v['videoUrl'] as String,
        title: v['title'] as String? ?? 'Video',
        thumbnail: v['thumbnail'] as String?);
    if (widget.inRoom) setState(() => _added.add(v['videoUrl'] as String));
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600)),
      );

  Widget _continueRow() => SizedBox(
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _continue.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final s = _continue[i];
            return Semantics(
              button: true,
              label: 'Continue ${s.title ?? 'video'}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => _pick({
                  'sourceType': s.sourceType,
                  'videoUrl': s.videoUrl,
                  'title': s.title,
                  'thumbnail': s.thumbnail,
                }),
                child: Container(
                  width: 132,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 72,
                          width: double.infinity,
                          child: s.thumbnail != null
                              ? AppImage(source: s.thumbnail, fit: BoxFit.cover)
                              : const ColoredBox(
                                  color: AppColors.surface3,
                                  child: Center(
                                      child: InIcon(InIcons.play,
                                          color: AppColors.textFaint))),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(7, 5, 7, 0),
                          child: Text(s.title ?? 'Video',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: Text(_sourceName(s.sourceType),
                              style: const TextStyle(
                                  color: AppColors.textDim, fontSize: 11)),
                        ),
                      ]),
                ),
              ),
            );
          },
        ),
      );

  static String _sourceName(String? t) => switch (t) {
        'drive' => 'Drive',
        'netflix' => 'Netflix',
        'amazon' => 'Prime Video',
        'hotstar' => 'Hotstar',
        _ => 'YouTube',
      };

  Widget _preview(Map<String, dynamic> v) => Container(
        margin: const EdgeInsets.only(top: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3A2A55)),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: v['thumbnail'] != null
                ? AppImage(source: v['thumbnail'] as String, fit: BoxFit.cover)
                : const ColoredBox(
                    color: AppColors.surface3,
                    child: Center(
                        child: InIcon(InIcons.play,
                            size: 28, color: AppColors.textFaint))),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(v['title'] as String? ?? 'Video',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_sourceName(v['sourceType'] as String?),
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 12)),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed:
                        _added.contains(v['videoUrl']) ? null : () => _pick(v),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46)),
                    child: Text(widget.inRoom
                        ? (_added.contains(v['videoUrl'])
                            ? '✓ Added to queue'
                            : 'Add to queue')
                        : 'Start watching'),
                  ),
                ]),
          ),
        ]),
      );

  Widget _resultsList(List<Map<String, dynamic>> r) {
    if (r.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: Text('No results',
                  style: TextStyle(color: AppColors.textDim))));
    }
    return Column(children: [
      for (final v in r)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 84,
                height: 48,
                child: v['thumbnail'] != null
                    ? AppImage(
                        source: v['thumbnail'] as String, fit: BoxFit.cover)
                    : const ColoredBox(color: AppColors.surface3),
              ),
            ),
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
            const SizedBox(width: 8),
            if (_added.contains(v['videoUrl']))
              const Text('✓ Added',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12))
            else
              FilledButton(
                onPressed: () => _pick(v),
                style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: widget.inRoom
                        ? const Color(0xFF2B1640)
                        : AppColors.primary),
                child: Text(widget.inRoom ? 'Add' : 'Watch'),
              ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final busy =
        _searching || _results != null || _link != null || _error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _c,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        onChanged: (v) {
          if (v.isEmpty) _clear();
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Search YouTube or paste a link',
          prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child:
                  InIcon(InIcons.search, size: 18, color: AppColors.textDim)),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: _c.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: _clear,
                  icon: const InIcon(InIcons.close,
                      size: 16, color: AppColors.textDim)),
        ),
      ),
      if (_searching)
        const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()))
      else if (_error != null)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim)),
        )
      else if (_link != null)
        _preview(_link!)
      else if (_results != null) ...[
        _label('RESULTS'),
        _resultsList(_results!),
      ],
      if (!busy) ...[
        if (_continue.isNotEmpty) ...[
          _label(widget.inRoom ? 'FROM YOUR HISTORY' : 'CONTINUE WATCHING'),
          _continueRow(),
        ],
        const SizedBox(height: 18),
        widget.sources,
      ],
    ]);
  }
}
