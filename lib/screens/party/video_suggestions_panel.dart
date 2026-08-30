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
  final String? sourceType;
  final String? videoUrl;
  final void Function({
    required String videoUrl,
    required String title,
    String? thumbnail,
    required String sourceType,
  }) onPin;
  final VoidCallback onRestore;

  const VideoSuggestionsPanel({
    super.key,
    required this.miniPlayer,
    required this.sourceType,
    required this.videoUrl,
    required this.onPin,
    required this.onRestore,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child:
                    SizedBox(width: 140, height: 79, child: widget.miniPlayer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Now playing',
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Pin something to play next',
                        style: TextStyle(color: AppColors.text, fontSize: 13)),
                  ],
                ),
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
              : _suggestions.isEmpty
                  ? const Center(
                      child: Text('No suggestions right now',
                          style: TextStyle(color: AppColors.textFaint)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, i) => _SuggestionCard(
                          item: _suggestions[i],
                          onTap: () => _pin(_suggestions[i])),
                    ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _SuggestionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surface2),
            if (item['thumbnail'] != null)
              AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8)
                    ],
                  ),
                ),
                child: Text(item['title'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle),
                child: const Icon(Icons.push_pin_rounded,
                    color: Colors.white, size: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
