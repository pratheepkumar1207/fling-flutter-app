import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar.dart';
import '../../widgets/spinner.dart';
import '../profile/creator_profile_screen.dart';

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
      appBar: AppBar(title: const Text('Matches')),
      body: _loading
          ? const Center(child: Spinner())
          : _matches.isEmpty
              ? const Center(child: Text('No matches yet.\nKeep swiping in Discover.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
                  itemCount: _matches.length,
                  itemBuilder: (context, i) {
                    final m = _matches[i];
                    final matchedAt = DateTime.tryParse(m['matchedAt']?.toString() ?? '');
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatorProfileScreen(userId: m['userId'] as String))),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Avatar(src: m['avatarUrl'] as String?, name: m['name'] as String?, size: AvatarSize.lg),
                            const SizedBox(height: 8),
                            Text(m['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (matchedAt != null) Text('Matched ${DateFormat.MMMd().format(matchedAt)}', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
