import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

const _scopeLabels = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _challenges = [];
  String? _claiming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/gamification/challenges');
      if (!mounted) return;
      setState(() {
        _challenges = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim(String key) async {
    setState(() => _claiming = key);
    try {
      final res = await ApiClient.post('/gamification/challenges/$key/claim') as Map<String, dynamic>;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+${res['coinsAwarded']} coins!')));
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Challenges')),
      body: _loading
          ? const Center(child: Spinner())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _challenges.length,
              itemBuilder: (context, i) {
                final c = _challenges[i];
                final progress = asNum(c['progress']).toDouble();
                final target = asNum(c['target']).toDouble();
                final ratio = (progress / target).clamp(0.0, 1.0);
                final completed = c['completed'] == true;
                final claimed = c['claimed'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c['label'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                          Text(_scopeLabels[c['scope']] ?? c['scope'] as String? ?? '', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: ratio, backgroundColor: AppColors.surface3, color: AppColors.primary, minHeight: 6),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${c['progress']}/${c['target']} · ${c['reward']} coins', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                          if (claimed)
                            const Text('Claimed', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600))
                          else
                            ElevatedButton(
                              onPressed: (!completed || _claiming == c['key']) ? null : () => _claim(c['key'] as String),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                              child: Text(_claiming == c['key'] ? 'Claiming…' : 'Claim', style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
