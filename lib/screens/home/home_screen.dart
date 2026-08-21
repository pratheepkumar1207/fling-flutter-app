import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../core/socket_service.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/avatar.dart';
import '../../widgets/countdown_badge.dart';
import '../../widgets/member_avatar_strip.dart';
import '../../widgets/post_composer_sheet.dart';
import '../../widgets/spinner.dart';
import '../../widgets/story_bar.dart';
import '../../widgets/story_viewer_screen.dart';
import '../party/party_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _roomFilters = [
  {'key': null, 'label': 'All', 'emoji': '✨'},
  {'key': 'watch', 'label': 'Watch Party', 'emoji': '📺', 'icon': 'assets/icons/rooms/watch_party.png'},
  {'key': 'voice', 'label': 'Voice Room', 'emoji': '🎙️', 'icon': 'assets/icons/rooms/voice_lobby.png'},
  {'key': 'game', 'label': 'Game', 'emoji': '🎮', 'icon': 'assets/icons/rooms/game_lobby.png'},
];

/// Real 3D-style room-type icon asset for a room's roomType, falling back
/// to null (caller shows an emoji) for types with no shipped asset yet.
String? _roomTypeIconAsset(String? roomType) {
  switch (roomType) {
    case 'watch':
      return 'assets/icons/rooms/watch_party.png';
    case 'voice':
      return 'assets/icons/rooms/voice_lobby.png';
    case 'game':
      return 'assets/icons/rooms/game_lobby.png';
    default:
      return null;
  }
}

/// Renders the real icon asset for [roomType] when one exists, otherwise
/// falls back to the closest emoji.
Widget _roomTypeIcon(String? roomType, double size) {
  final asset = _roomTypeIconAsset(roomType);
  if (asset != null) return Image.asset(asset, width: size, height: size);
  return Text(roomType == 'voice' ? '🎙️' : '📺', style: TextStyle(fontSize: size * 0.7));
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];
  List<RoomSummary> _invited = [];
  List<Map<String, dynamic>> _scheduledEvents = [];
  List<StoryEntry> _stories = [];
  String? _typeFilter;
  Timer? _refreshTimer;
  Timer? _activityDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStories();
    // This poll is now mostly a fallback (missed socket event, screen was
    // opened before anything changed) — rooms:activity below is what
    // actually makes a room appearing/disappearing feel instant. Set to
    // 1s per explicit request; worth knowing this means /rooms/browse gets
    // hit every second while Home is open, on every connected device,
    // regardless of whether anything actually changed.
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) => _load(silent: true));
    context.read<SocketService>().socket?.on('rooms:activity', _onRoomsActivity);
  }

  // Debounced — a burst of joins/leaves (e.g. a room emptying out member by
  // member) would otherwise fire several near-simultaneous refetches.
  void _onRoomsActivity(dynamic _) {
    _activityDebounce?.cancel();
    _activityDebounce = Timer(const Duration(milliseconds: 400), () => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _activityDebounce?.cancel();
    context.read<SocketService>().socket?.off('rooms:activity', _onRoomsActivity);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/rooms/browse').catchError((_) => []),
      ApiClient.get('/rooms/invited').catchError((_) => []),
      ApiClient.get('/rooms/events').catchError((_) => []),
    ]);
    if (!mounted) return;
    setState(() {
      _rooms = ((results[0] as List?) ?? []).cast<Map<String, dynamic>>();
      _invited = ((results[1] as List?) ?? [])
          .map((e) => RoomSummary.fromJson(e as Map<String, dynamic>))
          .where((r) => r.memberCount == 0)
          .toList();
      _scheduledEvents = ((results[2] as List?) ?? []).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _loadStories() async {
    try {
      final data = await ApiClient.get('/feed/stories');
      if (!mounted) return;
      setState(() => _stories = (data as List).map((e) => StoryEntry.fromJson(e as Map<String, dynamic>)).toList());
    } catch (_) {
      // Stories are a non-critical preview strip — silently skip on failure.
    }
  }

  void _openStoryViewer(StoryEntry entry) {
    final index = _stories.indexWhere((s) => s.userId == entry.userId);
    if (index == -1) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewerScreen(groups: _stories, startGroupIndex: index)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = (user?.name ?? 'there').split(' ').first;
    // Only surface a boosted room while it actually has people in it — an
    // empty boosted room isn't "trending", it's just paid-for and idle.
    final typeFiltered = _typeFilter == null ? _rooms : _rooms.where((r) => r['roomType'] == _typeFilter).toList();
    final featured = typeFiltered.where((r) => r['isBoosted'] == true && asNum(r['memberCount']) > 0).toList();
    final active = typeFiltered.where((r) => r['isBoosted'] != true && asNum(r['memberCount']) > 0).toList();

    return GestureDetector(
      // Swipe left-to-right anywhere on Home opens the profile screen, same
      // destination as tapping the top-bar avatar — a shortcut mirroring the
      // reference design's edge-swipe-to-profile gesture.
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }
      },
      child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hey $firstName 👋', style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Here's what's happening right now.", style: TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.textFaint, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Search lobbies, movies, people…', style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
                  ),
                  Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StoryBar(
            stories: _stories,
            onOpen: _openStoryViewer,
            leading: GestureDetector(
              onTap: () => showPostComposerSheet(context, onPosted: _loadStories, initialIsStory: true),
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Avatar(src: user?.avatarUrl, name: user?.name, size: AvatarSize.lg),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Text('+', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('My status', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textDim, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _roomFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _roomFilters[i];
                final selected = _typeFilter == f['key'];
                return GestureDetector(
                  onTap: () => setState(() => _typeFilter = f['key']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: selected ? AppGradients.volaCtaDiagonal : null,
                      color: selected ? null : AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? Colors.transparent : AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        f['icon'] != null
                            ? Image.asset(f['icon']!, width: 32, height: 32)
                            : Text(f['emoji']!, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          f['label']!,
                          style: TextStyle(color: selected ? Colors.white : AppColors.textDim, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const BannerCarousel(placement: 'home'),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Spinner()))
          else ...[
            if (_invited.isNotEmpty) ...[
              _sectionHeader('Invited'),
              ..._invited.map((r) => _roomTile(r.id, r.title, r.hostName, r.memberCount, inviteLabel: 'Invited')),
              const SizedBox(height: 20),
            ],
            _sectionHeader('Featured', iconAsset: 'assets/icons/rooms/featured.png'),
            featured.isEmpty
                ? const Text('No featured rooms right now.', style: TextStyle(color: AppColors.textFaint))
                : _heroBanner(featured[0]),
            if (featured.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length - 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final r = featured[i + 1];
                    return _posterCard(r);
                  },
                ),
              ),
            ],
            // Type-grouped horizontal rails — matches LobbyDark.dc.html's
            // "Live now" / "Trending watch parties" / "Voice rooms" /
            // "Game rooms" rows, instead of one mixed vertical list. Same
            // /rooms/browse data, just grouped by roomType client-side
            // (no new backend endpoint needed).
            if (active.isEmpty && _scheduledEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text('No active rooms right now. Be the first to start one.', style: TextStyle(color: AppColors.textFaint)),
              )
            else ...[
              ..._rail('Live now', active.where((r) => r['roomType'] == 'live').toList(), width: 118, height: 158),
              ..._rail('Trending watch parties', active.where((r) => r['roomType'] == 'watch').toList(), width: 200, height: 112),
              ..._rail('Voice rooms', active.where((r) => r['roomType'] == 'voice').toList(), width: 150, height: 96),
              ..._rail('Game rooms', active.where((r) => r['roomType'] == 'game').toList(), width: 118, height: 118),
              if (_scheduledEvents.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionHeader('Coming up'),
                ..._scheduledEvents.map(_eventTile),
              ],
            ],
          ],
        ],
      ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? iconAsset}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            if (iconAsset != null) ...[
              Image.asset(iconAsset, width: 40, height: 40),
              const SizedBox(width: 6),
            ],
            Text(title, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );

  Widget _heroBanner(Map<String, dynamic> r) {
    final thumbnail = r['nowPlayingThumbnail'] as String?;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: r['id'] as String))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              (thumbnail != null && thumbnail.isNotEmpty)
                  ? AppImage(source: thumbnail, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppGradients.brand)),
                      alignment: Alignment.center,
                      child: _roomTypeIcon(r['roomType'] as String?, 64),
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87], stops: [0.4, 1])),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(999)),
                  child: const Text('🔥 Trending Now', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['title'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${r['hostName'] ?? ''} · ${r['memberCount'] ?? 0} watching', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(gradient: AppGradients.volaCtaDiagonal, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                          child: const Text('▶ Watch', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                          child: Text('👥 ${r['memberCount'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // One rail section (header + horizontal scroll of poster cards) — empty
  // list (no header, no row) when this type has nothing active, so a quiet
  // category just doesn't take up space rather than showing an empty rail.
  List<Widget> _rail(String title, List<Map<String, dynamic>> rooms, {required double width, required double height}) {
    if (rooms.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      _sectionHeader(title),
      SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) => _posterCard(rooms[i], width: width, height: height),
        ),
      ),
    ];
  }

  String _watchingLabel(String? roomType) => switch (roomType) {
        'voice' => 'listening',
        'game' => 'spectating',
        _ => 'watching',
      };

  Widget _posterCard(Map<String, dynamic> r, {double width = 110, double? height}) {
    final thumbnail = r['nowPlayingThumbnail'] as String?;
    final roomType = r['roomType'] as String?;
    final isLive = roomType == 'live';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: r['id'] as String))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              (thumbnail != null && thumbnail.isNotEmpty)
                  ? AppImage(source: thumbnail, fit: BoxFit.cover)
                  : Container(color: AppColors.surface3, alignment: Alignment.center, child: _roomTypeIcon(roomType, 32)),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87], stops: [0.5, 1])),
              ),
              if (isLive)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(999)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 5, color: Colors.white),
                      SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['title'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${r['memberCount'] ?? 0} ${_watchingLabel(roomType)}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // roomType -> (badge label, badge tint) matching Lobby.dc.html's
  // per-type pastel pill colors. 'live' gets its own accent-tinted "Live
  // now" pill instead of always stamping every room with a LIVE badge
  // regardless of type, which is what this replaced.
  static const _typeBadges = {
    'watch': ('Watch party', Color(0xFF4272D9)),
    'voice': ('Voice room', Color(0xFFA23FCB)),
    'game': ('Game room', Color(0xFF2E9E5B)),
    'live': ('Live now', AppColors.accent),
  };

  Widget _roomTile(
    String id,
    String? title,
    String? hostName,
    int memberCount, {
    String? thumbnail,
    List<dynamic>? members,
    String? roomType,
    String? nowPlayingTitle,
    bool isBoosted = false,
    String? inviteLabel,
  }) {
    final isLive = roomType == 'live';
    final (badgeLabel, badgeColor) = _typeBadges[roomType] ?? ('Room', AppColors.textFaint);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isLive ? AppColors.accent.withValues(alpha: 0.35) : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: (thumbnail != null && thumbnail.isNotEmpty)
                        ? AppImage(source: thumbnail, fit: BoxFit.cover)
                        : Container(
                            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppGradients.brand)),
                            alignment: Alignment.center,
                            child: _roomTypeIcon(roomType, 24),
                          ),
                  ),
                ),
                if (isLive)
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, size: 5, color: Colors.white),
                        SizedBox(width: 3),
                        Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                        child: Text(badgeLabel, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                      if (isBoosted) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded, size: 11, color: AppColors.gold),
                        const SizedBox(width: 2),
                        const Text('Boosted', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                      if (inviteLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                          child: Text(inviteLabel, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(title ?? 'Untitled room', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Hosted by ${hostName ?? 'Unknown'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
                  if (roomType == 'watch' && nowPlayingTitle != null && nowPlayingTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Expanded(child: Text('Now playing — $nowPlayingTitle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (members != null && members.isNotEmpty) Flexible(child: MemberAvatarStrip(members: members)),
                      const SizedBox(width: 6),
                      Icon(Icons.people_alt_rounded, size: 12, color: AppColors.textFaint),
                      const SizedBox(width: 3),
                      Text('$memberCount ${isLive ? 'watching' : roomType == 'voice' ? 'listening' : roomType == 'game' ? 'spectating' : 'watching'}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(Map<String, dynamic> ev) {
    final scheduledAt = DateTime.tryParse(ev['scheduledAt'] as String? ?? '');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: ev['id'] as String))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: _roomTypeIcon(ev['roomType'] as String?, 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                  Text(ev['hostName'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                ],
              ),
            ),
            if (scheduledAt != null) CountdownBadge(scheduledAt: scheduledAt),
          ],
        ),
      ),
    );
  }
}
