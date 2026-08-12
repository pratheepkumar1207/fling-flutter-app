import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import 'swipe_card.dart';

/// "Random Match" — one truly random eligible profile at a time (see GET
/// /discover/random), instead of the ranked/paginated Discover deck.
/// Optional gender filter, no other filters — the whole point is
/// randomness, not curation.
class RandomMatchScreen extends StatefulWidget {
  const RandomMatchScreen({super.key});

  @override
  State<RandomMatchScreen> createState() => _RandomMatchScreenState();
}

class _RandomMatchScreenState extends State<RandomMatchScreen> {
  DiscoverProfile? _current;
  bool _loading = true;
  String? _gender;
  String? _matchName;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() => _loading = true);
    try {
      final query = _gender != null ? '?gender=$_gender' : '';
      final data = await ApiClient.get('/discover/random$query');
      if (!mounted) return;
      setState(() {
        _current = data == null ? null : DiscoverProfile.fromJson(data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSwipe(String action) async {
    final current = _current;
    if (current == null) return;
    setState(() => _current = null);
    try {
      final res = await ApiClient.post('/swipe', body: {'toUserId': current.id, 'action': action}) as Map<String, dynamic>;
      if (!mounted) return;
      if (res['matched'] == true) {
        setState(() => _matchName = current.name);
        return;
      }
    } catch (_) {
      // Swallow — still move on to the next candidate either way, same as
      // DiscoverScreen's swipe-error handling.
    }
    _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('🎲 Random Match'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_alt_outlined, color: AppColors.textDim),
            color: AppColors.surface2,
            onSelected: (v) {
              setState(() => _gender = v);
              _loadNext();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('Any gender')),
              PopupMenuItem(value: 'male', child: Text('Male')),
              PopupMenuItem(value: 'female', child: Text('Female')),
              PopupMenuItem(value: 'other', child: Text('Other')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: Spinner(size: 28))
          else if (current == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No one new right now.\nTry again later or widen your filter.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint)),
              ),
            )
          else
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SwipeCard(key: ValueKey(current.id), profile: current, active: true, onSwipe: _handleSwipe),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _roundButton('✕', AppColors.danger, () => _handleSwipe('pass')),
                      const SizedBox(width: 20),
                      _roundButton('★', AppColors.accent, () => _handleSwipe('superlike')),
                      const SizedBox(width: 20),
                      _roundButton('♥', AppColors.primary, () => _handleSwipe('like')),
                    ],
                  ),
                ),
              ],
            ),
          if (_matchName != null)
            GestureDetector(
              onTap: () {
                setState(() => _matchName = null);
                _loadNext();
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("It's a match! 🎉", style: TextStyle(color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('You and $_matchName liked each other.', style: const TextStyle(color: AppColors.textDim), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, border: Border.all(color: AppColors.border)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: color, fontSize: 24)),
      ),
    );
  }
}
