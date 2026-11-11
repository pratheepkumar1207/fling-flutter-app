import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/ott_page_suggestions.dart';
import '../../core/youtube_util.dart';
import '../../models/room_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';

/// Shown in place of the normal full-size player after a right-to-left
/// swipe on it, and automatically when the queue runs dry after a video
/// ends (see party_screen.dart's _suggestionsMode / queue:promptPin).
///
/// A two-row carousel that scrolls sideways: four edge-to-edge 16:9
/// thumbnails fill the width at a time, with no text. While something is
/// playing, the first tile (row 1, column 1) is the live miniPlayer itself,
/// so the party keeps playing uninterrupted; once nothing is playing that
/// tile is dropped and the suggestions start there instead. Each suggestion
/// shows the profile pictures of the people who pinned it.
///
/// Pinning is a vote for everyone, the host included — the server adds the
/// song once a majority of the room has pinned it (see syncHandler.js's
/// queue:voteAdd) and starts it straight away if nothing is playing. The
/// host can still long-press a tile to play it next without a vote.
///
/// Suggestions aren't the same thing for every source: YouTube discontinued
/// its "related videos" API in 2023, so GET /youtube/suggestions falls back
/// to "other uploads from the same channel" instead — the closest honest
/// approximation left. Drive/OTT rooms (and YouTube when that lookup isn't
/// available) fall back to this device's own liked songs + watch history,
/// filtered to the same sourceType — not true suggestions, but a real,
/// buildable "something to pin" list rather than an empty grid.
class VideoSuggestionsPanel extends StatefulWidget {
  final Widget miniPlayer;
  // False once nothing is playing (the room's playback state cleared) — the
  // live "now playing" tile is left out of the carousel then.
  final bool showNowPlaying;
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
  final bool isHost;
  final void Function({
    required String videoUrl,
    required String title,
    String? thumbnail,
    required String sourceType,
  })? onVoteAdd;
  // Tapping a suggestion you've already pinned retracts it instead — see
  // RoomSocketController.unvoteAdd. Needs myUserId to know locally whether
  // "you" are one of a candidate's current voterIds.
  final void Function(String videoUrl)? onUnvoteAdd;
  final String? myUserId;
  final Map<String, Map<String, dynamic>> addVotes;
  // Who's in the room, to turn a candidate's voterIds into profile pictures.
  final List<RosterEntry> roster;

  const VideoSuggestionsPanel({
    super.key,
    required this.miniPlayer,
    this.showNowPlaying = true,
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
    this.roster = const [],
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
    OttPageSuggestions.current.addListener(_onPageList);
    _load();
  }

  @override
  void dispose() {
    OttPageSuggestions.current.removeListener(_onPageList);
    super.dispose();
  }

  // Prime Video's, Netflix's or Hotstar's own list (next episodes, then similar
  // titles) arrives once the room's player has read the title's page; it replaces
  // the liked/history fallback as soon as it does.
  void _onPageList() {
    final items = OttPageSuggestions.itemsFor(widget.videoUrl);
    if (mounted && items.isNotEmpty) {
      setState(() {
        _suggestions = items;
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    var items = <Map<String, dynamic>>[];
    if (const {'amazon', 'netflix', 'hotstar'}.contains(widget.sourceType)) {
      items = OttPageSuggestions.itemsFor(widget.videoUrl);
    }
    if (widget.sourceType == 'youtube') {
      try {
        items = await _loadYoutubeSuggestions();
      } catch (_) {
        // e.g. 503 when YOUTUBE_API_KEY isn't configured — fall through.
      }
    }
    // Same-source liked songs + history: the only list for Drive/OTT, and
    // the fallback when YouTube suggestions are unavailable or empty, so
    // the carousel after a video ends is never just blank.
    if (items.isEmpty) {
      try {
        items = await _loadLikedHistoryFallback();
      } catch (_) {}
    }
    // The page's own list may have come in while this was loading.
    final page = OttPageSuggestions.itemsFor(widget.videoUrl);
    if (page.isNotEmpty) items = page;
    if (mounted) {
      setState(() {
        _suggestions = items;
        _loading = false;
      });
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

  void _pinNow(Map<String, dynamic> item) {
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

  List<String> _pinnerIds(String videoUrl) =>
      ((widget.addVotes[videoUrl]?['voterIds'] as List?) ?? const [])
          .whereType<String>()
          .toList();

  bool _hasPinned(String videoUrl) {
    final myId = widget.myUserId;
    return myId != null && _pinnerIds(videoUrl).contains(myId);
  }

  // Tap pins (a vote) for everyone, host included; tapping again retracts.
  // Without vote callbacks wired up, fall back to adding directly.
  void _handleTap(Map<String, dynamic> item) {
    final videoUrl = item['videoUrl'] as String;
    if (widget.onVoteAdd == null) {
      _pinNow(item);
    } else if (_hasPinned(videoUrl)) {
      widget.onUnvoteAdd?.call(videoUrl);
    } else {
      _vote(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterById = {for (final r in widget.roster) r.userId: r};
    final leading = widget.showNowPlaying ? 1 : 0;
    // While suggestions load, the now-playing tile is already there (with a
    // loading tile beside it): if the player left the screen for that
    // moment its page was dropped and the video restarted.
    if (_loading && leading == 0) return const Center(child: Spinner());
    final count = (_loading ? 1 : _suggestions.length) + leading;
    if (count == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No suggestions yet — use Search & queue to add the next song.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textFaint, fontSize: 13),
          ),
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      // Two tiles across the full width, each 16:9, two rows tall — four
      // visible at a time, edge to edge, scrolling sideways for the rest.
      final tileWidth = constraints.maxWidth / 2;
      final tileHeight = tileWidth * 9 / 16;
      final grid = Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: tileHeight * 2,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // two rows
              mainAxisExtent: tileWidth,
            ),
            itemCount: count,
            itemBuilder: (context, i) {
              if (i < leading) {
                return _KeepAlive(
                  child: _NowPlayingTile(
                    player: widget.miniPlayer,
                    title: widget.nowPlayingTitle,
                    onTap: widget.onRestore,
                  ),
                );
              }
              if (_loading) {
                return const Center(child: Spinner(size: 22));
              }
              final item = _suggestions[i - leading];
              final videoUrl = item['videoUrl'] as String;
              return _SuggestionTile(
                item: item,
                pinners: [
                  for (final id in _pinnerIds(videoUrl))
                    if (rosterById[id] != null) rosterById[id]!,
                ],
                pinnedByMe: _hasPinned(videoUrl),
                onTap: () => _handleTap(item),
                onLongPress: widget.isHost ? () => _pinNow(item) : null,
              );
            },
          ),
        ),
      );
      return grid;
    });
  }
}

// Keeps the now-playing tile (and so the live player inside it) mounted
// when it scrolls out of view — GridView.builder would otherwise dispose
// it, killing the WebView and restarting the video.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// Row 1, column 1 while something's playing — the live miniPlayer (not a
// static thumbnail). Tapping it goes back to the full-size player.
class _NowPlayingTile extends StatelessWidget {
  final Widget player;
  final String? title;
  final VoidCallback onTap;

  const _NowPlayingTile(
      {required this.player, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Now playing: ${title ?? 'video'}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            IgnorePointer(child: player),
            // Inset border so it doesn't change the tile's 16:9 size.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A thumbnail and nothing else — no title or text. Bottom-left: profile
// pictures of whoever has pinned it so far. A song you pinned yourself gets
// an inset highlight border.
class _SuggestionTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<RosterEntry> pinners;
  final bool pinnedByMe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SuggestionTile({
    required this.item,
    required this.pinners,
    required this.pinnedByMe,
    required this.onTap,
    this.onLongPress,
  });

  static const _maxAvatars = 3;

  @override
  Widget build(BuildContext context) {
    final shown = pinners.take(_maxAvatars).toList();
    return Semantics(
      // No visible text, but screen readers (and tests) still get the title.
      label: item['title'] as String? ?? 'Suggestion',
      button: true,
      selected: pinnedByMe,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.surface2),
            if (item['thumbnail'] != null)
              AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover)
            else
              // Prime's similar titles can arrive before their poster has
              // loaded on the page: the name stands in for it.
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    item['title'] as String? ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            // Prime episodes: which one, e.g. S2 E3.
            if (item['badge'] is String)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['badge'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            if (pinnedByMe)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent2, width: 2)),
                ),
              ),
            if (shown.isNotEmpty)
              Positioned(
                left: 6,
                bottom: 6,
                child: SizedBox(
                  height: 25,
                  width: 25.0 + (shown.length - 1) * 15,
                  child: Stack(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Positioned(
                          left: i * 15.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            // Avatar's smallest size is 32px; scaled to fit
                            // a compact stack on a half-width thumbnail.
                            child: SizedBox.square(
                              dimension: 22,
                              child: FittedBox(
                                child: Avatar(
                                    src: shown[i].avatarUrl,
                                    name: shown[i].name,
                                    size: AvatarSize.sm),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
