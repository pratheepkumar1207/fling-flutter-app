import 'dart:async';
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
import '../experience/experience_hub.dart';
import '../party/party_screen.dart';
import '../lobby/lobby_create_screen.dart';
import '../../theme/insync_icons.dart';
import 'home_room_cards.dart';
import 'home_lobby_card.dart';
import 'popcorn_cards.dart';
import '../live/live_feed_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    // Now 30s, and _load skips silent refreshes while Home isn't visible.
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
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

  // Popcorn tab: All · Watch · Talk · Game · Live, list or grid.
  String _filter = 'all';
  bool _grid = false;
  bool _gridLoaded = false;

  Future<void> _loadGridPref() async {
    if (_gridLoaded) return;
    _gridLoaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool('popcorn.grid') ?? false;
      if (mounted && v != _grid) setState(() => _grid = v);
    } catch (_) {}
  }

  void _setGrid(bool v) {
    setState(() => _grid = v);
    SharedPreferences.getInstance()
        .then((p) => p.setBool('popcorn.grid', v))
        .catchError((_) => false);
  }

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
    _loadGridPref();
    final active = _rooms.where((r) => asNum(r['memberCount']) > 0).toList();
    final shown = active.where(_matches).toList();
    final boosted = active.where((r) => r['isBoosted'] == true).toList();
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
          if (boosted.isNotEmpty && _filter == 'all') ...[
            const Row(children: [
              InIcon(InIcons.bolt, size: 16, color: Color(0xFFFFD60A)),
              SizedBox(width: 5),
              Text('Boosted',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: boosted.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => PopcornBoostedCard(
                    room: boosted[i],
                    onTap: () => _openRoom(boosted[i]['id'] as String)),
              ),
            ),
            const SizedBox(height: 18),
          ],
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
                        appBar: AppBar(title: const Text('Live')),
                        body: const LiveFeedScreen()))),
                child: const Text('Live feed'),
              ),
            _viewToggle(InIcons.ticket, 'Join with a code', false,
                _showJoinSheet),
            _viewToggle(InIcons.menu, 'List view', !_grid, () => _setGrid(false)),
            _viewToggle(InIcons.feed, 'Grid view', _grid, () => _setGrid(true)),
          ]),
          const SizedBox(height: 10),
          if (context.watch<AuthProvider>().user?.locationSharingEnabled ==
              false) ...[
            _actionRow(
                InIcons.pin, 'See rooms near you', 'Turn on', _turnOnLocation),
            const SizedBox(height: 4),
          ],
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()))
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
          else if (_grid)
            LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final r in shown)
                    SizedBox(
                      width: (box.maxWidth - 10) / 2,
                      child: PopcornRoomTile(
                          room: r,
                          onTap: () => _openRoom(r['id'] as String),
                          onLongPress: () => showRoomPeoplePopup(context,
                              room: r, line: '')),
                    ),
                ],
              ),
            )
          else
            for (final r in shown) ...[
              PopcornRoomCard(
                  room: r,
                  onTap: () => _openRoom(r['id'] as String),
                  onLongPress: () =>
                      showRoomPeoplePopup(context, room: r, line: '')),
              const SizedBox(height: 9),
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
          _actionRow(
              InIcons.globe,
              'More ways to connect',
              'Vibe Match, communities & your creator space',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InsyncFeatureHubScreen()))),
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
