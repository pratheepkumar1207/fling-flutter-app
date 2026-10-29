import '../../widgets/profile_song_chip.dart';
import '../../widgets/verified_tick.dart';
import '../../theme/insync_icons.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/dynamic_options_cache.dart';
import '../../core/format.dart';
import '../../core/interest_options.dart';
import '../../core/language_options.dart';
import '../../core/location_service.dart';
import '../../core/smart_play_song.dart';
import '../../core/active_room_holder.dart';
import '../../models/post.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/interest_picker.dart';
import '../../widgets/photo_verification.dart';
import '../../widgets/profile_completeness_meter.dart';
import '../../widgets/prompt_editor.dart';
import '../../widgets/share_bottom_sheet.dart';
import '../../widgets/spinner.dart';
import '../achievements/achievements_screen.dart';
import '../auth/login_screen.dart';
import '../challenges/challenges_screen.dart';
import '../communities/communities_screen.dart';
import '../discover/discover_matches_screen.dart';
import '../events/events_screen.dart';
import '../feed/saved_posts_screen.dart';
import '../friends/friends_screen.dart';
import '../leaderboards/leaderboards_screen.dart';
import '../lobby/youtube_browse_screen.dart';
import '../messages/messages_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/privacy_screen.dart';
import '../../widgets/notes.dart';
import 'close_friends_screen.dart';
import 'highlights.dart';
import 'profile_layout.dart';
import 'profile_post_grid.dart';
import 'user_list_screen.dart';
import '../wallet/livestream_dashboard_screen.dart';
import '../wallet/referral_screen.dart';
import '../wallet/vip_store_screen.dart';

const _kMoreNav = [
  {'label': 'Messages', 'icon': '💬'},
  {'label': 'Friends', 'icon': '👥'},
  {'label': 'Matches', 'icon': '💘'},
  {'label': 'Communities', 'icon': '🏘️'},
  {'label': 'Events', 'icon': '📅'},
  {'label': 'Search', 'icon': '🔍'},
  {'label': 'Leaderboards', 'icon': '🏆'},
  {'label': 'Achievements', 'icon': '🎖️'},
  {'label': 'Challenges', 'icon': '🎯'},
  {'label': 'Livestream', 'icon': '🔴'},
  {'label': 'VIP Store', 'icon': '🖼️'},
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _gam;
  Map<String, dynamic>? _stats;
  int _matchesCount = 0;
  List<Playlist> _playlists = [];
  List<Song> _history = [];
  List<Song> _liked = [];
  List<Post> _posts = [];
  List<Post> _reels = [];
  List<Post> _tagged = [];
  Map<String, dynamic>? _note;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/gamification/me').catchError((_) => null),
      ApiClient.get('/social/stats').catchError((_) => null),
      Future.value(null), // (photos are posts now)
      ApiClient.get('/playlists').catchError((_) => []),
      ApiClient.get('/song-history').catchError((_) => []),
      ApiClient.get('/liked-songs').catchError((_) => []),
      ApiClient.get('/swipe/matches').catchError((_) => []),
      _myId == null
          ? Future.value(<dynamic>[])
          : ApiClient.get('/feed/user/$_myId?kind=posts').catchError((_) => []),
      _myId == null
          ? Future.value(<dynamic>[])
          : ApiClient.get('/feed/user/$_myId?kind=reels').catchError((_) => []),
      _myId == null
          ? Future.value(<dynamic>[])
          : ApiClient.get('/feed/user/$_myId?kind=tagged')
              .catchError((_) => []),
      _myId == null
          ? Future.value(null)
          : ApiClient.get('/notes/user/$_myId').catchError((_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _gam = results[0] as Map<String, dynamic>?;
      _stats = results[1] as Map<String, dynamic>?;
      _playlists = ((results[3] as List?) ?? [])
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
      _history = ((results[4] as List?) ?? [])
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
      _liked = ((results[5] as List?) ?? [])
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
      _matchesCount = (results[6] as List?)?.length ?? 0;
      _posts = ((results[7] as List?) ?? [])
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
      _reels = ((results[8] as List?) ?? [])
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
      _tagged = ((results[9] as List?) ?? [])
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
      _note = results[10] is Map
          ? Map<String, dynamic>.from(results[10] as Map)
          : null;
      _loading = false;
    });
  }

  String? get _myId => context.read<AuthProvider>().user?.id;

  Future<void> _createPlaylist(String name) async {
    try {
      await ApiClient.post('/playlists', body: {'name': name});
      _loadAll();
    } catch (_) {
      _showSnack('Failed to create playlist');
    }
  }

  Future<void> _updateVisibility(String playlistId, String visibility) async {
    try {
      await ApiClient.patch('/playlists/$playlistId',
          body: {'visibility': visibility});
      _loadAll();
    } catch (_) {
      _showSnack('Failed to update visibility');
    }
  }

  // Reuses the same YouTube search/playlists/liked browser the watch-party
  // queue picker uses (see source_picker_screen.dart) — onSelectOverride is
  // exactly the hook it already exposes for "add this video somewhere that
  // isn't a room's queue".
  void _addSongToPlaylist(String playlistId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => YoutubeBrowseScreen(
        visibility: 'public',
        onSelectOverride: (item) async {
          Navigator.of(context).pop();
          try {
            await ApiClient.post('/playlists/$playlistId/songs', body: {
              'videoUrl': 'https://www.youtube.com/watch?v=${item['videoId']}',
              'title': item['title'],
              'thumbnail': item['thumbnail'],
              'sourceType': 'youtube',
            });
            _loadAll();
          } on ApiException catch (e) {
            _showSnack(e.message);
          } catch (_) {
            _showSnack('Failed to add song');
          }
        },
      ),
    ));
  }

  Future<void> _removeSongFromPlaylist(String playlistId, String songId) async {
    try {
      await ApiClient.delete('/playlists/$playlistId/songs/$songId');
      _loadAll();
    } catch (_) {
      _showSnack('Failed to remove song');
    }
  }

  Future<void> _claimDailyBonus() async {
    try {
      final res = await ApiClient.post('/gamification/daily-bonus')
          as Map<String, dynamic>;
      _showSnack('+${res['coinsAwarded']} coins, ${res['streak']} day streak!');
      _loadAll();
      if (mounted) context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // Everything that isn't the profile itself — the old "More" grid, daily
  // bonus, saved posts, privacy, arrange, invite, log out — lives behind ☰.
  void _openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              _sectionHeader('More'),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.9,
                children: _kMoreNav
                    .map((item) =>
                        _moreNavTile(item['label']!, item['icon']!, sheet))
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (_gam != null) ...[
                _navRow(
                    icon: InIcons.gift,
                    label: 'Claim daily bonus',
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _claimDailyBonus();
                    }),
                const SizedBox(height: 8),
              ],
              _navRow(
                  icon: InIcons.bookmark,
                  label: 'Saved posts',
                  onTap: () => _openFromMenu(
                      sheet,
                      MaterialPageRoute(
                          builder: (_) => const SavedPostsScreen()))),
              const SizedBox(height: 8),
              _navRow(
                  icon: InIcons.archive,
                  label: 'Archive',
                  onTap: () => _openFromMenu(
                      sheet,
                      MaterialPageRoute(
                          builder: (_) => const ArchiveScreen()))),
              const SizedBox(height: 8),
              _navRow(
                  icon: InIcons.star,
                  label: 'Close friends',
                  onTap: () => _openFromMenu(
                      sheet,
                      MaterialPageRoute(
                          builder: (_) => const CloseFriendsScreen()))),
              const SizedBox(height: 8),
              _navRow(
                  icon: InIcons.feed,
                  label: 'Arrange profile',
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _openArrange();
                  }),
              const SizedBox(height: 8),
              _navRow(
                  icon: InIcons.lock,
                  label: 'Privacy',
                  onTap: () => _openFromMenu(
                      sheet,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyScreen()))),
              const SizedBox(height: 8),
              _navRow(
                  icon: InIcons.useradd,
                  label: 'Invite friends',
                  onTap: () => _openFromMenu(
                      sheet,
                      MaterialPageRoute(
                          builder: (_) => const ReferralScreen()))),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger)),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Opening a screen from the ☰ menu closes the menu first, so coming back
  // lands on the profile rather than the menu.
  void _openFromMenu(BuildContext sheet, Route<void> route) {
    Navigator.of(sheet).pop();
    Navigator.of(context).push(route);
  }

  Future<void> _openArrange() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ArrangeProfileScreen()));
    if (mounted) setState(() {});
  }

  void _shareProfile(User? user) {
    final handle = user?.username;
    showShareBottomSheet(
      context,
      text: handle != null && handle.isNotEmpty
          ? 'Find me on Insync: @$handle'
          : 'Find me on Insync',
      url: '${ApiClient.baseUrl}/u/${user?.id ?? ''}',
    );
  }

  // Compact summary cards (completeness, verification, level) — each opens
  // the full card it summarises, so nothing that was on the profile is lost.
  Widget _progressRow(User? user) {
    Widget card(String title, Widget body, Widget full) => GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.bg,
            isScrollControlled: true,
            builder: (_) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: full,
              ),
            ),
          ),
          child: Container(
            width: 150,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(10),
            decoration: insyncClay(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 11.5)),
                const SizedBox(height: 6),
                body,
              ],
            ),
          ),
        );
    final percent = user?.completenessPercent ?? 0;
    final verification = user?.photoVerificationStatus ?? 'none';
    // Cards size to their content, so large system text never clips them.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null)
              card(
                'Profile',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                          value: (percent / 100).clamp(0, 1).toDouble(),
                          minHeight: 5,
                          backgroundColor: AppColors.surface3,
                          color: AppColors.accent),
                    ),
                    const SizedBox(height: 4),
                    Text('$percent% complete',
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 12)),
                  ],
                ),
                ProfileCompletenessMeter(percent: percent),
              ),
            card(
              'Photo check',
              Text(
                switch (verification) {
                  'verified' => 'Verified',
                  'pending' => 'In review',
                  'rejected' => 'Try again',
                  _ => 'Get verified',
                },
                style: TextStyle(
                    color: verification == 'verified'
                        ? AppColors.success
                        : AppColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
              PhotoVerificationEntry(
                status: verification,
                selfieUrl: user?.verificationSelfieUrl,
                onSubmitted: () => context.read<AuthProvider>().refreshUser(),
              ),
            ),
            if (_gam != null)
              card(
                'Level ${_gam!['level']}',
                Text('🔥 ${_gam!['loginStreak']} day streak',
                    style:
                        const TextStyle(color: AppColors.text, fontSize: 12)),
                _gamificationCard(),
              ),
          ],
        ),
      ),
    );
  }

  // "Right now" on your own profile — the room you're in, if any.
  Widget? _rightNow() {
    final room = ActiveRoomHolder.room;
    if (room == null) return null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2A12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const InIcon(InIcons.live, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('You\'re in ${room['title'] ?? 'a room'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _musicTab() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionHeader('My playlists'),
          ..._playlists.map((p) => _playlistCard(p)),
          const SizedBox(height: 8),
          _CreatePlaylistRow(onCreate: _createPlaylist),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader('History'),
            ..._history.map(_songTile),
          ],
          if (_liked.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader('Liked songs'),
            ..._liked.map(_songTile),
          ],
        ],
      );

  Widget _tabContent(String id) => switch (id) {
        'posts' => ProfilePostGrid(
            posts: _posts, emptyText: 'Share your first post from the feed'),
        'reels' => ProfilePostGrid(
            posts: _reels, reels: true, emptyText: 'No reels yet'),
        'music' => _musicTab(),
        _ => ProfilePostGrid(
            posts: _tagged,
            emptyText: 'Posts you\'re tagged in will show here'),
      };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final layout = ProfileLayout.fromJson(user?.profileLayout);
    final tabs =
        layout.visibleTabs(const {'posts', 'reels', 'music', 'tagged'});
    final sections = <Widget>[];
    for (final id in layout.visibleSections()) {
      final Widget? w = switch (id) {
        'rightNow' => _rightNow(),
        'interests' => user != null && user.interests.isNotEmpty
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.interests
                    .map((i) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(i,
                              style: const TextStyle(
                                  color: AppColors.textDim,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              )
            : null,
        'progress' => _progressRow(user),
        'highlights' => user == null
            ? null
            : HighlightsRow(
                userId: user.id,
                isMine: true,
                ownerName: user.name,
                ownerAvatar: user.avatarUrl),
        _ => null,
      };
      if (w != null) {
        sections
            .add(Padding(padding: const EdgeInsets.only(top: 12), child: w));
      }
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: InsyncPageTitle(
            user?.username != null && user!.username!.isNotEmpty
                ? user.username!
                : 'Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const InIcon(InIcons.gear, color: AppColors.text),
          ),
          IconButton(
            tooltip: 'Menu',
            onPressed: _openMenu,
            icon: const InIcon(InIcons.menu, color: AppColors.text),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : DefaultTabController(
              key: ValueKey(tabs.join(',')),
              length: tabs.length,
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _profileHeader(user),
                          ...sections,
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  if (tabs.isNotEmpty)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarHeader(TabBar(
                        indicatorColor: AppColors.text,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: const Color(0xFF1E1B27),
                        labelColor: AppColors.text,
                        unselectedLabelColor: AppColors.textFaint,
                        tabs: [
                          for (final t in tabs)
                            Tab(
                                icon: InIcon(ProfileLayout.icon(t),
                                    semanticLabel: ProfileLayout.label(t))),
                        ],
                      )),
                    ),
                ],
                body: tabs.isEmpty
                    ? const SizedBox.shrink()
                    : TabBarView(
                        children: [for (final t in tabs) _tabContent(t)]),
              ),
            ),
    );
  }

  // Own-profile header — ring-avatar with a completeness-percent badge,
  // stats beside it (Posts/Followers/Following, then Matches/Photos/Level),
  // name/bio/city and badges below, then Edit / Share / Arrange. Interests
  // are their own arrangeable section now.
  Widget _profileHeader(User? user) {
    final percent = user?.completenessPercent ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: (percent / 100).clamp(0, 1),
                      strokeWidth: 3,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.pink),
                    ),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(6),
                      child: Avatar(
                          src: user?.avatarUrl,
                          name: user?.name,
                          size: AvatarSize.lg)),
                  if (_note != null)
                    Positioned(
                      top: -6,
                      child: NoteBubble(
                          text: _note!['text'] as String?,
                          songTitle: _note!['songTitle'] as String?,
                          maxWidth: 96),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.bg, width: 2)),
                      child: Text('$percent%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                          child: _profileStat('${_posts.length}', 'Posts')),
                      Expanded(
                          child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const UserListScreen())),
                        child: _profileStat(
                            formatNumber(_stats?['followers'] ?? 0),
                            'Followers'),
                      )),
                      Expanded(
                          child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const UserListScreen(
                                    startOnFollowing: true))),
                        child: _profileStat(
                            formatNumber(_stats?['following'] ?? 0),
                            'Following'),
                      )),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const DiscoverMatchesScreen())),
                          child: _profileStat('$_matchesCount', 'Matches'),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(children: [
          Flexible(
            child: Text(
              [user?.name, if (user?.age != null) '${user!.age}']
                  .whereType<String>()
                  .join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          if (user?.isVerified == true ||
              user?.photoVerificationStatus == 'verified') ...[
            const SizedBox(width: 5),
            const VerifiedTick(size: 15),
          ],
        ]),
        if ((user?.bio != null && user!.bio!.isNotEmpty) ||
            (user?.city != null && user!.city!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                if (user.bio != null && user.bio!.isNotEmpty) user.bio,
                if (user.city != null && user.city!.isNotEmpty) user.city
              ].whereType<String>().join('\n'),
              style: const TextStyle(
                  color: AppColors.textDim, fontSize: 13, height: 1.4),
            ),
          ),
        ProfileSongChip(song: user?.profileSong),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            if (user?.isVip == true) _badge('VIP', AppColors.gold),
            if (_gam?['rank'] != null)
              _badge(_gam!['rank'] as String, AppColors.accent),
            if (user?.equippedCarId != null &&
                (user!.carExpiresAt == null ||
                    user.carExpiresAt!.isAfter(DateTime.now())))
              _badge('🚗 Admission Car', AppColors.gold),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) => const EditProfileSheet()))
                      .then((_) => _loadAll()),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Text('Edit profile',
                        style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _shareProfile(user),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Text('Share profile',
                        style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Arrange profile',
                child: GestureDetector(
                  onTap: _openArrange,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12)),
                    child: const InIcon(InIcons.feed,
                        color: AppColors.textDim, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Shrinks to fit when four stats share the row beside the avatar.
  Widget _profileStat(String value, String label) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          // Labels shrink rather than run into each other at large text
          // (three stats share ~60px each beside the avatar).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 58),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 11)),
            ),
          ),
        ],
      ));

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _moreNavTile(String label, String icon, BuildContext sheet) {
    return GestureDetector(
      onTap: () {
        final screen = switch (label) {
          'Messages' => const MessagesScreen(),
          'Friends' => const FriendsScreen(),
          'Matches' => const DiscoverMatchesScreen(),
          'Communities' => const CommunitiesScreen(),
          'Events' => const EventsScreen(),
          'Search' => const SearchScreen(),
          'Leaderboards' => const LeaderboardsScreen(),
          'Achievements' => const AchievementsScreen(),
          'Challenges' => const ChallengesScreen(),
          'Livestream' => const LivestreamDashboardScreen(),
          'VIP Store' => const VipStoreScreen(),
          _ => null,
        };
        if (screen != null) {
          _openFromMenu(sheet, MaterialPageRoute(builder: (_) => screen));
        }
      },
      child: Container(
        decoration: insyncClay(radius: 22),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            // One line, shrunk to fit — long names used to break mid-word
            // ("Communitie / s").
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            if (trailing != null) trailing,
          ],
        ),
      );

  Widget _navRow(
          {required InIconData icon,
          required String label,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: insyncClay(radius: 22),
          child: Row(
            children: [
              InIcon(icon, color: AppColors.accent, size: 19),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5))),
              const InIcon(InIcons.chev, color: AppColors.textFaint, size: 20),
            ],
          ),
        ),
      );

  Widget _gamificationCard() {
    final g = _gam!;
    final xpToNext = asNum(g['xpToNextLevel']).toInt();
    final progress = ((100 - xpToNext).clamp(0, 100)) / 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: insyncClay(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level ${g['level']}',
                  style: const TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w600)),
              Text('$xpToNext XP to next level',
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surface3,
                color: AppColors.primary,
                minHeight: 8),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const InIcon(InIcons.streak, size: 15, color: Color(0xFFFF9F5A)),
            const SizedBox(width: 4),
            Text('${g['loginStreak']} day streak',
                style: const TextStyle(color: Color(0xFFFF9F5A), fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: _claimDailyBonus,
              child: const Text('Claim daily bonus')),
        ],
      ),
    );
  }

  Widget _playlistCard(Playlist p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: insyncClay(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(p.name,
                      style: const TextStyle(
                          color: AppColors.text, fontWeight: FontWeight.w600))),
              IconButton(
                icon: const InIcon(InIcons.plus,
                    color: AppColors.primary, size: 20),
                tooltip: 'Add song',
                visualDensity: VisualDensity.compact,
                onPressed: () => _addSongToPlaylist(p.id),
              ),
              DropdownButton<String>(
                value: p.visibility,
                dropdownColor: AppColors.surface2,
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                items: kVisibilityLabels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _updateVisibility(p.id, v);
                },
              ),
            ],
          ),
          Text('${p.songs.length} song${p.songs.length == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
          if (p.songs.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.songs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = p.songs[i];
                  return GestureDetector(
                    onTap: () => playSongSmart(context, s),
                    child: SizedBox(
                      width: 64,
                      height: 48,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                  color: AppColors.surface3,
                                  borderRadius: BorderRadius.circular(8)),
                              clipBehavior: Clip.antiAlias,
                              child: s.thumbnail != null
                                  ? AppImage(
                                      source: s.thumbnail, fit: BoxFit.cover)
                                  : const Center(child: Text('🎵')),
                            ),
                          ),
                          if (s.id != null)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    _removeSongFromPlaylist(p.id, s.id!),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const InIcon(InIcons.close,
                                      size: 10, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _songTile(Song s) => GestureDetector(
        onTap: () => playSongSmart(context, s),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: insyncClay(radius: 22),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.antiAlias,
                child: s.thumbnail != null
                    ? AppImage(source: s.thumbnail, fit: BoxFit.cover)
                    : const Center(child: Text('🎵')),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(s.title ?? 'Untitled',
                      style:
                          const TextStyle(color: AppColors.text, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
}

class _CreatePlaylistRow extends StatefulWidget {
  final Future<void> Function(String name) onCreate;
  const _CreatePlaylistRow({required this.onCreate});

  @override
  State<_CreatePlaylistRow> createState() => _CreatePlaylistRowState();
}

class _CreatePlaylistRowState extends State<_CreatePlaylistRow> {
  final _controller = TextEditingController();
  bool _creating = false;

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    await widget.onCreate(name);
    _controller.clear();
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(hintText: 'New playlist name'),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
            onPressed: _creating ? null : _submit, child: const Text('Create')),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => EditProfileSheetState();
}

class EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _city;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _religion;
  List<String> _interests = [];
  List<String> _languages = [];
  List<List<String>> _interestOptions = kInterestOptions;
  List<Map<String, dynamic>> _prompts = [];
  String? _gender;
  String? _orientation;
  String? _smoking;
  String? _drinking;
  String? _hasKids;
  String? _avatarDataUri;
  bool _saving = false;
  bool _hideOnlineStatus = false;
  bool _safeModeEnabled = false;
  bool _locationSharingEnabled = false;
  DateTime? _usernameChangedAt;
  Map<String, dynamic>? _profileSong;
  bool _songChanged = false;

  static const _usernameCooldown = Duration(days: 15);

  /// Pick the profile song from your liked songs (or history).
  Future<void> _pickSong() async {
    List songs = [];
    try {
      songs = await ApiClient.get('/liked-songs') as List;
      if (songs.isEmpty) songs = await ApiClient.get('/song-history') as List;
    } catch (_) {}
    if (!mounted) return;
    final yt = songs
        .cast<Map>()
        .where((s) => '${s['videoUrl'] ?? ''}'.contains('youtu'))
        .toList();
    final pick = await showModalBottomSheet<Map>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: yt.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                    'Like a song in a room first — your liked songs show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim)),
              )
            : ListView(shrinkWrap: true, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
                  child: Text('Profile song',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                for (final s in yt)
                  ListTile(
                    leading: const InIcon(InIcons.music,
                        size: 20, color: AppColors.lilac),
                    title: Text('${s['title'] ?? 'Song'}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(sheet).pop(s),
                  ),
                if (_profileSong != null)
                  ListTile(
                    leading: const InIcon(InIcons.close,
                        size: 20, color: AppColors.textDim),
                    title: const Text('Remove profile song'),
                    onTap: () => Navigator.of(sheet).pop(const {}),
                  ),
              ]),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _songChanged = true;
      _profileSong = pick.isEmpty
          ? null
          : {
              'title': pick['title'] ?? 'Song',
              'videoUrl': pick['videoUrl'],
              'thumbnail': pick['thumbnail'],
            };
    });
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  DateTime? get _canChangeFreeAt => _usernameChangedAt?.add(_usernameCooldown);
  bool get _inCooldown =>
      _canChangeFreeAt != null && _canChangeFreeAt!.isAfter(DateTime.now());
  int get _daysLeft =>
      _inCooldown ? _canChangeFreeAt!.difference(DateTime.now()).inDays + 1 : 0;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _username = TextEditingController(text: user?.username ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _city = TextEditingController(text: user?.city ?? '');
    _age = TextEditingController(text: user?.age?.toString() ?? '');
    _height = TextEditingController(text: user?.height?.toString() ?? '');
    _religion = TextEditingController(text: user?.religion ?? '');
    _interests = List<String>.from(user?.interests ?? []);
    _languages = List<String>.from(user?.languages ?? []);
    _prompts = List<Map<String, dynamic>>.from(user?.prompts ?? []);
    _gender = user?.gender;
    _orientation = user?.orientation;
    _smoking = user?.smoking;
    _drinking = user?.drinking;
    _hasKids = user?.hasKids;
    _avatarDataUri = user?.avatarUrl;
    _hideOnlineStatus = user?.hideOnlineStatus ?? false;
    _safeModeEnabled = user?.safeModeEnabled ?? false;
    _locationSharingEnabled = user?.locationSharingEnabled ?? false;
    _usernameChangedAt = user?.usernameChangedAt;
    _profileSong = user?.profileSong;
    InterestOptionsCache.load().then((options) {
      if (mounted) setState(() => _interestOptions = options);
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    if (!mounted) return;
    setState(
        () => _avatarDataUri = 'data:image/$ext;base64,${base64Encode(bytes)}');
  }

  Map<String, dynamic> _buildPatch() => {
        if (_songChanged) 'profileSong': _profileSong,
        'name': _name.text.trim(),
        'username': _username.text.trim(),
        'bio': _bio.text,
        'city': _city.text.trim(),
        'age': _age.text.trim().isEmpty ? null : int.tryParse(_age.text.trim()),
        'gender': _gender,
        'interests': _interests,
        'languages': _languages,
        'height': _height.text.trim().isEmpty
            ? null
            : int.tryParse(_height.text.trim()),
        'orientation': _orientation,
        'smoking': _smoking,
        'drinking': _drinking,
        'hasKids': _hasKids,
        'religion': _religion.text.trim(),
        'prompts': _prompts,
        'hideOnlineStatus': _hideOnlineStatus,
        'safeModeEnabled': _safeModeEnabled,
        'locationSharingEnabled': _locationSharingEnabled,
        if (_avatarDataUri != null) 'avatarUrl': _avatarDataUri,
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/auth/me', body: _buildPatch());
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      // Only actually requests the OS permission prompt + sends a position
      // when this was just turned on — the server no-ops POST /auth/location
      // for anyone with the flag off, so there'd be nothing to gain calling
      // it otherwise.
      if (_locationSharingEnabled) LocationService.requestPermissionAndPing();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const InsyncPageTitle('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Avatar(
                  src: _avatarDataUri, name: _name.text, size: AvatarSize.lg),
            ),
          ),
          const SizedBox(height: 16),
          _field('Name', _name),
          _field('Username', _username, enabled: !_inCooldown),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              _inCooldown
                  ? 'You can change your handle again in $_daysLeft day${_daysLeft == 1 ? '' : 's'} (once every 15 days)'
                  : 'You can change your handle once every 15 days',
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
            ),
          ),
          _field('Bio', _bio, maxLines: 2),
          _field('City', _city),
          _field('Age', _age, keyboardType: TextInputType.number),
          _section('ABOUT YOU'),
          const Text('Gender',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          DropdownButton<String?>(
            value: _gender,
            isExpanded: true,
            dropdownColor: AppColors.surface2,
            hint: const Text('Prefer not to say',
                style: TextStyle(color: AppColors.textFaint)),
            items: const [
              DropdownMenuItem(value: null, child: Text('Prefer not to say')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _field('Height (cm)', _height,
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Orientation',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButton<String?>(
                      value: _orientation,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Prefer not to say',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 12)),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Prefer not to say')),
                        DropdownMenuItem(
                            value: 'straight', child: Text('Straight')),
                        DropdownMenuItem(value: 'gay', child: Text('Gay')),
                        DropdownMenuItem(
                            value: 'lesbian', child: Text('Lesbian')),
                        DropdownMenuItem(
                            value: 'bisexual', child: Text('Bisexual')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _orientation = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _section('INTERESTS AND PROMPTS'),
          const Text('Interests',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          InterestPicker(
              selected: _interests,
              onChanged: (v) => setState(() => _interests = v),
              options: _interestOptions),
          const SizedBox(height: 12),
          const Text('Languages',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          InterestPicker(
              selected: _languages,
              onChanged: (v) => setState(() => _languages = v),
              options: kLanguageOptions),
          const SizedBox(height: 12),
          const Text('Prompts',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          PromptEditor(
              prompts: _prompts,
              onChanged: (v) => setState(() => _prompts = v)),
          _section('LIFESTYLE'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Smoking',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButton<String?>(
                      value: _smoking,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Prefer not to say',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 12)),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Prefer not to say')),
                        DropdownMenuItem(value: 'never', child: Text('Never')),
                        DropdownMenuItem(
                            value: 'sometimes', child: Text('Sometimes')),
                        DropdownMenuItem(
                            value: 'regularly', child: Text('Regularly')),
                      ],
                      onChanged: (v) => setState(() => _smoking = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Drinking',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButton<String?>(
                      value: _drinking,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Prefer not to say',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 12)),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Prefer not to say')),
                        DropdownMenuItem(value: 'never', child: Text('Never')),
                        DropdownMenuItem(
                            value: 'socially', child: Text('Socially')),
                        DropdownMenuItem(
                            value: 'regularly', child: Text('Regularly')),
                      ],
                      onChanged: (v) => setState(() => _drinking = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kids',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButton<String?>(
                      value: _hasKids,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Prefer not to say',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 12)),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Prefer not to say')),
                        DropdownMenuItem(
                            value: 'no', child: Text("Don't have kids")),
                        DropdownMenuItem(
                            value: 'yes', child: Text('Have kids')),
                      ],
                      onChanged: (v) => setState(() => _hasKids = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _field('Religion', _religion)),
            ],
          ),
          _section('MORE'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const InIcon(InIcons.music, size: 20, color: AppColors.lilac),
            title: const Text('Profile song'),
            subtitle: Text(
                _profileSong == null
                    ? 'Pick from your liked songs'
                    : '${_profileSong!['title']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
            trailing:
                const InIcon(InIcons.right, size: 16, color: AppColors.textDim),
            onTap: _pickSong,
          ),
          CheckboxListTile(
            value: _hideOnlineStatus,
            onChanged: (v) => setState(() => _hideOnlineStatus = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: const Text('Hide my online status',
                style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          ),
          CheckboxListTile(
            value: _safeModeEnabled,
            onChanged: (v) => setState(() => _safeModeEnabled = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: const Text(
                'Safe mode (only show verified profiles in Discover)',
                style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          ),
          CheckboxListTile(
            value: _locationSharingEnabled,
            onChanged: (v) =>
                setState(() => _locationSharingEnabled = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.primary,
            title: const Text('Share precise location for map-based Discover',
                style: TextStyle(color: AppColors.textDim, fontSize: 13)),
            subtitle: const Text(
                'Off by default — turning this on asks for location access.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _saving
                    ? null
                    : const LinearGradient(colors: AppGradients.brand),
                color: _saving ? AppColors.surface2 : null,
              ),
              alignment: Alignment.center,
              child: Text(_saving ? 'Saving…' : 'Save changes',
                  style: TextStyle(
                      color: _saving ? AppColors.textFaint : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType? keyboardType, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            decoration: insyncClay(radius: 22),
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _city.dispose();
    _age.dispose();
    _height.dispose();
    _religion.dispose();
    super.dispose();
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarHeader(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) => Container(
        color: AppColors.bg,
        child: tabBar,
      );

  @override
  bool shouldRebuild(covariant _TabBarHeader old) => old.tabBar != tabBar;
}
