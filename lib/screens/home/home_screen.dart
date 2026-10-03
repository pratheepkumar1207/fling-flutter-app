import 'room_discovery_header.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/smart_play_song.dart';
import '../../core/socket_service.dart';
import '../../models/room_models.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/avatar.dart';
import '../../widgets/post_composer_sheet.dart';
import '../../widgets/story_bar.dart';
import '../../widgets/story_viewer_screen.dart';
import '../experience/experience_hub.dart';
import '../party/party_screen.dart';
import '../lobby/lobby_create_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _roomsLoadFailed = false;
  List<Map<String, dynamic>> _rooms = [];
  List<RoomSummary> _invited = [];
  List<Map<String, dynamic>> _scheduledEvents = [];
  List<StoryEntry> _stories = [];
  List<Map<String, dynamic>> _likedPlaylists = [];
  String? _typeFilter;
  Timer? _refreshTimer;
  Timer? _activityDebounce;
  // "Join by ID/link" used to live on its own Rooms tab (now removed —
  // see app_shell.dart) — kept as a feature, just moved onto Home directly
  // instead of behind a tab nobody needed a whole screen for.
  final _roomIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadStories();
    _loadLikedPlaylists();
    // This poll is now mostly a fallback (missed socket event, screen was
    // opened before anything changed) — rooms:activity below is what
    // actually makes a room appearing/disappearing feel instant. Set to
    // 1s per explicit request; worth knowing this means /rooms/browse gets
    // hit every second while Home is open, on every connected device,
    // regardless of whether anything actually changed.
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _load(silent: true));
    context
        .read<SocketService>()
        .socket
        ?.on('rooms:activity', _onRoomsActivity);
  }

  // Debounced — a burst of joins/leaves (e.g. a room emptying out member by
  // member) would otherwise fire several near-simultaneous refetches.
  void _onRoomsActivity(dynamic _) {
    _activityDebounce?.cancel();
    _activityDebounce =
        Timer(const Duration(milliseconds: 400), () => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _activityDebounce?.cancel();
    context
        .read<SocketService>()
        .socket
        ?.off('rooms:activity', _onRoomsActivity);
    _roomIdController.dispose();
    super.dispose();
  }

  void _joinByCode() {
    final id = _roomIdController.text.trim();
    if (id.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: id)));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/rooms/browse').catchError((_) => null),
      ApiClient.get('/rooms/invited').catchError((_) => []),
      ApiClient.get('/rooms/events').catchError((_) => []),
    ]);
    if (!mounted) return;
    setState(() {
      _roomsLoadFailed = results[0] == null;
      if (!_roomsLoadFailed) {
        _rooms = ((results[0] as List?) ?? []).cast<Map<String, dynamic>>();
      }
      _invited = ((results[1] as List?) ?? [])
          .map((e) => RoomSummary.fromJson(e as Map<String, dynamic>))
          .where((r) => r.memberCount == 0)
          .toList();
      _scheduledEvents =
          ((results[2] as List?) ?? []).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _loadStories() async {
    try {
      final data = await ApiClient.get('/feed/stories');
      if (!mounted) return;
      setState(() => _stories = (data as List)
          .map((e) => StoryEntry.fromJson(e as Map<String, dynamic>))
          .toList());
    } catch (_) {
      // Stories are a non-critical preview strip — silently skip on failure.
    }
  }

  Future<void> _loadLikedPlaylists() async {
    try {
      final data = await ApiClient.get('/playlists/liked');
      if (!mounted) return;
      setState(
          () => _likedPlaylists = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // Non-critical rail — silently skip on failure.
    }
  }

  void _openStoryViewer(StoryEntry entry) {
    final index = _stories.indexWhere((s) => s.userId == entry.userId);
    if (index == -1) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            StoryViewerScreen(groups: _stories, startGroupIndex: index)));
  }

  void _createRoom() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LobbyCreateScreen()));

  Future<void> _showJoinSheet() async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) => Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
              child: SafeArea(
                  top: false,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your invitation starts here',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text('Enter the room code your friend shared.',
                            style: TextStyle(color: AppColors.textDim)),
                        const SizedBox(height: 20),
                        TextField(
                            controller: _roomIdController,
                            autofocus: true,
                            textInputAction: TextInputAction.go,
                            decoration:
                                const InputDecoration(labelText: 'Room code'),
                            onSubmitted: (_) {
                              if (_roomIdController.text.trim().isEmpty) {
                                return;
                              }
                              Navigator.pop(sheetContext);
                              _joinByCode();
                            }),
                        const SizedBox(height: 16),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                onPressed: () {
                                  if (_roomIdController.text.trim().isEmpty) {
                                    return;
                                  }
                                  Navigator.pop(sheetContext);
                                  _joinByCode();
                                },
                                child: const Text('Enter room'))),
                      ])),
            ));
  }

  void _openRoom(String id) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: id)));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = (user?.name ?? 'friend').split(' ').first;
    final active = _rooms
        .where((r) =>
            asNum(r['memberCount']) > 0 &&
            (_typeFilter == null || r['roomType'] == _typeFilter))
        .toList()
      ..sort((a, b) => (b['isBoosted'] == true ? 1 : 0)
          .compareTo(a['isBoosted'] == true ? 1 : 0));
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), _loadStories(), _loadLikedPlaylists()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const SizedBox(height: 28),
          _heading('Your circle'),
          const SizedBox(height: 14),
          SizedBox(
              height: 92,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _stories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final story = index == 0 ? null : _stories[index - 1];
                    return SizedBox(
                        width: 64,
                        child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => story == null
                                ? showPostComposerSheet(context,
                                    onPosted: _loadStories,
                                    initialIsStory: true)
                                : _openStoryViewer(story),
                            child: Column(children: [
                              Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: story == null
                                              ? AppColors.border
                                              : AppColors.primary)),
                                  child: story == null
                                      ? const SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Icon(Icons.add_rounded,
                                              color: AppColors.text))
                                      : Avatar(
                                          src: story.avatarUrl,
                                          name: story.name,
                                          size: AvatarSize.md)),
                              const SizedBox(height: 8),
                              Text(story?.name ?? 'Your story',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.textDim)),
                            ])));
                  })),
          RoomDiscoveryHeader(
              firstName: firstName,
              onCreate: _createRoom,
              onJoin: _showJoinSheet,
              onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()))),
          const SizedBox(height: 28),
          _heading('Find your room', trailing: '${active.length} live'),
          const SizedBox(height: 14),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final filter in const <(String?, String, IconData)>[
                  (null, 'For you', Icons.grid_view_rounded),
                  ('watch', 'Watch', Icons.play_circle_outline),
                  ('voice', 'Talk', Icons.graphic_eq_rounded),
                  ('game', 'Play', Icons.sports_esports_outlined),
                  ('live', 'Live', Icons.sensors_rounded),
                ])
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          showCheckmark: false,
                          avatar: Icon(filter.$3,
                              size: 18,
                              color: _typeFilter == filter.$1
                                  ? AppColors.ink
                                  : AppColors.textDim),
                          label: Text(filter.$2),
                          selected: _typeFilter == filter.$1,
                          selectedColor: AppColors.paper,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                              color: _typeFilter == filter.$1
                                  ? AppColors.ink
                                  : AppColors.textDim),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          onSelected: (_) =>
                              setState(() => _typeFilter = filter.$1))),
              ])),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()))
          else if (_roomsLoadFailed && active.isEmpty)
            _actionRow(Icons.cloud_off_outlined, 'Could not load rooms',
                'Tap to try again', () => _load())
          else if (active.isEmpty)
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(18)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chair_alt_outlined,
                          color: AppColors.textDim, size: 28),
                      const SizedBox(height: 16),
                      Text('The next great room could be yours.',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                          'It’s quiet here. Pick something to watch and invite someone along.',
                          style:
                              TextStyle(color: AppColors.textDim, height: 1.5)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                          onPressed: _createRoom,
                          label: const Text('Start something'),
                          icon: const Icon(Icons.arrow_forward_rounded,
                              size: 18)),
                    ]))
          else
            ...active.map((r) => DiscoveryRoomCard(
                title: (r['roomType'] == 'watch'
                        ? r['nowPlayingTitle']
                        : r['title']) as String? ??
                    r['title'] as String? ??
                    'Untitled room',
                subtitle: r['hostName'] as String? ?? 'Come hang out',
                kind: r['roomType'] as String? ?? 'watch',
                count: asNum(r['memberCount']).toInt(),
                gameType: r['gameType'] as String?,
                participants: ((r['members'] as List?) ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .toList(),
                positionSeconds: (r['playbackPosition'] as num?)?.toDouble(),
                isPlaying: r['isPlaying'] == true,
                image: (r['nowPlayingThumbnail'] as String?)?.isNotEmpty == true
                    ? AppImage(
                        source: r['nowPlayingThumbnail'] as String,
                        fit: BoxFit.cover)
                    : null,
                onTap: () => _openRoom(r['id'] as String))),
          if (_invited.isNotEmpty) ...[
            const SizedBox(height: 24),
            _heading('You’re invited'),
            const SizedBox(height: 12),
            ..._invited.map((r) => _actionRow(
                Icons.mail_outline_rounded,
                r.title,
                r.hostName ?? 'A room is waiting for you',
                () => _openRoom(r.id))),
          ],
          if (_likedPlaylists.isNotEmpty) ...[
            const SizedBox(height: 24),
            _heading('On repeat'),
            const SizedBox(height: 12),
            ..._likedPlaylists.map((p) {
              final songs = ((p['songs'] as List?) ?? [])
                  .map((s) => Song.fromJson(s as Map<String, dynamic>))
                  .toList();
              return _actionRow(
                  Icons.queue_music_rounded,
                  p['name'] as String? ?? 'Saved playlist',
                  '${songs.length} tracks · Your saved collection',
                  () => playPlaylistSmart(context, songs));
            }),
          ],
          if (_scheduledEvents.isNotEmpty) ...[
            const SizedBox(height: 24),
            _heading('Coming up'),
            const SizedBox(height: 12),
            ..._scheduledEvents.map((ev) => _actionRow(
                Icons.event_outlined,
                ev['title'] as String? ?? 'Upcoming room',
                ev['hostName'] as String? ?? 'Scheduled room',
                () => _openRoom(ev['id'] as String))),
          ],
          const SizedBox(height: 24),
          _actionRow(
              Icons.explore_outlined,
              'More ways to connect',
              'Matching, communities & your creator space',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FlingFeatureHubScreen()))),
          const SizedBox(height: 16),
          const BannerCarousel(placement: 'home'),
        ],
      ),
    );
  }

  Widget _heading(String title, {String? trailing}) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: -0.5))),
        if (trailing != null)
          Text(trailing,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textDim)),
      ]);

  Widget _actionRow(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Icon(icon, color: AppColors.primary),
                  title: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textDim)),
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onTap: onTap)));
}
