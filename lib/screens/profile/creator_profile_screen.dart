import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/smart_play_song.dart';
import '../../models/photo.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/cola_profile_card.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/spinner.dart';
import '../messages/message_thread_screen.dart';
import '../party/party_screen.dart';

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
        ApiClient.get('/song-history/user/${widget.userId}').catchError((_) => []),
        ApiClient.get('/liked-songs/user/${widget.userId}').catchError((_) => []),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _gallery = ((results[1] as List?) ?? []).map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
        _playlists = ((results[2] as List?) ?? []).map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
        _history = ((results[3] as List?) ?? []).map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
        _liked = ((results[4] as List?) ?? []).map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final isFollowed = _profile?['isFollowedByMe'] == true;
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

  Future<void> _addFriend() async {
    try {
      await ApiClient.post('/friends/request', body: {'toUserId': widget.userId});
      _snack('Friend request sent');
    } catch (_) {
      _snack('Failed to send request');
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

  Future<void> _report() async {
    try {
      await ApiClient.post('/social/report/${widget.userId}', body: {'reason': 'Reported from profile'});
      _snack('Report submitted');
    } catch (_) {
      _snack('Failed to report');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDialog({required String title, required String description, required String confirmLabel, required bool danger, required VoidCallback onConfirm}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        content: Text(description, style: const TextStyle(color: AppColors.textDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: danger ? AppColors.danger : AppColors.primary)),
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
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: Spinner(size: 28))
          : (_error != null || _profile == null)
              ? Center(child: Text(_error ?? 'Profile not found.', style: const TextStyle(color: AppColors.danger)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = _profile!;
    final isFollowed = p['isFollowedByMe'] == true;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ColaProfileCard(
            key: _avatarKey,
            avatarUrl: p['avatarUrl'] as String?,
            name: p['name'] as String?,
            username: p['username'] as String?,
            bio: p['bio'] as String?,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent, Color(0xFF0D3B3A)],
            ),
            badges: [
              if (p['isVerified'] == true) _badge('Verified', AppColors.success),
              if (p['isVip'] == true) _badge('VIP', AppColors.gold),
              if (p['isCreator'] == true) _badge('Creator', AppColors.accent),
            ],
            insideAction: (p['activeRoom'] as Map?) != null ? _activeRoomBadge(p['activeRoom'] as Map) : null,
            stats: [
              ColaStat('Followers', p['followerCount']),
              ColaStat('Following', p['followingCount']),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _toggleFollow,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
                child: Text(isFollowed ? 'Unfollow' : 'Follow'),
              ),
              OutlinedButton(onPressed: _addFriend, style: OutlinedButton.styleFrom(shape: const StadiumBorder()), child: const Text('Add friend')),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold, side: const BorderSide(color: AppColors.gold), shape: const StadiumBorder()),
                onPressed: () => showGiftBottomSheet(context, toUserId: widget.userId, targetKey: _avatarKey),
                child: const Text('🎁 Gift'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MessageThreadScreen(userId: widget.userId, name: p['name'] as String? ?? '', avatarUrl: p['avatarUrl'] as String?)),
                ),
                child: const Text('💬 Message'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => _confirmDialog(
                  title: 'Report ${p['name']}?',
                  description: 'Our team will review this report.',
                  confirmLabel: 'Report',
                  danger: false,
                  onConfirm: _report,
                ),
                child: const Text('Report'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), shape: const StadiumBorder()),
                onPressed: () => _confirmDialog(
                  title: 'Block ${p['name']}?',
                  description: 'They will no longer be able to interact with you.',
                  confirmLabel: 'Block',
                  danger: true,
                  onConfirm: _block,
                ),
                child: const Text('Block'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_gallery.isNotEmpty) ...[
            _sectionTitle('Gallery'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: _gallery.length,
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppImage(source: _gallery[i].imageData, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_playlists.isNotEmpty) ...[
            _sectionTitle('Playlists'),
            ..._playlists.map(
              (pl) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pl.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                    Text('${pl.songs.length} song${pl.songs.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                    if (pl.songs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pl.songs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final s = pl.songs[i];
                            return GestureDetector(
                              onTap: () => playSongSmart(context, s),
                              child: Container(
                                width: 64,
                                height: 48,
                                decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
                                clipBehavior: Clip.antiAlias,
                                child: s.thumbnail != null ? AppImage(source: s.thumbnail, fit: BoxFit.cover) : const Center(child: Text('🎵')),
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
          if (_history.isNotEmpty) ...[_sectionTitle('History'), ..._history.map(_songTile), const SizedBox(height: 16)],
          if (_liked.isNotEmpty) ...[_sectionTitle('Liked songs'), ..._liked.map(_songTile)],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  // Only ever populated by the backend when the viewer is VIP — seeing
  // someone's live room activity is a VIP perk.
  Widget _activeRoomBadge(Map activeRoom) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: activeRoom['roomId'] as String))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
              const SizedBox(width: 6),
              Text('Active in "${activeRoom['title']}"', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _songTile(Song s) => GestureDetector(
        onTap: () => playSongSmart(context, s),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.antiAlias,
                child: s.thumbnail != null ? AppImage(source: s.thumbnail, fit: BoxFit.cover) : const Center(child: Text('🎵')),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s.title ?? 'Untitled', style: const TextStyle(color: AppColors.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      );
}
