import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/location_service.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../party/party_screen.dart';
import 'discover_ui.dart';
import 'map_privacy_sheet.dart';
import 'map_search_screen.dart';
import 'peek_card.dart';
import '../../widgets/insync_snack.dart';

/// Map tiles. Defaults to OpenStreetMap drawn dark; a dark tile provider
/// (MapTiler, Stadia…) can be set at build time:
///   --dart-define=MAP_TILE_URL=https://…/{z}/{x}/{y}.png?key=…
///   --dart-define=MAP_TILE_DARK=false   (when those tiles are dark already)
const _kTileUrl = String.fromEnvironment('MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
const _kDarken = bool.fromEnvironment('MAP_TILE_DARK', defaultValue: true);

// Light map tiles turned dark and grey: inverted, desaturated, dimmed.
// Land comes out near black, water and parks dark grey, labels light grey.
const _kDarkMatrix = <double>[
  -0.27, -0.27, -0.27, 0, 204, //
  -0.27, -0.27, -0.27, 0, 204,
  -0.27, -0.27, -0.27, 0, 204,
  0, 0, 0, 1, 0,
];

enum _Tab { everyone, friends, rooms }

/// The people map: everyone who lets you see them, with details by how you
/// know them (server side, see GET /discover/map), live lobbies, busy areas,
/// search and ghost mode.
class MapExploreScreen extends StatefulWidget {
  final bool startOnRooms;
  const MapExploreScreen({super.key, this.startOnRooms = false});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  final _map = MapController();
  late _Tab _tab = widget.startOnRooms ? _Tab.rooms : _Tab.everyone;
  String? _roomType; // null = all
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;
  bool _needsLocation = false;
  String? _error;
  bool _turningOn = false;
  LatLng? _me;
  LatLng? _center;
  bool _moved = false;
  double _zoom = 13;
  bool _zoomSet = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({LatLng? area}) async {
    setState(() {
      _loading = true;
      _error = null;
      _moved = false;
    });
    final q = area == null ? '' : '?lat=${area.latitude}&lng=${area.longitude}';
    try {
      final results = await Future.wait([
        ApiClient.get('/discover/map$q'),
        ApiClient.get('/discover/map/rooms$q'),
      ]);
      _me ??= await _myPosition();
      if (!mounted) return;
      setState(() {
        _people = (results[0] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _rooms = (results[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
        _needsLocation = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _needsLocation = e.status == 400;
        _error = e.status == 400 ? null : e.message;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Couldn’t load the map. Try again.';
        });
      }
    }
  }

  Future<LatLng?> _myPosition() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p != null) return LatLng(p.latitude, p.longitude);
    } catch (_) {}
    return null;
  }

  // Asks permission, turns sharing on, saves a position, then opens the map.
  Future<void> _turnOnLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    setState(() => _turningOn = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        messenger.showSnackBar(insyncSnackBar(
            content: Text('Turn on location on your phone first.')));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) return;
      if (permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(insyncSnackBar(
            content: const Text('Allow location for Insync in your settings.'),
            action: SnackBarAction(
                label: 'Settings', onPressed: Geolocator.openAppSettings)));
        return;
      }
      await ApiClient.patch('/auth/me', body: {'locationSharingEnabled': true});
      final saved = await LocationService.requestPermissionAndPing();
      auth.refreshUser();
      if (!saved) {
        messenger.showSnackBar(insyncSnackBar(
            content: Text('Couldn’t get your location. Try again outside.')));
        return;
      }
      _me = await _myPosition();
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(insyncSnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _turningOn = false);
    }
  }

  List<Map<String, dynamic>> get _shownPeople => switch (_tab) {
        _Tab.everyone => _people,
        _Tab.friends => _people.where((p) => p['relation'] != 'none').toList(),
        _Tab.rooms => const [],
      };

  List<Map<String, dynamic>> get _shownRooms => _rooms
      .where((r) =>
          r['latitude'] != null &&
          (_roomType == null || r['roomType'] == _roomType))
      .toList();

  LatLng _at(Map p) =>
      LatLng(asNum(p['latitude']).toDouble(), asNum(p['longitude']).toDouble());

  /// People close together on screen become one "+N" circle.
  List<List<Map<String, dynamic>>> _clusters(
      List<Map<String, dynamic>> people) {
    // About 48 px at this zoom, in degrees.
    final cell = 48 * 360 / (256 * math.pow(2, _zoom));
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in people) {
      final at = _at(p);
      final key =
          '${(at.latitude / cell).floor()}:${(at.longitude / cell).floor()}';
      groups.putIfAbsent(key, () => []).add(p);
    }
    return groups.values.toList();
  }

  /// Busy areas: about 1 km squares with 3 or more people in them.
  List<CircleMarker> _busyAreas() {
    final cells = <String, List<LatLng>>{};
    for (final p in _people) {
      final at = _at(p);
      cells
          .putIfAbsent(
              '${(at.latitude * 100).round()}:${(at.longitude * 100).round()}',
              () => [])
          .add(at);
    }
    return [
      for (final pts in cells.values)
        if (pts.length >= 3)
          CircleMarker(
            point: LatLng(
                pts.map((e) => e.latitude).reduce((a, b) => a + b) / pts.length,
                pts.map((e) => e.longitude).reduce((a, b) => a + b) /
                    pts.length),
            radius: 350 + pts.length * 60.0,
            useRadiusInMeter: true,
            color: DColors.red.withValues(alpha: 0.13),
            borderColor: DColors.red.withValues(alpha: 0.25),
            borderStrokeWidth: 1,
          ),
    ];
  }

  RingKind _ringOf(Map p) {
    if (p['activeRoom'] != null) return RingKind.lobby;
    if (p['relation'] != 'none') return RingKind.close;
    return RingKind.stranger;
  }

  void _openPerson(Map p) => showPeekCard(context, p['id'] as String);

  void _openCluster(List<Map<String, dynamic>> group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheet) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.6),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${group.length} people around here',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in _sorted(group))
                  ListTile(
                    leading: PersonFace(
                        avatarUrl: p['avatarUrl'] as String?,
                        name: '${p['name']}',
                        size: 38,
                        ring: _ringOf(p)),
                    title: Text(p['age'] != null && p['relation'] == 'none'
                        ? '${p['name']}, ${p['age']}'
                        : '${p['name']}'),
                    subtitle: Text(
                        p['activeRoom'] != null
                            ? 'In a lobby'
                            : p['relation'] == 'friend'
                                ? 'Friend'
                                : p['relation'] == 'match'
                                    ? 'Match'
                                    : 'In this area',
                        style: TextStyle(
                            color: p['activeRoom'] != null
                                ? DColors.redSoft
                                : DColors.dim,
                            fontSize: 12)),
                    trailing: p['activeRoom']?['roomId'] != null
                        ? DChip('Join', tone: DTone.outline, onTap: () {
                            Navigator.of(sheet).pop();
                            _join(p['activeRoom']['roomId'] as String);
                          })
                        : null,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _openPerson(p);
                    },
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    int rank(Map p) => p['relation'] == 'friend'
        ? 0
        : p['relation'] == 'match'
            ? 1
            : p['activeRoom'] != null
                ? 2
                : 3;
    return [...list]..sort((a, b) => rank(a) - rank(b) != 0
        ? rank(a) - rank(b)
        : asNum(a['distanceKm']).compareTo(asNum(b['distanceKm'])));
  }

  void _join(String roomId) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));

  Future<void> _search() async {
    final r = await Navigator.of(context).push<MapSearchResult>(
        MaterialPageRoute(builder: (_) => const MapSearchScreen()));
    if (r == null || !mounted) return;
    if (r.at != null) {
      _map.move(r.at!, r.personId != null ? 15 : 13);
      _load(area: r.at);
    }
    if (r.personId != null) showPeekCard(context, r.personId!);
  }

  Future<void> _privacy() async {
    await showMapPrivacySheet(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final ghost =
        user?.ghostUntil != null && user!.ghostUntil!.isAfter(DateTime.now());
    return Scaffold(
      backgroundColor: Colors.black,
      body: _needsLocation
          ? _LocationPrimer(busy: _turningOn, onAllow: _turnOnLocation)
          : _error != null && _people.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: DColors.dim)),
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: _load, child: const Text('Try again')),
                  ]),
                )
              : Stack(children: [
                  _buildMap(),
                  if (_loading)
                    const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                            minHeight: 2, color: DColors.red)),
                  SafeArea(
                      child: _topBar(user?.avatarUrl, user?.name ?? 'You')),
                  if (_moved)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 104,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: DChip('Search this area',
                            icon: InIcons.search,
                            tone: DTone.white,
                            fontSize: 13,
                            onTap: () => _load(area: _center)),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 230,
                    child: Column(children: [
                      _roundBtn(InIcons.target, 'Back to me', () {
                        final me = _me;
                        if (me != null) _map.move(me, 14);
                      }),
                      const SizedBox(height: 8),
                      _roundBtn(InIcons.eyeoff,
                          ghost ? 'Ghost mode on' : 'Ghost mode', _privacy,
                          lit: ghost),
                    ]),
                  ),
                  Positioned(left: 0, right: 0, bottom: 0, child: _tray()),
                ]),
    );
  }

  Widget _buildMap() {
    final people = _shownPeople;
    final first = _me ??
        (_people.isNotEmpty
            ? _at(_people.first)
            : (_rooms.isNotEmpty && _rooms.first['latitude'] != null
                ? _at(_rooms.first)
                : null));
    final center = first ?? const LatLng(20.5937, 78.9629); // India
    // Group people at the zoom the map really opens at.
    if (!_zoomSet) {
      _zoomSet = true;
      _zoom = first != null ? 13 : 4;
    }
    Widget tiles = TileLayer(
        urlTemplate: _kTileUrl, userAgentPackageName: 'com.fling.app');
    if (_kDarken) {
      tiles = ColorFiltered(
          colorFilter: const ColorFilter.matrix(_kDarkMatrix), child: tiles);
    }
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: first != null ? 13 : 4,
        backgroundColor: const Color(0xFF000000),
        onPositionChanged: (camera, hasGesture) {
          final zoomMoved = (camera.zoom - _zoom).abs() > 0.4;
          if (zoomMoved) _zoom = camera.zoom;
          if (hasGesture) _center = camera.center;
          final show = hasGesture && !_moved;
          if (!zoomMoved && !show) return;
          // The map calls this while it updates itself: rebuild after.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              if (show) _moved = true;
            });
          });
        },
      ),
      children: [
        tiles,
        if (_tab != _Tab.rooms) CircleLayer(circles: _busyAreas()),
        if (_me != null)
          MarkerLayer(markers: [
            Marker(
              point: _me!,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: DColors.red, width: 4),
                ),
              ),
            ),
          ]),
        MarkerLayer(markers: [
          if (_tab == _Tab.rooms)
            for (final r in _shownRooms)
              Marker(point: _at(r), width: 100, height: 70, child: _roomPin(r))
          else
            for (final g in _clusters(people))
              g.length == 1
                  ? Marker(
                      point: _at(g.first),
                      width: 124,
                      height: 84,
                      child: _personPin(g.first))
                  : Marker(
                      point: LatLng(
                          g
                                  .map((p) => _at(p).latitude)
                                  .reduce((a, b) => a + b) /
                              g.length,
                          g
                                  .map((p) => _at(p).longitude)
                                  .reduce((a, b) => a + b) /
                              g.length),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () => _openCluster(g),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('+${g.length}',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                      ),
                    ),
        ]),
      ],
    );
  }

  Widget _personPin(Map p) {
    final close = p['relation'] != 'none';
    final inLobby = p['activeRoom'] != null;
    final name = '${p['name']}'.split(' ').first;
    final label =
        close ? name : (p['age'] != null ? '$name, ${p['age']}' : name);
    return GestureDetector(
      onTap: () => _openPerson(p),
      onLongPress: () => _openPerson(p),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PersonFace(
            avatarUrl: p['avatarUrl'] as String?,
            name: '${p['name']}',
            size: close ? 44 : 36,
            ring: _ringOf(p),
            online: p['online'] == true),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(99)),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (inLobby)
                const TextSpan(
                    text: ' · lobby', style: TextStyle(color: DColors.redSoft)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                color: close ? Colors.white : const Color(0xFFFFFFFF)),
          ),
        ),
      ]),
    );
  }

  Widget _roomPin(Map r) {
    return GestureDetector(
      onTap: () => _join(r['id'] as String),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 58,
          height: 40,
          decoration: BoxDecoration(
            color: DColors.redTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DColors.red, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: r['thumbnail'] != null
              ? AppImage(source: r['thumbnail'] as String, fit: BoxFit.cover)
              : InIcon(
                  r['roomType'] == 'voice'
                      ? InIcons.mic
                      : r['roomType'] == 'game'
                          ? InIcons.game
                          : InIcons.tv,
                  size: 20,
                  color: DColors.redSoft),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(99)),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(
                  text: 'LIVE ',
                  style: TextStyle(
                      color: DColors.red, fontWeight: FontWeight.w800)),
              TextSpan(text: '${r['memberCount'] ?? 0}'),
            ]),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _topBar(String? avatar, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(children: [
        Row(children: [
          _roundBtn(
              InIcons.back, 'Back', () => Navigator.of(context).maybePop()),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _search,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xEE000000),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFFFFFFF)),
                ),
                child: const Row(children: [
                  InIcon(InIcons.search, size: 17, color: DColors.dim),
                  SizedBox(width: 8),
                  Text('Search people or places',
                      style: TextStyle(color: DColors.dim, fontSize: 13)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _roundBtn(InIcons.gear, 'Who can see me', _privacy),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final t in _Tab.values) ...[
            DChip(
                switch (t) {
                  _Tab.everyone => 'Everyone',
                  _Tab.friends => 'Friends',
                  _Tab.rooms => 'Rooms'
                },
                tone: _tab == t ? DTone.white : DTone.plain,
                fontSize: 13,
                onTap: () => setState(() => _tab = t)),
            const SizedBox(width: 6),
          ],
        ]),
      ]),
    );
  }

  Widget _roundBtn(InIconData icon, String tip, VoidCallback onTap,
      {bool lit = false}) {
    return Tooltip(
      message: tip,
      child: Material(
        color: const Color(0xEE000000),
        shape: CircleBorder(
            side:
                BorderSide(color: lit ? DColors.red : const Color(0xFFFFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                  child: InIcon(icon,
                      size: 19, color: lit ? DColors.red : Colors.white))),
        ),
      ),
    );
  }

  Widget _tray() {
    final rooms = _tab == _Tab.rooms;
    final people = _sorted(_shownPeople);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: Color(0xFFFFFFFF))),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 0, 0, MediaQuery.paddingOf(context).bottom + 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        if (rooms)
          SizedBox(
            height: 30,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final t in const [
                    (null, 'All'),
                    ('watch', 'Watch'),
                    ('voice', 'Voice'),
                    ('live', 'Live'),
                    ('game', 'Games')
                  ]) ...[
                    DChip(t.$2,
                        tone: _roomType == t.$1 ? DTone.outline : DTone.plain,
                        onTap: () => setState(() => _roomType = t.$1)),
                    const SizedBox(width: 6),
                  ],
                ]),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _Legend(RingKind.close, 'Friend or match'),
              SizedBox(width: 12),
              _Legend(RingKind.lobby, 'In a lobby'),
              SizedBox(width: 12),
              _Legend(RingKind.stranger, 'Others, area only'),
            ]),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: rooms ? _roomList() : _peopleList(people),
        ),
      ]),
    );
  }

  Widget _peopleList(List<Map<String, dynamic>> people) {
    if (people.isEmpty) {
      return Center(
        child: Text(
            _loading
                ? 'Looking around…'
                : _tab == _Tab.friends
                    ? 'No friends on the map nearby'
                    : 'No one nearby yet',
            style: const TextStyle(color: DColors.dim, fontSize: 13)),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final p = people[i];
        final room = p['activeRoom'] as Map?;
        return GestureDetector(
          onTap: () {
            _map.move(_at(p), math.max(_zoom, 14));
            _openPerson(p);
          },
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              PersonFace(
                  avatarUrl: p['avatarUrl'] as String?,
                  name: '${p['name']}',
                  size: 34,
                  ring: _ringOf(p)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['name']}'.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                          room != null
                              ? 'In a lobby'
                              : '${p['distanceKm'] ?? '?'} km',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 12,
                              color: room != null
                                  ? DColors.redSoft
                                  : DColors.dim)),
                    ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _roomList() {
    final rooms = _rooms
        .where((r) => _roomType == null || r['roomType'] == _roomType)
        .toList();
    if (rooms.isEmpty) {
      return Center(
        child: Text(
            _loading ? 'Looking around…' : 'No live lobbies nearby right now',
            style: const TextStyle(color: DColors.dim, fontSize: 13)),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final r = rooms[i];
        final km = r['distanceKm'];
        return GestureDetector(
          onTap: () => _join(r['id'] as String),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 54,
                  height: 46,
                  color: DColors.photo,
                  alignment: Alignment.center,
                  child: r['thumbnail'] != null
                      ? AppImage(
                          source: r['thumbnail'] as String, fit: BoxFit.cover)
                      : const InIcon(InIcons.play,
                          size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                          [
                            if (km != null) '$km km',
                            '${r['memberCount'] ?? 0} in it'
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 12, color: DColors.dim)),
                    ]),
              ),
              const DChip('Join', tone: DTone.red, fontSize: 11),
            ]),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final RingKind kind;
  final String text;
  const _Legend(this.kind, this.text);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 12,
          height: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: switch (kind) {
                  RingKind.close => Colors.white,
                  RingKind.lobby => DColors.red,
                  _ => const Color(0xFFFFFFFF)
                },
                width: kind == RingKind.stranger ? 1.2 : 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 13,
                color: kind == RingKind.stranger ? DColors.dim : Colors.white)),
      ]);
}

/// Shown before the location permission: what the map does and the promise
/// about exact spots.
class _LocationPrimer extends StatelessWidget {
  final bool busy;
  final VoidCallback onAllow;
  const _LocationPrimer({required this.busy, required this.onAllow});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const InIcon(InIcons.back, color: Colors.white)),
          ),
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: DColors.redTint,
              shape: BoxShape.circle,
              border: Border.all(color: DColors.red, width: 1.5),
            ),
            alignment: Alignment.center,
            child: const InIcon(InIcons.pin, size: 44, color: DColors.red),
          ),
          const SizedBox(height: 18),
          const Text('See who’s around you',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          const _Check('Find friends and live lobbies nearby'),
          const _Check(
              'People you don’t know only see your area, never your exact spot'),
          const _Check('Ghost mode hides you any time'),
          const Spacer(),
          DButton(busy ? 'Turning on…' : 'Allow location',
              busy: busy, onPressed: onAllow),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Not now', style: TextStyle(color: DColors.dim)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final String text;
  const _Check(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const InIcon(InIcons.check, size: 18, color: DColors.red),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, height: 1.35))),
        ]),
      );
}
