import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const _roomFilters = [
  {'key': null, 'label': 'All', 'emoji': '✨'},
  {'key': 'watch', 'label': 'Watch Party', 'emoji': '📺'},
  {'key': 'voice', 'label': 'Voice Room', 'emoji': '🎙️'},
  {'key': 'game', 'label': 'Game', 'emoji': '🎮'},
  {'key': 'live', 'label': 'Live', 'emoji': '🔴'},
];

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];
  List<RoomSummary> _invited = [];
  List<Map<String, dynamic>> _scheduledEvents = [];
  List<StoryEntry> _stories = [];
  String? _typeFilter;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStories();
    // Home has no socket-driven live room list — without this, a room
    // someone else just created/joined only appears after a manual
    // pull-to-refresh, which reads as "my room isn't showing up" (it just
    // hasn't refreshed yet). Poll while this screen is visible instead.
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hey $firstName 👋', style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Here's what's happening right now.", style: TextStyle(color: AppColors.textDim)),
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
                            child: const Text('+', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
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
            height: 34,
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
                    child: Text(
                      '${f['emoji']} ${f['label']}',
                      style: TextStyle(color: selected ? Colors.black : AppColors.textDim, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
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
              ..._invited.map((r) => _roomTile(r.id, r.title, r.hostName, r.memberCount, badge: 'Invited')),
              const SizedBox(height: 20),
            ],
            _sectionHeader('Featured'),
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
            const SizedBox(height: 20),
            _sectionHeader('Lobby'),
            active.isEmpty && _scheduledEvents.isEmpty
                ? const Text('No active rooms right now. Be the first to start one.', style: TextStyle(color: AppColors.textFaint))
                : Column(
                    children: [
                      ...active.map((r) => _roomTile(
                            r['id'] as String,
                            r['title'] as String?,
                            r['hostName'] as String?,
                            asNum(r['memberCount']).toInt(),
                            thumbnail: r['nowPlayingThumbnail'] as String?,
                            members: r['members'] as List?,
                          )),
                      ..._scheduledEvents.map(_eventTile),
                    ],
                  ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
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
                      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, AppColors.primary])),
                      alignment: Alignment.center,
                      child: Text(r['roomType'] == 'voice' ? '🎙️' : '📺', style: const TextStyle(fontSize: 56)),
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
                          child: const Text('▶ Watch', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700)),
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

  Widget _posterCard(Map<String, dynamic> r) {
    final thumbnail = r['nowPlayingThumbnail'] as String?;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: r['id'] as String))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 110,
          child: Stack(
            fit: StackFit.expand,
            children: [
              (thumbnail != null && thumbnail.isNotEmpty)
                  ? AppImage(source: thumbnail, fit: BoxFit.cover)
                  : Container(color: AppColors.surface3, alignment: Alignment.center, child: Text(r['roomType'] == 'voice' ? '🎙️' : '📺', style: const TextStyle(fontSize: 28))),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87], stops: [0.5, 1])),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['title'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${r['memberCount'] ?? 0} watching', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomTile(String id, String? title, String? hostName, int memberCount, {String? badge, String? thumbnail, List<dynamic>? members}) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 96,
              child: (thumbnail != null && thumbnail.isNotEmpty)
                  ? AppImage(source: thumbnail, fit: BoxFit.cover)
                  : Container(color: AppColors.surface3, alignment: Alignment.center, child: const Text('📺', style: TextStyle(fontSize: 20))),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title ?? 'Untitled room', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                            child: Text(badge, style: const TextStyle(color: AppColors.accent, fontSize: 11)),
                          ),
                      ],
                    ),
                    Text('${hostName ?? ''} · $memberCount watching', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                    if (members != null && members.isNotEmpty) MemberAvatarStrip(members: members),
                  ],
                ),
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
              child: Text(ev['roomType'] == 'voice' ? '🎙️' : '📺', style: const TextStyle(fontSize: 20)),
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
