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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Achievements'), actions: [
        if (!_loading) Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('$_unlocked/$_total', style: const TextStyle(color: AppColors.textDim)))),
      ]),
      body: _loading
          ? const Center(child: Spinner())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
              itemCount: _achievements.length,
              itemBuilder: (context, i) {
                final a = _achievements[i];
                final unlocked = a['unlocked'] == true;
                return Container(
                  decoration: BoxDecoration(
                    color: unlocked ? AppColors.gold.withValues(alpha: 0.05) : AppColors.surface,
                    border: Border.all(color: unlocked ? AppColors.gold.withValues(alpha: 0.4) : AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: unlocked ? 1 : 0.6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(a['icon'] as String? ?? '🏅', style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 6),
                        Text(a['label'] as String? ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
