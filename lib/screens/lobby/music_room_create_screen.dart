import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinning_vinyl.dart';
import '../../widgets/two_row_carousel.dart';
import '../party/party_screen.dart';

/// Start a music room: set it up, pick the first song (or a playlist) from
/// YouTube Music, then start. Music rooms are voice rooms for listening
/// together — songs only, played as audio, in sync for everyone.
class MusicRoomCreateScreen extends StatefulWidget {
  const MusicRoomCreateScreen({super.key});

  @override
  State<MusicRoomCreateScreen> createState() => _MusicRoomCreateScreenState();
}

class _MusicRoomCreateScreenState extends State<MusicRoomCreateScreen> {
  int _step = 0;
  final _name = TextEditingController();
  String _visibility = 'public';
  bool _anyoneAdds = true;
  bool _mics = true;
  // Step 2/3: what plays first.
  List<Song> _songs = const [];
  String? _pickTitle;
  bool _shuffle = false;
  bool _loop = false;
  bool _starting = false;

  // Search + lists.
  final _search = TextEditingController();
  bool _searching = false;
  String? _searchError;
  List<Song>? _results;
  List<Song> _liked = const [], _history = const [];
  List<Map<String, dynamic>> _playlists = const [];

  static const _quick = [
    'Trending Tamil songs',
    'Tamil hits',
    'Melody',
    'Kuthu'
  ];

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthProvider>().user?.name ?? 'My';
    _name.text = '${me.split(' ').first}’s Music Room';
    _loadLists();
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Song> _parse(dynamic d) => [
        for (final e in (d as List? ?? const []))
          Song.fromJson(Map<String, dynamic>.from(e as Map))
      ]
          .where((s) => (s.videoUrl ?? '').isNotEmpty || s.videoId != null)
          .toList();

  Future<void> _loadLists() async {
    final r = await Future.wait([
      ApiClient.get('/liked-songs?music=1').catchError((_) => const []),
      ApiClient.get('/song-history?music=1').catchError((_) => const []),
      ApiClient.get('/playlists?music=1').catchError((_) => const []),
    ]);
    if (!mounted) return;
    setState(() {
      _liked = _parse(r[0]);
      _history = _parse(r[1]);
      _playlists = [
        for (final p in (r[2] as List? ?? const []))
          Map<String, dynamic>.from(p as Map)
      ];
    });
  }

  Future<void> _runSearch([String? q]) async {
    final text = (q ?? _search.text).trim();
    if (q != null) _search.text = q;
    if (text.isEmpty) return setState(() => _results = null);
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final d = await ApiClient.get(
              '/youtube/search?q=${Uri.encodeQueryComponent(text)}&music=1')
          as List;
      if (!mounted) return;
      setState(() => _results = [
            for (final r in d)
              Song(
                videoUrl:
                    'https://www.youtube.com/watch?v=${(r as Map)['videoId']}',
                title: r['title'] as String?,
                thumbnail: r['thumbnail'] as String?,
                sourceType: 'youtube',
                mediaMode: 'audio',
              )
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

  void _choose(List<Song> songs, String title) => setState(() {
        _songs = songs;
        _pickTitle = title;
        _step = 2;
      });

  Map<String, dynamic> _item(Song s) => {
        'sourceType': 'youtube',
        'videoUrl': s.videoId != null
            ? 'https://www.youtube.com/watch?v=${s.videoId}'
            : s.videoUrl,
        'title': s.title,
        'thumbnail': s.thumbnail,
        'mediaMode': 'audio',
      };

  Future<void> _start() async {
    if (_starting || _songs.isEmpty) return;
    setState(() => _starting = true);
    try {
      final songs = [..._songs];
      if (_shuffle) songs.shuffle(Random());
      final room = await ApiClient.post('/rooms', body: {
        'roomType': 'music',
        'title': _name.text.trim(),
        'visibility': _visibility,
        if (!_mics) 'micEnabled': false,
        if (!_anyoneAdds) 'songPermission': 'host',
        if (_loop) 'loop': true,
        'queueItems': [for (final s in songs) _item(s)],
      }) as Map<String, dynamic>;
      final roomId = room['id'] as String;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _starting = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t start the room')));
        setState(() => _starting = false);
      }
    }
  }

  // ---------- UI ----------

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 11.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600)),
      );

  Widget _segment<T>(List<(T, String, InIconData?)> opts, T value,
          ValueChanged<T> onPick) =>
      Row(children: [
        for (final (v, label, icon) in opts)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: v == value ? const Color(0xFF2B1640) : AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color:
                            v == value ? AppColors.primary : AppColors.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onPick(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            InIcon(icon, size: 15, color: AppColors.text),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
          ),
      ]);

  Widget _setup() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1028),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A2A55)),
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: const Color(0xFF2A1A10),
                    borderRadius: BorderRadius.circular(14)),
                child: const Center(
                    child: InIcon(InIcons.music,
                        size: 22, color: Color(0xFFFF9F5A))),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Listen together',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          'Songs only · YouTube Music · everyone hears it in sync',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ]),
              ),
            ]),
          ),
          _label('ROOM NAME'),
          TextField(
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(counterText: '')),
          _label('WHO CAN JOIN'),
          _segment([
            ('public', 'Everyone', InIcons.globe),
            ('friends', 'Friends', InIcons.users),
            ('private', 'Private', InIcons.lock),
          ], _visibility, (v) => setState(() => _visibility = v)),
          _label('WHO ADDS SONGS'),
          _segment([(true, 'Anyone', null), (false, 'Only me', null)],
              _anyoneAdds, (v) => setState(() => _anyoneAdds = v)),
          const SizedBox(height: 14),
          SwitchListTile(
            value: _mics,
            onChanged: (v) => setState(() => _mics = v),
            activeThumbColor: AppColors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary:
                const InIcon(InIcons.mic, size: 20, color: AppColors.lilac),
            title: const Text('Mics on'),
            subtitle: const Text('Talk and sing along',
                style: TextStyle(color: AppColors.textDim, fontSize: 12)),
          ),
        ],
      );

  Widget _songsCarousel(List<Song> songs) => TwoRowCarousel(tiles: [
        for (final s in songs)
          CarouselTile(
              title: s.title ?? 'Song',
              thumbnail: s.thumbnail,
              onTap: () => _choose([s], s.title ?? 'Song')),
      ]);

  Widget _pick() {
    final results = _results;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _runSearch(),
          onChanged: (v) {
            if (v.isEmpty) setState(() => _results = null);
          },
          decoration: InputDecoration(
            hintText: 'Search songs on YouTube Music',
            prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child:
                    InIcon(InIcons.search, size: 18, color: AppColors.textDim)),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () => setState(() {
                          _search.clear();
                          _results = null;
                        }),
                    icon: const InIcon(InIcons.close,
                        size: 16, color: AppColors.textDim)),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final q in _quick)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(q),
                  onPressed: () => _runSearch(q),
                ),
              ),
          ]),
        ),
        if (_searching)
          const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()))
        else if (_searchError != null)
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_searchError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textDim)))
        else if (results != null) ...[
          _label('SONGS'),
          if (results.isEmpty)
            const Text('No songs found',
                style: TextStyle(color: AppColors.textDim)),
          for (final s in results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                    width: 64,
                    height: 40,
                    child: s.thumbnail != null
                        ? AppImage(source: s.thumbnail, fit: BoxFit.cover)
                        : const ColoredBox(color: AppColors.surface3)),
              ),
              title: Text(s.title ?? 'Song',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5)),
              trailing: const InIcon(InIcons.right,
                  size: 16, color: AppColors.textDim),
              onTap: () => _choose([s], s.title ?? 'Song'),
            ),
        ] else ...[
          if (_liked.isNotEmpty) ...[
            _label('YOUR LIKED SONGS'),
            _songsCarousel(_liked),
          ],
          if (_history.isNotEmpty) ...[
            _label('HISTORY'),
            _songsCarousel(_history),
          ],
          if (_playlists.isNotEmpty) ...[
            _label('YOUR PLAYLISTS'),
            TwoRowCarousel(tiles: [
              for (final p in _playlists)
                () {
                  final songs = _parse(p['songs']);
                  return CarouselTile(
                    title: p['name'] as String? ?? 'Playlist',
                    thumbnail: songs.isEmpty ? null : songs.first.thumbnail,
                    badge:
                        '${songs.length} song${songs.length == 1 ? '' : 's'}',
                    onTap: songs.isEmpty
                        ? null
                        : () =>
                            _choose(songs, p['name'] as String? ?? 'Playlist'),
                  );
                }(),
            ]),
          ],
          if (_liked.isEmpty && _history.isEmpty && _playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                  'Search for a song to start. Songs you play and like in music rooms show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDim)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Only songs from YouTube Music show here',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
            ),
        ],
      ],
    );
  }

  Widget _ready() {
    final first = _songs.first;
    final many = _songs.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A2A55)),
          ),
          child: Column(children: [
            SpinningVinyl(thumbnail: first.thumbnail, size: 130),
            const SizedBox(height: 12),
            Text(_pickTitle ?? first.title ?? 'Song',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
                many
                    ? 'Playlist · ${_songs.length} songs play in order'
                    : 'Song · then the room picks what plays next',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              if (many)
                FilterChip(
                  selected: _shuffle,
                  onSelected: (v) => setState(() => _shuffle = v),
                  avatar: const InIcon(InIcons.shuffle,
                      size: 15, color: AppColors.text),
                  label: const Text('Shuffle'),
                ),
              FilterChip(
                selected: _loop,
                onSelected: (v) => setState(() => _loop = v),
                avatar: const InIcon(InIcons.repeat,
                    size: 15, color: AppColors.text),
                label: const Text('Loop'),
              ),
            ]),
          ]),
        ),
        if (many) ...[
          _label('UP NEXT'),
          for (var i = 1; i < _songs.length && i <= 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                    width: 18,
                    child: Text('$i',
                        style: const TextStyle(color: AppColors.textDim))),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                      width: 52,
                      height: 32,
                      child: _songs[i].thumbnail != null
                          ? AppImage(
                              source: _songs[i].thumbnail, fit: BoxFit.cover)
                          : const ColoredBox(color: AppColors.surface3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_songs[i].title ?? 'Song',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          if (_songs.length > 4)
            Text('+ ${_songs.length - 4} more',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Music room', 'Pick a song', 'Ready'];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step -= 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(titles[_step]),
          actions: [
            if (_step == 1)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                    child: Text('YouTube Music',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 12))),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
                child: switch (_step) {
              0 => _setup(),
              1 => _pick(),
              _ => _ready(),
            }),
            if (_step != 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                child: Column(children: [
                  FilledButton(
                    onPressed: _step == 0
                        ? () => setState(() => _step = 1)
                        : (_starting ? null : _start),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: Text(_step == 0
                        ? 'Next · pick the first song'
                        : _starting
                            ? 'Starting…'
                            : 'Start music room'),
                  ),
                  if (_step == 2)
                    TextButton(
                        onPressed: () => setState(() => _step = 1),
                        child: const Text('Change song')),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
