import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/youtube_util.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';

/// Shown in place of the normal full-size player after a right-to-left
/// swipe on it (see party_screen.dart's _suggestionsMode) — the live player
/// shrinks into a small "now playing" box up top instead of disappearing,
/// and a scrollable grid of other videos to pin fills the rest, so the
/// party keeps playing uninterrupted while people pick what's next.
///
/// Suggestions aren't the same thing for every source: YouTube discontinued
/// its "related videos" API in 2023, so GET /youtube/suggestions falls back
/// to "other uploads from the same channel" instead — the closest honest
/// approximation left. Drive/OTT rooms have no comparable per-video catalog
/// to query at all, so they fall back to this device's own liked songs +
/// watch history (filtered to the same sourceType) — not true suggestions,
/// but a real, buildable "something to pin" list rather than an empty grid.
class VideoSuggestionsPanel extends StatefulWidget {
  final Widget miniPlayer;
  final String? nowPlayingTitle;
  final String? sourceType;
  final String? videoUrl;
  final void Function({
    required String videoUrl,
    required String title,
    String? thumbnail,
    required String sourceType,
  }) onPin;
  final VoidCallback onRestore;
  // Host taps a card and it's added immediately (onPin above, unchanged).
  // Everyone else's tap is a vote instead — see room_socket_controller
  // .dart's voteAdd/addVotes.
  final bool isHost;
  final void Function({
    required String videoUrl,
    required String title,
    String? thumbnail,
    required String sourceType,
  })? onVoteAdd;
  // Tapping a suggestion you've already voted for retracts it instead —
  // see RoomSocketController.unvoteAdd. Needs myUserId to know locally
  // whether "you" are one of a candidate's current voterIds.
  final void Function(String videoUrl)? onUnvoteAdd;
  final String? myUserId;
  final Map<String, Map<String, dynamic>> addVotes;

  const VideoSuggestionsPanel({
    super.key,
    required this.miniPlayer,
    this.nowPlayingTitle,
    required this.sourceType,
    required this.videoUrl,
    required this.onPin,
    required this.onRestore,
    this.isHost = false,
    this.onVoteAdd,
    this.onUnvoteAdd,
    this.myUserId,
    this.addVotes = const {},
  });

  @override
  State<VideoSuggestionsPanel> createState() => _VideoSuggestionsPanelState();
}

class _VideoSuggestionsPanelState extends State<VideoSuggestionsPanel> {
  bool _loading = true;
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = widget.sourceType == 'youtube'
          ? await _loadYoutubeSuggestions()
          : await _loadLikedHistoryFallback();
      if (mounted) setState(() => _suggestions = items);
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadYoutubeSuggestions() async {
    final videoId = extractYouTubeId(widget.videoUrl);
    if (videoId == null) return [];
    final data = await ApiClient.get('/youtube/suggestions?v=$videoId');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map((v) => {
              'videoUrl': 'https://www.youtube.com/watch?v=${v['videoId']}',
              'title': v['title'],
              'thumbnail': v['thumbnail'],
              'sourceType': 'youtube',
              'durationSeconds': v['durationSeconds'],
            })
        .toList();
  }

  // No room-agnostic "suggestions" pool exists for a private Drive file or a
  // DRM-locked OTT page — this device's own liked/history, filtered to the
  // same source, is the closest real (not fabricated) list available.
  Future<List<Map<String, dynamic>>> _loadLikedHistoryFallback() async {
    final results = await Future.wait([
      ApiClient.get('/liked-songs'),
      ApiClient.get('/song-history'),
    ]);
    final seen = <String>{widget.videoUrl ?? ''};
    final items = <Map<String, dynamic>>[];
    for (final list in results) {
      for (final raw in (list as List)) {
        final v = Map<String, dynamic>.from(raw as Map);
        final url = v['videoUrl'] as String?;
        if (url == null || !seen.add(url)) continue;
        if ((v['sourceType'] as String?) != widget.sourceType) continue;
        items.add(v);
      }
    }
    return items;
  }

  void _pin(Map<String, dynamic> item) {
    widget.onPin(
      videoUrl: item['videoUrl'] as String,
      title: item['title'] as String? ?? 'Untitled',
      thumbnail: item['thumbnail'] as String?,
      sourceType: item['sourceType'] as String? ?? widget.sourceType ?? '',
    );
  }

  void _vote(Map<String, dynamic> item) {
    widget.onVoteAdd?.call(
      videoUrl: item['videoUrl'] as String,
      title: item['title'] as String? ?? 'Untitled',
      thumbnail: item['thumbnail'] as String?,
      sourceType: item['sourceType'] as String? ?? widget.sourceType ?? '',
    );
  }

  bool _hasVoted(String videoUrl) {
    final myId = widget.myUserId;
    if (myId == null) return false;
    final voterIds = widget.addVotes[videoUrl]?['voterIds'] as List?;
    return voterIds?.contains(myId) ?? false;
  }

  void _handleTap(Map<String, dynamic> item) {
    if (widget.isHost || widget.onVoteAdd == null) {
      _pin(item);
    } else if (_hasVoted(item['videoUrl'] as String)) {
      widget.onUnvoteAdd?.call(item['videoUrl'] as String);
    } else {
      _vote(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Swipe left-to-right anywhere on this view goes back to the normal
      // player — the mirror image of the right-to-left swipe on the player
      // itself that opens this view (see party_screen.dart's
      // onHorizontalDragEnd). The restore icon in the header stays too, as
      // a non-gesture fallback.
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) widget.onRestore();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Suggestions',
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                IconButton(
                  tooltip: 'Back to full view',
                  onPressed: widget.onRestore,
                  icon: const Icon(Icons.unfold_more_rounded,
                      color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 10,
                      // A landscape (16:9) thumbnail (see _SuggestionCard's
                      // AspectRatio) plus a title/subtitle area below it.
                      childAspectRatio: 1.05,
                    ),
                    // +1 — whatever's actually playing right now is the
                    // first cell in this same grid (see _NowPlayingCard
                    // below), not a separate box above it; everything
                    // after that first cell is a plain suggestion.
                    itemCount: _suggestions.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _NowPlayingCard(
                          player: widget.miniPlayer,
                          title: widget.nowPlayingTitle,
                          onTap: widget.onRestore,
                        );
                      }
                      final item = _suggestions[i - 1];
                      final videoUrl = item['videoUrl'] as String;
                      final vote = widget.addVotes[videoUrl];
                      return _SuggestionCard(
                        item: item,
                        isHost: widget.isHost,
                        voteCount: (vote?['count'] as int?) ?? 0,
                        voteRequired: (vote?['required'] as int?) ?? 1,
                        hasVoted: _hasVoted(videoUrl),
                        onTap: () => _handleTap(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// The first cell in the suggestions grid — whatever's actually playing
// right now, using the live miniPlayer (not a static thumbnail) so it
// keeps playing uninterrupted while this view is up. Tapping it is the
// same as tapping the restore button: you're looking at what's already
// playing, so there's nothing to vote/pin here.
class _NowPlayingCard extends StatelessWidget {
  final Widget player;
  final String? title;
  final VoidCallback onTap;

  const _NowPlayingCard(
      {required this.player, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  player,
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('PLAYING',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(title ?? 'Now playing',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const Text('Tap to go back',
              style: TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
        ],
      ),
    );
  }
}

// Thumbnail (with a duration badge, if known) on top, title + a status line
// below it — a real info area, not text overlaid on the image. Tapping
// either adds immediately (host) or casts a vote (everyone else, showing
// live progress toward the room's required majority).
class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isHost;
  final int voteCount;
  final int voteRequired;
  final bool hasVoted;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.item,
    required this.onTap,
    this.isHost = false,
    this.voteCount = 0,
    this.voteRequired = 1,
    this.hasVoted = false,
  });

  String? get _durationLabel {
    final seconds = item['durationSeconds'];
    if (seconds is! num || seconds <= 0) return null;
    final d = Duration(seconds: seconds.round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _durationLabel;
    final hasVote = !isHost && voteCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.surface2),
                  if (item['thumbnail'] != null)
                    AppImage(
                        source: item['thumbnail'] as String?,
                        fit: BoxFit.cover),
                  if (duration != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(duration,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: hasVoted
                              ? AppColors.accent2.withValues(alpha: 0.9)
                              : Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle),
                      child: Icon(
                          isHost
                              ? Icons.push_pin_rounded
                              : (hasVoted
                                  ? Icons.check_rounded
                                  : Icons.how_to_vote_rounded),
                          color: Colors.white,
                          size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(item['title'] as String? ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (hasVote)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  hasVoted
                      ? '$voteCount/$voteRequired — tap to remove your vote'
                      : '$voteCount/$voteRequired votes to add',
                  style: const TextStyle(
                      color: AppColors.accent2,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
            )
          else
            Text(isHost ? 'Tap to add' : 'Tap to vote',
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: 10.5)),
        ],
      ),
    );
  }
}
