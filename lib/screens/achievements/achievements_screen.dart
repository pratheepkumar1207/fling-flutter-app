import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _achievements = [];
  int _unlocked = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/gamification/achievements') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _achievements = (data['achievements'] as List).cast<Map<String, dynamic>>();
        _unlocked = data['unlockedCount'] as int? ?? 0;
        _total = data['totalCount'] as int? ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Deterministic per-badge gradient (no color field from the API) — matches
  // AchievementsDark.dc.html's glossy circular badge icons.
  static const _badgeGradients = [
    [Color(0xFFE8A26B), Color(0xFFC5522E)],
    [Color(0xFFCC9DE8), Color(0xFF9955B8)],
    [Color(0xFFE8C56B), Color(0xFFC28A38)],
    [Color(0xFF7ED9B0), Color(0xFF3F9E6E)],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Achievements'), actions: [
        if (!_loading) Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('$_unlocked/$_total', style: const TextStyle(color: AppColors.textDim)))),
      ]),
      body: _loading
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Badges', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textFaint, letterSpacing: 0.6)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 10, childAspectRatio: 0.72),
                    itemCount: _achievements.length,
                    itemBuilder: (context, i) {
                      final a = _achievements[i];
                      final unlocked = a['unlocked'] == true;
                      final gradient = _badgeGradients[i % _badgeGradients.length];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: unlocked
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
                                    boxShadow: [BoxShadow(color: gradient[1].withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
                                  )
                                : BoxDecoration(shape: BoxShape.circle, color: AppColors.surface2, border: Border.all(color: AppColors.border, width: 1.5)),
                            alignment: Alignment.center,
                            child: unlocked
                                ? Text(a['icon'] as String? ?? '🏅', style: const TextStyle(fontSize: 24))
                                : Icon(Icons.lock_rounded, color: AppColors.textFaint, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            unlocked ? (a['label'] as String? ?? '') : 'Locked',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: unlocked ? AppColors.textDim : AppColors.textFaint, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
