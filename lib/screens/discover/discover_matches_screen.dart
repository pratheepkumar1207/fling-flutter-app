import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';
import '../profile/creator_profile_screen.dart';

// Deterministic per-card gradient for matches with no avatar photo,
// matching DiscoverMatchesDark.dc.html's colorful full-bleed cards —
// local to this screen, same pattern as blocked_accounts_screen.dart.
const _kCardGradients = [
  [Color(0xFFC9825A), Color(0xFF5C2E17)],
  [Color(0xFF5A82B8), Color(0xFF1E3A5C)],
  [Color(0xFFB8A25A), Color(0xFF4C4017)],
  [Color(0xFF6BAF8A), Color(0xFF1E4C34)],
  [Color(0xFFA5709A), Color(0xFF4C2447)],
  [Color(0xFFC96B6B), Color(0xFF5C1E1E)],
];

/// Matches DiscoverMatchesDark.dc.html: full-bleed 2-column photo cards
/// (name/age overlaid bottom-left over a dark scrim, a pulsing green dot
/// for whoever's online right now) instead of the old bordered avatar
/// tiles. The mockup's "Active 2h ago" / "X km away" subtitles aren't
/// backed by real data — this app only tracks online-right-now (no
/// granular last-seen timestamp) and doesn't compute distance outside the
/// separate opt-in Explore Map flow — so offline cards fall back to the
/// real "Matched {date}" instead of a fabricated recency/distance string.
class DiscoverMatchesScreen extends StatefulWidget {
  const DiscoverMatchesScreen({super.key});

  @override
  State<DiscoverMatchesScreen> createState() => _DiscoverMatchesScreenState();
}

class _DiscoverMatchesScreenState extends State<DiscoverMatchesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/swipe/matches');
      if (!mounted) return;
      setState(() {
        _matches = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.text)),
                      const Text('Your Matches',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  if (!_loading)
                    Text(
                        '${_matches.length} ${_matches.length == 1 ? 'match' : 'matches'}',
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: Spinner())
                  : _matches.isEmpty
                      ? const Center(
                          child: Text(
                              'No matches yet.\nKeep swiping in Discover.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textFaint)))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.78),
                          itemCount: _matches.length,
                          itemBuilder: (context, i) => _card(_matches[i], i),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> m, int index) {
    final avatarUrl = m['avatarUrl'] as String?;
    final age = m['age'] as int?;
    final online = m['online'] == true;
    final matchedAt = DateTime.tryParse(m['matchedAt']?.toString() ?? '');
    final gradient = _kCardGradients[index % _kCardGradients.length];

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CreatorProfileScreen(userId: m['userId'] as String))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (avatarUrl != null)
              AppImage(source: avatarUrl, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient)),
                alignment: Alignment.center,
                child: Text(initials(m['name'] as String?),
                    style: const TextStyle(
                        color: Colors.white24,
                        fontWeight: FontWeight.bold,
                        fontSize: 44)),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xBF000000), Colors.transparent],
                    stops: [0, 0.55]),
              ),
            ),
            if (online)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.25),
                            blurRadius: 0,
                            spreadRadius: 3)
                      ]),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 10,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m['name'] as String? ?? ''}${age != null ? ', $age' : ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    online
                        ? 'Active now'
                        : (matchedAt != null
                            ? 'Matched ${DateFormat.MMMd().format(matchedAt)}'
                            : ''),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
