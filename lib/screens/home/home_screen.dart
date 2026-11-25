import 'dart:async';
import '../tournaments/tournament_cards.dart';
import '../../widgets/game_computer.dart';
import '../../widgets/skeletons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/smart_play_song.dart';
import '../../core/socket_service.dart';
import '../../models/room_models.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../widgets/banner_carousel.dart';
import '../party/party_screen.dart';
import '../lobby/lobby_create_screen.dart';
import '../../theme/insync_icons.dart';
import 'home_room_cards.dart';
import 'home_lobby_card.dart';
import 'popcorn_cards.dart';
import '../../core/live_now.dart';
import '../feed/friends_in_rooms_strip.dart';
import '../live/live_feed_screen.dart';
import '../live/live_swipe_screen.dart';
import '../shell/create_room_screen.dart';
import 'popcorn_live_row.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/location_service.dart';
import 'package:geolocator/geolocator.dart';
import '../blend/blend_screen.dart';

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
  List<Map<String, dynamic>> _likedPlaylists = [];
  // The room you're still connected to (another device or a call), and
  // Reels Blends someone is watching right now.
  Map<String, dynamic>? _myRoom;
  List<Map<String, dynamic>> _liveBlends = [];
  Timer? _refreshTimer;
  Timer? _activityDebounce;
  // Never let refreshes stack up — on a slow device a new tick used to fire
  // while the previous request batch was still in flight.
  bool _loadInFlight = false;
  bool? _wasVisible;
  // "Join by ID/link" used to live on its own Rooms tab (now removed —
  // see app_shell.dart) — kept as a feature, just moved onto Home directly
  // instead of behind a tab nobody needed a whole screen for.
  final _roomIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadLikedPlaylists();
    // Fallback poll only (missed socket event) — rooms:activity below is what
    // makes a room appearing/disappearing feel instant. This used to run
    // every 1s, firing 3 requests per tick (~180/min per device, even on
    // other tabs), which exhausted the backend's 300-per-15-min rate limit
    // in under two minutes and made every other request in the app fail.
    // Now 15s (head counts on the cards come from this; the server only
    // pings for rooms opening and closing), and _load skips silent
    // refreshes while Home isn't visible.
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
    context
        .read<SocketService>()
        .socket
        ?.on('rooms:activity', _onRoomsActivity);
  }

  // A room opened or closed somewhere. The first one reloads at once; after
  // that at most one reload every 10 s, however many rooms change, so a
  // busy app can't keep every phone on Home reloading.
  DateTime _lastActivityLoad = DateTime.fromMillisecondsSinceEpoch(0);
  void _onRoomsActivity(dynamic _) {
    if (_activityDebounce?.isActive ?? false) return;
    final since = DateTime.now().difference(_lastActivityLoad);
    const gap = Duration(seconds: 10);
    final delay = since >= gap ? const Duration(milliseconds: 400) : gap - since;
    _activityDebounce = Timer(delay, () {
      _lastActivityLoad = DateTime.now();
      _load(silent: true);
    });
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

  // Home lives in the shell's IndexedStack, which disables TickerMode for
  // hidden tabs — so this is false while another tab is showing.
  bool get _isVisible =>
      TickerMode.valuesOf(context).enabled &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Coming back to the Home tab: refresh right away rather than waiting
    // up to 30s for the next poll tick.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _wasVisible == false) _load(silent: true);
    _wasVisible = visible;
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadInFlight) return;
    if (silent && !_isVisible) return;
    _loadInFlight = true;
    if (!silent) setState(() => _loading = true);
    final List<dynamic> results;
    try {
      results = await Future.wait([
        ApiClient.get('/rooms/browse').catchError((_) => null),
        ApiClient.get('/rooms/invited').catchError((_) => []),
        ApiClient.get('/rooms/events').catchError((_) => []),
      ]);
    } finally {
      _loadInFlight = false;
    }
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
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final r = await Future.wait([
        ApiClient.get('/rooms/mine/active').catchError((_) => null),
        ApiClient.get('/blends').catchError((_) => null),
      ]);
      if (!mounted) return;
      final mine = r[0] is Map ? Map<String, dynamic>.from(r[0] as Map) : null;
      setState(() {
        _myRoom = mine?['roomId'] == null ? null : mine;
        _liveBlends = [
          for (final b in (r[1] as List?) ?? const [])
            if (b is Map && ((b['watching'] as List?) ?? const []).isNotEmpty)
              Map<String, dynamic>.from(b)
        ];
      });
    } catch (_) {}
  }

  // Only used to put nearby rooms higher; no distance is ever shown.
  Future<void> _turnOnLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    try {
      await ApiClient.patch('/auth/me', body: {'locationSharingEnabled': true});
      await LocationService.requestPermissionAndPing();
      if (mounted) await context.read<AuthProvider>().refreshUser();
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<bool?> _toggleRemind(String id) async {
    try {
      final r = await ApiClient.post('/rooms/$id/remind');
      return (r as Map)['remindMe'] == true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return null;
    }
  }

  String _blendTitle(Map<String, dynamic> b) {
    final myId = context.read<AuthProvider>().user?.id;
    final others = [
      for (final m in (b['members'] as List? ?? const []))
        if (m is Map && m['id'] != myId)
          (m['name'] as String? ?? 'Someone').split(' ').first
    ];
    final name = b['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    if (others.isEmpty) return 'Your Blend';
    return 'You + ${others.take(2).join(', ')}${others.length > 2 ? ' +${others.length - 2}' : ''}';
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

  void _createRoom() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LobbyCreateScreen()));

  Future<void> _showJoinSheet() async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.black,
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

  // Popcorn tab: All · Watch · Talk · Game · Live, as a list of lobby cards.
  String _filter = 'all';

  bool _matches(Map<String, dynamic> r) {
    final t = r['roomType'] as String? ?? 'watch';
    return switch (_filter) {
      'watch' => t == 'watch',
      'talk' => t == 'voice',
      'game' => t == 'game',
      'live' => t == 'live',
      _ => true,
    };
  }

  Widget _segmented() {
    const opts = [
      ('all', 'All'),
      ('watch', 'Watch'),
      ('talk', 'Talk'),
      ('game', 'Game'),
      ('live', 'Live'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: const Color(0xFF121216),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F1F24))),
      child: Row(children: [
        for (final (id, label) in opts)
          Expanded(
            child: Semantics(
              button: true,
              selected: _filter == id,
              child: GestureDetector(
                onTap: () => setState(() => _filter = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                      color: _filter == id
                          ? const Color(0xFF26262C)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _filter == id
                              ? Colors.white
                              : const Color(0xFF8E8E93))),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _viewToggle(InIconData icon, String label, bool on, VoidCallback tap) =>
      Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          onTap: tap,
          child: Container(
            width: 30,
            height: 28,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
                color: on ? const Color(0xFF26262C) : const Color(0xFF121216),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1F1F24))),
            child: Center(
                child: InIcon(icon,
                    size: 15,
                    color: on ? Colors.white : const Color(0xFF8E8E93))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final active = _rooms.where((r) => asNum(r['memberCount']) > 0).toList();
    final matching = active.where(_matches).toList();
    final shown = [
      ...matching.where((r) => r['isBoosted'] == true),
      ...matching.where((r) => r['isBoosted'] != true),
    ];
    final liveRooms = active.where((r) => r['roomType'] == 'live').toList();
    final lives = active.where((r) => r['roomType'] == 'live').length;
    if (liveNowCount.value != lives) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => liveNowCount.value = lives);
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), _loadLikedPlaylists()]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _segmented(),
          const SizedBox(height: 14),
          if (_myRoom != null) ...[
            HomeInRoomBanner(
                title: _myRoom!['title'] as String? ?? 'Your room',
                speakingName: _rooms
                    .where((r) => r['id'] == _myRoom!['roomId'])
                    .map((r) => r['speakingName'] as String?)
                    .firstOrNull,
                onOpen: () => _openRoom(_myRoom!['roomId'] as String)),
            const SizedBox(height: 14),
          ],
          for (final r in _invited) ...[
            HomeInviteCard(
                title: '${r.hostName ?? 'A friend'} invited you to ${r.title}',
                subtitle: r.invitedAt == null
                    ? 'Tap to join the room'
                    : 'Tap to join the room · ${formatRelativeTime(r.invitedAt)}',
                onTap: () => _openRoom(r.id)),
            const SizedBox(height: 10),
          ],
          // Go live, then everyone live; View more opens the Live page.
          if (_filter == 'all') ...[
            PopcornLiveRow(
              lives: liveRooms,
              onOpen: (room) => openLiveSwipe(context, liveRooms, room),
              onChanged: _load,
            ),
            const SizedBox(height: 18),
          ],
          // Friends' faces with what they're doing; tap to join them.
          if (_filter == 'all') const FriendsInRoomsStrip(),
          if (_filter == 'all' || _filter == 'game')
            TournamentPopcornSection(
                key: ValueKey('tour-$_filter'), vertical: _filter == 'game'),
          Row(children: [
            Expanded(
              child: Text(
                  _filter == 'live'
                      ? 'Live now'
                      : 'Rooms${shown.isEmpty ? '' : ' · ${shown.length}'}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (_filter == 'live')
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                        appBar: AppBar(toolbarHeight: 44),
                        body: const LiveFeedScreen()))),
                child: const Text('Live feed'),
              ),
            _viewToggle(InIcons.ticket, 'Join with a code', false,
                _showJoinSheet),
          ]),
          const SizedBox(height: 10),
          if (_filter == 'game' || (!_loading && active.isEmpty))
            _actionRow(InIcons.game, 'Play vs computer',
                'Tic tac toe, UNO or Ludo · starts right away', _playComputer),
          if (context.watch<AuthProvider>().user?.locationSharingEnabled ==
              false) ...[
            _actionRow(
                InIcons.pin, 'See rooms near you', 'Turn on', _turnOnLocation),
            const SizedBox(height: 4),
          ],
          if (_loading)
            const SkeletonRoomCards()
          else if (_roomsLoadFailed && active.isEmpty)
            _actionRow(InIcons.cloud, 'Could not load rooms',
                'Tap to try again', () => _load())
          else if (active.isEmpty)
            _EmptyRooms(onCreate: _createRoom)
          else if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                  child: Text('No rooms like this right now',
                      style: TextStyle(color: AppColors.textDim))),
            )
          else ...[
            _CreateRoomCard(onTap: () => openCreateRoom(context)),
            const SizedBox(height: 14),
            for (final r in shown) ...[
              PopcornPostCard(
                  room: r,
                  onTap: () => _openRoom(r['id'] as String),
                  onLongPress: () =>
                      showRoomPeoplePopup(context, room: r, line: '')),
              const SizedBox(height: 14),
            ],
          ],
          for (final b in _liveBlends) ...[
            const SizedBox(height: 6),
            HomeBlendCard(
                title: _blendTitle(b),
                members: [
                  for (final m in (b['members'] as List? ?? const []))
                    if (m is Map) Map<String, dynamic>.from(m)
                ],
                watching: (b['watching'] as List).length,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BlendScreen(
                        blendId: b['id'] as String, together: true)))),
            const SizedBox(height: 6),
          ],
          if (_scheduledEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            _heading('Coming up'),
            const SizedBox(height: 12),
            for (final ev in _scheduledEvents) ...[
              HomeEventCard(
                  key: ValueKey('event-${ev['id']}'),
                  event: ev,
                  onRemind: () => _toggleRemind(ev['id'] as String),
                  onTap: () => _openRoom(ev['id'] as String)),
              const SizedBox(height: 10),
            ],
          ],
          if (_likedPlaylists.isNotEmpty) ...[
            const SizedBox(height: 12),
            _heading('On repeat'),
            const SizedBox(height: 12),
            ..._likedPlaylists.map((p) {
              final songs = ((p['songs'] as List?) ?? [])
                  .map((s) => Song.fromJson(s as Map<String, dynamic>))
                  .toList();
              return _actionRow(
                  InIcons.queue,
                  p['name'] as String? ?? 'Saved playlist',
                  '${songs.length} tracks · Your saved collection',
                  () => playPlaylistSmart(context, songs));
            }),
          ],
          const SizedBox(height: 12),
          const SizedBox(height: 16),
          const BannerCarousel(placement: 'home'),
        ],
      ),
    );
  }

  Widget _heading(String title, {String? trailing}) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600))),
        if (trailing != null)
          Text(trailing,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.lilac,
                  fontWeight: FontWeight.w600)),
      ]);

  // Solo game: a private game room with one computer, no setup.
  Future<void> _playComputer() async {
    final game = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF16151B),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Play vs computer',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ),
          for (final (id, emoji, label) in const [
            ('tictactoe', '❌', 'Tic tac toe'),
            ('uno', '🃏', 'UNO'),
            ('ludo', '🎲', 'Ludo'),
          ])
            ListTile(
              leading: Text(emoji, style: const TextStyle(fontSize: 22)),
              title: Text(label),
              onTap: () => Navigator.of(sheet).pop(id),
            ),
        ]),
      ),
    );
    if (game == null || !mounted) return;
    final level = await showComputerLevelSheet(context);
    if (level == null || !mounted) return;
    try {
      final room = await ApiClient.post('/rooms', body: {
        'roomType': 'game',
        'gameType': game,
        'visibility': 'private',
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PartyScreen(
              roomId: room['id'] as String, vsComputerLevel: level)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t start the game. Try again.')));
      }
    }
  }

  Widget _actionRow(
          InIconData icon, String title, String subtitle, VoidCallback onTap) =>
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
                  leading: InIcon(icon, color: AppColors.primary),
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
                  trailing: const InIcon(InIcons.chev, size: 18),
                  onTap: onTap)));
}

class _EmptyRooms extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyRooms({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: const Color(0xFF1C1638),
              borderRadius: BorderRadius.circular(17)),
          child: const Center(
              child: InIcon(InIcons.tv, size: 26, color: AppColors.lilac)),
        ),
        const SizedBox(height: 10),
        const Text('No rooms right now',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Start one and invite your people.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textDim)),
        const SizedBox(height: 12),
        FilledButton(onPressed: onCreate, child: const Text('Start a room')),
      ]),
    );
  }
}


/// First card in Popcorn's room list: start a room of your own.
class _CreateRoomCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateRoomCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create room',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFF1D1B24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.lilac, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    gradient: AppGradients.brandDiagonal,
                    borderRadius: BorderRadius.circular(16)),
                child: const Center(
                    child: InIcon(InIcons.plus, size: 26, color: Colors.white)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create room',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      Text('Watch, talk or play together',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 12.5)),
                    ]),
              ),
              const InIcon(InIcons.right, size: 20, color: AppColors.textFaint),
            ]),
          ),
        ),
      ),
    );
  }
}
