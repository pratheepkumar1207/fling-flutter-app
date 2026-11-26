import '../../widgets/profile_song_chip.dart';
import '../../widgets/share_bottom_sheet.dart';
import '../../core/active_room_holder.dart';
import '../../widgets/sub_tiers.dart';
import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../../widgets/insync_clay.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/smart_play_song.dart';
import '../../models/photo.dart';
import '../../models/post.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/report_user_sheet.dart';
import '../../widgets/spinner.dart';
import '../messages/message_thread_screen.dart';
import '../party/party_screen.dart';
import '../../widgets/notes.dart';
import 'highlights.dart';
import 'profile_layout.dart';
import 'profile_post_grid.dart';
import '../../widgets/verified_tick.dart';
import '../../widgets/two_row_carousel.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String userId;
  const CreatorProfileScreen({super.key, required this.userId});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final _avatarKey = GlobalKey();
  Map<String, dynamic>? _profile;
  List<Photo> _gallery = [];
  List<Playlist> _playlists = [];
  List<Song> _history = [];
  List<Song> _liked = [];
  List<Map<String, dynamic>> _topSupporters = [];
  // Their monthly subscription offer and whether I'm subscribed.
  Map<String, dynamic> _subscription = const {};
  List<Post> _posts = [];
  List<Post> _reels = [];
  // Subscriber-only posts and reels (their own ◆ tab).
  List<Post> _subPosts = [];
  List<Post> _tagged = [];
  Map<String, dynamic>? _note;
  Map<String, dynamic> _relationship = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.get('/creators/${widget.userId}/profile'),
        ApiClient.get('/gallery/user/${widget.userId}').catchError((_) => []),
        ApiClient.get('/playlists/user/${widget.userId}').catchError((_) => []),
        ApiClient.get('/song-history/user/${widget.userId}')
            .catchError((_) => []),
        ApiClient.get('/liked-songs/user/${widget.userId}')
            .catchError((_) => []),
        ApiClient.get('/creators/${widget.userId}/top-supporters')
            .catchError((_) => []),
        ApiClient.get('/feed/user/${widget.userId}?kind=posts')
            .catchError((_) => []),
        ApiClient.get('/feed/user/${widget.userId}?kind=reels')
            .catchError((_) => []),
        ApiClient.get('/feed/user/${widget.userId}?kind=tagged')
            .catchError((_) => []),
        ApiClient.get('/notes/user/${widget.userId}').catchError((_) => null),
        ApiClient.get('/relationship/${widget.userId}')
            .catchError((_) => <String, dynamic>{}),
        ApiClient.get('/creators/${widget.userId}/subscription')
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _gallery = ((results[1] as List?) ?? [])
            .map((e) => Photo.fromJson(e as Map<String, dynamic>))
            .toList();
        _playlists = ((results[2] as List?) ?? [])
            .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList();
        _history = ((results[3] as List?) ?? [])
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
        _liked = ((results[4] as List?) ?? [])
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
        _topSupporters =
            ((results[5] as List?) ?? []).cast<Map<String, dynamic>>();
        _posts = ((results[6] as List?) ?? [])
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _reels = ((results[7] as List?) ?? [])
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _subPosts = [
          ..._posts.where((x) => x.subTier != null),
          ..._reels.where((x) => x.subTier != null),
        ];
        _posts = _posts.where((x) => x.subTier == null).toList();
        _reels = _reels.where((x) => x.subTier == null).toList();
        _tagged = ((results[8] as List?) ?? [])
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();
        _note = results[9] is Map
            ? Map<String, dynamic>.from(results[9] as Map)
            : null;
        _relationship = results[10] is Map
            ? Map<String, dynamic>.from(results[10] as Map)
            : const {};
        _subscription = results[11] is Map
            ? Map<String, dynamic>.from(results[11] as Map)
            : const {};
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _toggleLikePlaylist(Playlist pl) async {
    final index = _playlists.indexWhere((p) => p.id == pl.id);
    if (index == -1) return;
    final wasLiked = pl.isLiked;
    setState(() {
      _playlists[index] = Playlist(
        id: pl.id,
        name: pl.name,
        visibility: pl.visibility,
        songs: pl.songs,
        isLiked: !wasLiked,
        likeCount: pl.likeCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      if (wasLiked) {
        await ApiClient.delete('/playlists/${pl.id}/like');
      } else {
        await ApiClient.post('/playlists/${pl.id}/like');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playlists[index] = pl;
      });
      _snack('Action failed');
    }
  }

  Future<void> _toggleRelationship(
      String path, String key, String on, String off) async {
    try {
      final res = await ApiClient.post('/$path/${widget.userId}')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _relationship = {..._relationship, key: res[key] == true});
      _snack(res[key] == true ? on : off);
    } catch (_) {
      _snack('Action failed');
    }
  }

  void _moreSheet(String name) {
    Widget tile(InIconData icon, String label, VoidCallback onTap,
            {bool danger = false}) =>
        ListTile(
          leading:
              InIcon(icon, color: danger ? AppColors.danger : AppColors.text),
          title: Text(label,
              style:
                  TextStyle(color: danger ? AppColors.danger : AppColors.text)),
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
        );
    final closeFriend = _relationship['closeFriend'] == true;
    final muted = _relationship['muted'] == true;
    final restricted = _relationship['restricted'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            tile(
                closeFriend ? InIcons.star : InIcons.star,
                closeFriend
                    ? 'Remove from close friends'
                    : 'Add to close friends',
                () => _toggleRelationship(
                    'close-friends',
                    'closeFriend',
                    'Added $name to close friends',
                    'Removed from close friends')),
            tile(
                muted ? InIcons.speaker : InIcons.mute,
                muted ? 'Unmute' : 'Mute',
                () => _toggleRelationship(
                    'mute',
                    'muted',
                    'Muted — their posts and stories won\'t show in your feed',
                    'Unmuted')),
            tile(
                InIcons.block,
                restricted ? 'Unrestrict' : 'Restrict',
                () => _toggleRelationship(
                    'restrict',
                    'restricted',
                    'Restricted — their comments on your posts are only visible to them',
                    'Unrestricted')),
            tile(InIcons.flame, 'Report or block', () {
              final p = _profile!;
              showReportUserSheet(
                context,
                userName: p['name'] as String? ?? '',
                onReport: () => showReportReasonSheet(
                  context,
                  userName: p['name'] as String? ?? '',
                  onSubmit: _report,
                  onAlsoBlock: () =>
                      ApiClient.post('/social/block/${widget.userId}'),
                ),
                onBlock: () => _confirmDialog(
                  title: 'Block ${p['name']}?',
                  description:
                      'They will no longer be able to interact with you.',
                  confirmLabel: 'Block',
                  danger: true,
                  onConfirm: _block,
                ),
              );
            }, danger: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final isFollowed = _profile?['isFollowedByMe'] == true;
    if (isFollowed && _profile?['followsMe'] == true) {
      final name = (_profile?['name'] as String? ?? '').split(' ').first;
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Unfollow $name?'),
          content: const Text(
              'You won’t be friends any more. Messages you already have stay.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(d).pop(true),
                child: const Text('Unfollow')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      if (isFollowed) {
        await ApiClient.post('/social/unfollow/${widget.userId}');
      } else {
        await ApiClient.post('/social/follow/${widget.userId}');
      }
      _load();
    } catch (_) {
      _snack('Action failed');
    }
  }

  Future<void> _invite() async {
    final roomId = ActiveRoomHolder.roomId;
    if (roomId == null) {
      _snack('Start or join a room first, then invite them');
      return;
    }
    try {
      await ApiClient.post('/rooms/$roomId/invite',
          body: {'userIds': [widget.userId]});
      _snack('Invited to ${ActiveRoomHolder.roomTitle ?? 'your room'}');
    } catch (_) {
      _snack('Couldn’t send the invite');
    }
  }

  Future<void> _block() async {
    try {
      await ApiClient.post('/social/block/${widget.userId}');
      _snack('User blocked');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _snack('Failed to block');
    }
  }

  Future<void> _report(String reason) async {
    try {
      await ApiClient.post('/social/report/${widget.userId}',
          body: {'reason': reason});
      _snack('Report submitted');
    } catch (_) {
      _snack('Failed to report');
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirmDialog(
      {required String title,
      required String description,
      required String confirmLabel,
      required bool danger,
      required VoidCallback onConfirm}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        content:
            Text(description, style: const TextStyle(color: AppColors.textDim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: danger ? AppColors.danger : AppColors.primary)),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
          title: InsyncPageTitle(
              (_profile?['username'] as String?)?.isNotEmpty == true
                  ? _profile!['username'] as String
                  : 'Profile'),
          actions: [
            if (_profile != null) ...[
              IconButton(
                tooltip: 'Share profile',
                onPressed: () => showShareBottomSheet(
                  context,
                  text: 'Find ${_profile!['name'] ?? 'them'} on Insync',
                  url: '${ApiClient.baseUrl}/u/${widget.userId}',
                ),
                icon: const InIcon(InIcons.share, color: AppColors.text),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: () =>
                    _moreSheet(_profile!['name'] as String? ?? ''),
                icon: const InIcon(InIcons.more, color: AppColors.text),
              ),
            ],
          ]),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : (_error != null || _profile == null)
              ? Center(
                  child: Text(_error ?? 'Profile not found.',
                      style: const TextStyle(color: AppColors.danger)))
              : _buildBody(),
    );
  }

  Widget _tabContent(String id) {
    final p = _profile!;
    switch (id) {
      case 'posts':
        return ProfilePostGrid(posts: _posts, emptyText: 'No posts yet');
      case 'reels':
        return ProfilePostGrid(
            posts: _reels, reels: true, emptyText: 'No reels yet');
      case 'subscribers':
        return _subscribersTab();
      case 'photos':
        return _gallery.isEmpty
            ? const Center(
                child: Text('No photos yet.',
                    style: TextStyle(color: AppColors.textFaint)))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: _gallery.length,
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppImage(
                      source: _gallery[i].imageData, fit: BoxFit.cover),
                ),
              );
      case 'music':
        final showLiked = p['hideLikedSongs'] != true;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_playlists.isNotEmpty) ...[
              _sectionTitle('Playlists'),
              TwoRowCarousel(tiles: [
                for (final pl in _playlists)
                  CarouselTile(
                    title: pl.name,
                    thumbnail:
                        pl.songs.isEmpty ? null : pl.songs.first.thumbnail,
                    badge:
                        '${pl.songs.length} song${pl.songs.length == 1 ? '' : 's'}',
                    onTap: pl.songs.isEmpty
                        ? null
                        : () => playPlaylistSmart(context, pl.songs),
                  ),
              ]),
              const SizedBox(height: 10),
              ..._playlists.map(
                (pl) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: insyncClay(radius: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pl.name,
                                    style: const TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '${pl.songs.length} song${pl.songs.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          // Members can like each other's playlists — shows
                          // up on the liker's own Home/Lobby afterward (see
                          // home_screen.dart's "Playlists you've liked").
                          GestureDetector(
                            onTap: () => _toggleLikePlaylist(pl),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InIcon(
                                    pl.isLiked ? InIcons.heart : InIcons.heart,
                                    color: pl.isLiked
                                        ? AppColors.danger
                                        : AppColors.textFaint,
                                    size: 18),
                                if (pl.likeCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text('${pl.likeCount}',
                                      style: const TextStyle(
                                          color: AppColors.textFaint,
                                          fontSize: 11.5)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (pl.songs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: pl.songs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final s = pl.songs[i];
                              return GestureDetector(
                                onTap: () => playSongSmart(context, s),
                                child: Container(
                                  width: 64,
                                  height: 48,
                                  decoration: BoxDecoration(
                                      color: AppColors.surface3,
                                      borderRadius: BorderRadius.circular(8)),
                                  clipBehavior: Clip.antiAlias,
                                  child: s.thumbnail != null
                                      ? AppImage(
                                          source: s.thumbnail,
                                          fit: BoxFit.cover)
                                      : const Center(child: Text('🎵')),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_history.isNotEmpty) ...[
              _sectionTitle('History'),
              TwoRowCarousel(tiles: [
                for (final s in _history)
                  CarouselTile(
                      title: s.title ?? 'Untitled',
                      thumbnail: s.thumbnail,
                      onTap: () => playSongSmart(context, s)),
              ]),
              const SizedBox(height: 16)
            ],
            if (showLiked && _liked.isNotEmpty) ...[
              _sectionTitle('Liked songs'),
              TwoRowCarousel(tiles: [
                for (final s in _liked)
                  CarouselTile(
                      title: s.title ?? 'Untitled',
                      thumbnail: s.thumbnail,
                      onTap: () => playSongSmart(context, s)),
              ])
            ],
            if (_playlists.isEmpty &&
                _history.isEmpty &&
                (!showLiked || _liked.isEmpty))
              const Padding(
                padding: EdgeInsets.all(30),
                child: Text('No music yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textFaint)),
              ),
          ],
        );
      case 'supporters':
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_topSupporters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Text('No supporters yet — send the first gift.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textFaint)),
              )
            else ...[
              _sectionTitle('Top supporters'),
              ..._topSupporters
                  .asMap()
                  .entries
                  .map((entry) => _supporterTile(entry.key, entry.value)),
            ],
          ],
        );
      default:
        return ProfilePostGrid(
            posts: _tagged, emptyText: 'No tagged posts yet');
    }
  }

  Widget _buildBody() {
    final p = _profile!;
    final isFollowed = p['isFollowedByMe'] == true;
    final activeRoom = p['activeRoom'] as Map?;
    final layout = ProfileLayout.fromJson(p['profileLayout'] is Map
        ? Map<String, dynamic>.from(p['profileLayout'] as Map)
        : null);
    final tabs = [
      ...layout.visibleTabs(
          const {'posts', 'reels', 'music', 'supporters', 'tagged'}),
    ];
    // Subscriber-only posts get a ◆ tab right after Reels.
    if (_subPosts.isNotEmpty) {
      final at = tabs.indexOf('reels');
      tabs.insert(at < 0 ? (tabs.isEmpty ? 0 : 1) : at + 1, 'subscribers');
    }
    final inRoom = activeRoom != null;
    final header = <Widget>[
      // Avatar gets a green ring + "IN ROOM" tag while they're in a room
      // (Rave-style), stats beside it.
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 86,
            height: 92,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: _avatarKey,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: inRoom
                        ? Border.all(color: AppColors.success, width: 2.5)
                        : null,
                  ),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: FittedBox(
                      child: Avatar(
                          src: p['avatarUrl'] as String?,
                          name: p['name'] as String?,
                          size: AvatarSize.lg),
                    ),
                  ),
                ),
                if (_note != null)
                  Positioned(
                    top: -10,
                    child: NoteBubble(
                        text: _note!['text'] as String?,
                        songTitle: _note!['songTitle'] as String?,
                        maxWidth: 96),
                  ),
                if (inRoom)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      child: const Text('IN ROOM',
                          style: TextStyle(
                              color: Color(0xFF06210F),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _profileStatColumn('${_posts.length}', 'Posts'),
                _profileStatColumn(
                    formatNumber(p['followerCount']), 'Followers'),
                _profileStatColumn(
                    formatNumber(p['followingCount']), 'Following'),
                _profileStatColumn(
                    formatNumber(p['totalGiftsReceived']), 'Gifts',
                    color: AppColors.gold),
              ],
            ),
          ),
        ],
      ),
      if (p['followedBy'] is Map) ...[
        const SizedBox(height: 10),
        Builder(builder: (_) {
          final f = p['followedBy'] as Map;
          final names = (f['names'] as List? ?? []).cast<String>();
          final others = ((f['count'] as num?) ?? 0).toInt() - names.length;
          final who = names.map((n) => n.split(' ').first).join(', ');
          return Text(
              others > 0
                  ? 'Followed by $who and $others ${others == 1 ? 'other' : 'others'}'
                  : 'Followed by $who',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12.5));
        }),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Flexible(
              child: Text(p['name'] as String? ?? '',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          if (p['isVerified'] == true) ...[
            const SizedBox(width: 5),
            const VerifiedTick(size: 15)
          ],
          if (p['isCreator'] == true) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('Creator',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          if (p['isVip'] == true) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('VIP',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          if ((p['tournamentWins'] as num? ?? 0) > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999)),
              child: Text(
                  '🏆 ${(p['tournamentWins'] as num) > 1 ? '${p['tournamentWins']}× ' : ''}Champion',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      if (p['bio'] != null && (p['bio'] as String).isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(p['bio'] as String,
            style: const TextStyle(
                color: AppColors.textDim, fontSize: 12.5, height: 1.5)),
      ],
      if (p['profileSong'] is Map)
        Align(
            alignment: Alignment.centerLeft,
            child: ProfileSongChip(
                song: Map<String, dynamic>.from(p['profileSong'] as Map))),
    ];
    for (final id in layout.visibleSections()) {
      if (id == 'highlights') {
        header.addAll([
          const SizedBox(height: 12),
          HighlightsRow(
              userId: widget.userId,
              isMine: false,
              ownerName: p['name'] as String?,
              ownerAvatar: p['avatarUrl'] as String?),
        ]);
      }
      if (id == 'rightNow' && activeRoom != null) {
        header.addAll([
          const SizedBox(height: 14),
          const Text('RIGHT NOW',
              style: TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          _activeRoomBadge(activeRoom),
        ]);
      }
    }
    final followsMe = p['followsMe'] == true;
    final followLabel = isFollowed
        ? (followsMe ? '\u2713 Friends' : 'Following')
        : (followsMe ? 'Follow back' : 'Follow');
    Widget iconButton(InIconData icon, String label, VoidCallback onTap,
            {Color color = Colors.white}) =>
        Expanded(
          child: Material(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  InIcon(icon, size: 19, color: color),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 11.5)),
                ]),
              ),
            ),
          ),
        );
    header.addAll([
      const SizedBox(height: 16),
      // Follow (following each other = friends) and Subscribe.
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: isFollowed
                ? OutlinedButton(
                    onPressed: _toggleFollow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: followsMe
                          ? const Color(0xFF5DE08A)
                          : AppColors.text,
                      side: BorderSide(
                          color: followsMe
                              ? const Color(0xFF30D158)
                              : AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(followLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: AppGradients.brand),
                        borderRadius: BorderRadius.circular(12)),
                    child: TextButton(
                      onPressed: _toggleFollow,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(42)),
                      child: Text(followLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
          ),
        ),
        if (_subscription['priceCoins'] != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: _subscriptionSheet,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFAC775),
                  side: const BorderSide(color: Color(0xFFF7B21A)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                    _subscription['subscribed'] == true
                        ? '\u25C6 ${subTierName(_subscription['tier'] as String? ?? 'silver')}'
                        : '\u25C6 Subscribe',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      Row(children: [
        iconButton(
            InIcons.chat,
            'Message',
            () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MessageThreadScreen(
                    userId: widget.userId,
                    name: p['name'] as String? ?? '',
                    avatarUrl: p['avatarUrl'] as String?)))),
        const SizedBox(width: 8),
        iconButton(InIcons.gift, 'Gift',
            () => showGiftBottomSheet(context, toUserId: widget.userId),
            color: AppColors.gold),
        const SizedBox(width: 8),
        iconButton(InIcons.useradd, 'Invite', _invite),
      ]),
      const SizedBox(height: 8),
    ]);
    return RefreshIndicator(
      onRefresh: _load,
      child: DefaultTabController(
        key: ValueKey(tabs.join(',')),
        length: tabs.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: header,
                ),
              ),
            ),
            if (tabs.isNotEmpty)
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeader(TabBar(
                  indicatorColor: AppColors.accent,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textDim,
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
              : TabBarView(children: [for (final t in tabs) _tabContent(t)]),
        ),
      ),
    );
  }

  // ◆ Subscriber-only posts: open ones in the grid, locked ones blurred
  // with the level they need, and a Subscribe card if any are locked.
  Widget _subscribersTab() {
    final open = _subPosts.where((x) => !x.locked).toList();
    final locked = _subPosts.where((x) => x.locked).toList();
    final mine = _subscription['tier'] as String?;
    return ListView(padding: EdgeInsets.zero, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Text(
            mine == null
                ? '\u25C6 ${_subPosts.length} posts for subscribers'
                : '\u25C6 ${open.length} of ${_subPosts.length} unlocked for you',
            style: const TextStyle(color: Color(0xFFFAC775), fontSize: 13)),
      ),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: [
          for (final x in [...open, ...locked])
            x.locked
                ? Stack(fit: StackFit.expand, children: [
                    ColoredBox(
                        color: subTierColors(x.subTier!).$2,
                        child: const SizedBox.expand()),
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        InIcon(InIcons.lock,
                            size: 20, color: subTierColors(x.subTier!).$1),
                        const SizedBox(height: 4),
                        Text(subTierName(x.subTier!),
                            style: TextStyle(
                                color: subTierColors(x.subTier!).$1,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ])
                : Stack(fit: StackFit.expand, children: [
                    const ProfilePostGrid(posts: [], emptyText: '').tile(context, x),
                    Positioned(
                        left: 4,
                        top: 4,
                        child: SubTierBadge(x.subTier!, fontSize: 8)),
                  ]),
        ],
      ),
      if (locked.isNotEmpty && _subscription['tiers'] != null)
        Padding(
          padding: const EdgeInsets.all(14),
          child: Material(
            color: const Color(0xFF1E1A10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFF7B21A))),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _subscriptionSheet,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Text(mine == null ? '\u25C6 Subscribe to unlock' : '\u25C6 Upgrade to unlock the rest',
                      style: const TextStyle(
                          color: Color(0xFFFAC775),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('From ${_subscription['priceCoins']} coins a month',
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  // Subscribe, or manage an existing subscription.
  // Silver, Gold and Platinum: pick a level (or change / cancel yours).
  Future<void> _subscriptionSheet() async {
    final sub = _subscription;
    final tiers = Map<String, dynamic>.from(
        (sub['tiers'] as Map?) ?? {'silver': sub['priceCoins']});
    final subscribed = sub['subscribed'] == true;
    final mine = sub['tier'] as String?;
    final renews = sub['autoRenew'] == true;
    final until = sub['expiresAt'] == null
        ? null
        : DateTime.parse(sub['expiresAt'] as String).toLocal();
    final untilText =
        until == null ? '' : '${until.day}/${until.month}/${until.year}';
    final name = _profile?['name'] as String? ?? 'this creator';
    final offered = [
      for (final t in kSubTiers)
        if (tiers[t] != null) t,
    ];
    String? picked = mine ?? (offered.contains('gold') ? 'gold' : offered.firstOrNull);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(subscribed ? 'Your level with $name' : 'Subscribe to $name',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      subscribed
                          ? (renews
                              ? 'Renews on $untilText.'
                              : 'Ends on $untilText. It won’t renew.')
                          : 'Pick a level · renews monthly from your coins',
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 13)),
                  const SizedBox(height: 14),
                  for (final t in offered) ...[
                    Builder(builder: (_) {
                      final (accent, bg, onAccent) = subTierColors(t);
                      final on = picked == t;
                      return GestureDetector(
                        onTap: () => setSheet(() => picked = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: on ? accent : accent.withValues(alpha: 0.35),
                                width: on ? 2 : 1),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('\u25C6 ',
                                      style: TextStyle(color: accent, fontSize: 15)),
                                  Text(subTierName(t),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  if (t == 'gold' && offered.length > 1) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                          color: accent,
                                          borderRadius: BorderRadius.circular(4)),
                                      child: Text('Most popular',
                                          style: TextStyle(
                                              color: onAccent,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                  if (mine == t) ...[
                                    const SizedBox(width: 6),
                                    const Text('Yours',
                                        style: TextStyle(
                                            color: AppColors.textDim,
                                            fontSize: 11.5)),
                                  ],
                                  const Spacer(),
                                  Text('${tiers[t]} coins/mo',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 6),
                                for (final perk in subTierPerks(t))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('\u2713 $perk',
                                        style: const TextStyle(
                                            color: Color(0xFFF9B2BA),
                                            fontSize: 12.5)),
                                  ),
                              ]),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 4),
                  if (picked != null && !(subscribed && picked == mine && renews))
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop('subscribe'),
                      style: FilledButton.styleFrom(
                          backgroundColor: subTierColors(picked!).$1,
                          foregroundColor: subTierColors(picked!).$3,
                          minimumSize: const Size.fromHeight(48)),
                      child: Text(subscribed && picked == mine
                          ? 'Turn renewal back on'
                          : subscribed
                              ? 'Switch to ${subTierName(picked!)} · ${tiers[picked]}/mo'
                              : 'Subscribe · ${tiers[picked]} coins/mo',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  if (subscribed && renews)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop('cancel'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                        child: const Text('Cancel renewal'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                      subscribed && picked != mine
                          ? 'A new level starts a fresh month at its price.'
                          : 'Cancel anytime · you keep it till the month ends',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: 11.5)),
                ]),
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = action == 'subscribe'
          ? await ApiClient.post('/creators/${widget.userId}/subscribe',
              body: {'tier': picked})
          : await ApiClient.post(
              '/creators/${widget.userId}/subscription/cancel');
      if (!mounted) return;
      setState(() => _subscription = {
            ..._subscription,
            ...Map<String, dynamic>.from(res as Map),
          });
      messenger.showSnackBar(SnackBar(
          content: Text(action == 'subscribe'
              ? '${subTierName(picked ?? 'silver')} with $name'
              : 'Renewal cancelled. You keep access until $untilText.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _profileStatColumn(String value, String label,
          {Color color = AppColors.text}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 17)),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
        ],
      );

  // "Right now" card — only populated by the backend when this person's
  // room-activity privacy (Public / Friends only / Private) lets the
  // viewer see it. Icon/
  // color/label/copy are room-type-aware, matching CreatorProfileDark (voice),
  // CreatorProfileWatchPartyDark, and CreatorProfileGameRoomDark exactly —
  // this used to always show a mic icon and "IN A ROOM" regardless of type.
  Widget _activeRoomBadge(Map activeRoom) {
    // Null for a private lobby: its id is its join link.
    final roomId = activeRoom['roomId'] as String?;
    final title = activeRoom['title'] as String? ?? 'a room';
    final roomType = activeRoom['roomType'] as String?;
    final memberCount = activeRoom['memberCount'] as int?;

    final (icon, color, label, gradientColors, verb) = switch (roomType) {
      'watch' => (
          InIcons.play,
          const Color(0xFFFFFFFF),
          'IN A WATCH PARTY',
          const [Color(0xFFC7C7C7), Color(0xFFFFFFFF)],
          'watching'
        ),
      'game' => (
          InIcons.game,
          AppColors.success,
          'IN A GAME ROOM',
          const [Color(0xFF9EE0BE), AppColors.success],
          'spectating'
        ),
      _ => (
          InIcons.mic,
          AppColors.accent,
          'IN A VOICE ROOM',
          const [AppColors.accent2, AppColors.primary],
          'listening'
        ),
    };

    final isPrivate = activeRoom['isPrivate'] == true;
    final canJoin = activeRoom['canJoin'] != false && !isPrivate;
    final nowTitle = activeRoom['nowPlayingTitle'] as String?;
    final nowThumb = activeRoom['nowPlayingThumbnail'] as String?;
    final gameType = activeRoom['gameType'] as String?;
    final members = ((activeRoom['members'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    final headline = isPrivate
        ? 'In a private room'
        : nowTitle != null
            ? '${roomType == 'watch' ? 'Watching' : 'Listening to'} $nowTitle'
            : roomType == 'game' && gameType != null
                ? 'Playing ${gameType.replaceAll('_', ' ')}'
                : title;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nowThumb != null && !isPrivate)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(source: nowThumb, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('● LIVE',
                          style: TextStyle(
                              color: Color(0xFF06210F),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (nowThumb == null || isPrivate) ...[
                  GlassIcon(
                    size: 40,
                    radius: 12,
                    colors: gradientColors,
                    glowColor: color.withValues(alpha: 0.4),
                    child: InIcon(isPrivate ? InIcons.lock : icon,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(headline,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (memberCount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              for (var i = 0; i < members.length; i++)
                                Transform.translate(
                                  offset: Offset(-6.0 * i, 0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: FittedBox(
                                      child: Avatar(
                                          src: members[i]['avatarUrl']
                                              as String?,
                                          name: members[i]['name'] as String?,
                                          size: AvatarSize.sm),
                                    ),
                                  ),
                                ),
                              Text('$memberCount $verb',
                                  style: const TextStyle(
                                      color: AppColors.textFaint,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (canJoin && roomId != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PartyScreen(roomId: roomId))),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.accent),
                      alignment: Alignment.center,
                      child: const Text('Join',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _supporterTile(int rank, Map<String, dynamic> supporter) =>
      GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) =>
                  CreatorProfileScreen(userId: supporter['id'] as String)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: insyncClay(radius: 22),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text('#${rank + 1}',
                    style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              ClipOval(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: AppImage(
                    source: supporter['avatarUrl'] as String?,
                    fit: BoxFit.cover,
                    placeholder: (_) => Container(
                        color: AppColors.surface3,
                        child: const InIcon(InIcons.user,
                            size: 18, color: AppColors.textFaint)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(supporter['name'] as String? ?? 'Unknown',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                      (supporter['totalCoins'] as num?)?.toStringAsFixed(0) ??
                          '0',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      );
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarHeader(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) =>
      Container(color: AppColors.bg, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarHeader old) => old.tabBar != tabBar;
}
