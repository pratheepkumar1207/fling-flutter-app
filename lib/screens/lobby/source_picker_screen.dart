import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'youtube_browse_screen.dart';
import 'drive_browse_screen.dart';
import 'webview_browse_screen.dart';

/// Rave-style "pick a source" screen. YouTube is search/playlists/liked
/// (see youtube_browse_screen.dart); every streaming-platform tile below it
/// uses the same embedded-browser pattern (webview_browse_screen.dart) —
/// browse the real site in an in-app WebView, then "Start watch party
/// here" captures whatever page you land on. Drive browses your Google
/// Drive.
///
/// Sign-in reliability varies by platform and isn't something this app
/// controls: Netflix is confirmed (live) to block fresh sign-in via its
/// own bot detection for a WebView that isn't already authenticated — a
/// real, known limitation of staying embedded, not a bug here. The others
/// aren't individually verified either way, but the app never attempts to
/// work around detection regardless of outcome. YouTube doesn't have this
/// problem at all, so YouTube Surf additionally upgrades to a normal
/// fully-synced room when you land on a real /watch?v= page (see
/// WebviewBrowseScreen's _startHere).
///
/// Crunchyroll/X stay disabled: same DRM ceiling as the rest, not worth a
/// bespoke screen until there's real demand.
class SourcePickerScreen extends StatelessWidget {
  final String visibility;
  final String? topic;

  const SourcePickerScreen({super.key, required this.visibility, this.topic});

  void _openWebviewSource(BuildContext context, {required String platform, required String label, required String homeUrl}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebviewBrowseScreen(platform: platform, label: label, homeUrl: homeUrl, visibility: visibility, topic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Choose a source')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: [
          _SourceTile(
            emoji: '▶️',
            label: 'YouTube',
            available: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => YoutubeBrowseScreen(visibility: visibility, topic: topic)),
            ),
          ),
          _SourceTile(
            emoji: '🏄',
            label: 'YouTube Surf',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'youtube_surf', label: 'YouTube Surf', homeUrl: 'https://www.youtube.com'),
          ),
          _SourceTile(
            emoji: '📁',
            label: 'Drive',
            available: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DriveBrowseScreen(visibility: visibility, topic: topic)),
            ),
          ),
          _SourceTile(
            emoji: '🎬',
            label: 'Netflix',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'netflix', label: 'Netflix', homeUrl: 'https://www.netflix.com/in/'),
          ),
          _SourceTile(
            emoji: '⭐',
            label: 'Hotstar',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'hotstar', label: 'Hotstar', homeUrl: 'https://www.hotstar.com/in/'),
          ),
          _SourceTile(
            emoji: '📦',
            label: 'Prime Video',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'amazon', label: 'Prime Video', homeUrl: 'https://www.primevideo.com'),
          ),
          _SourceTile(
            emoji: '🅰️',
            label: 'Aha',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'aha', label: 'Aha', homeUrl: 'https://www.aha.video'),
          ),
          _SourceTile(
            emoji: '☀️',
            label: 'SunNXT',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'sunnxt', label: 'SunNXT', homeUrl: 'https://www.sunnxt.com'),
          ),
          _SourceTile(
            emoji: '📺',
            label: 'SonyLIV',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'sonyliv', label: 'SonyLIV', homeUrl: 'https://www.sonyliv.com'),
          ),
          _SourceTile(
            emoji: '📡',
            label: 'Airtel Xstream',
            available: true,
            onTap: () => _openWebviewSource(context, platform: 'airtel_xstream', label: 'Airtel Xstream', homeUrl: 'https://www.airtelxstream.in'),
          ),
          const _SourceTile(emoji: '🍥', label: 'Crunchyroll', available: false),
          const _SourceTile(emoji: '𝕏', label: 'X', available: false),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String emoji;
  final String label;
  final bool available;
  final VoidCallback? onTap;

  const _SourceTile({required this.emoji, required this.label, required this.available, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: available ? onTap : null,
      child: Opacity(
        opacity: available ? 1 : 0.35,
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              if (!available) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Coming soon', style: TextStyle(color: AppColors.textFaint, fontSize: 9))),
            ],
          ),
        ),
      ),
    );
  }
}
