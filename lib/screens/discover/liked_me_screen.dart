import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/spinner.dart';
import '../messages/message_thread_screen.dart';
import '../wallet/vip_store_screen.dart';

/// People who liked you (GET /swipe/likes). VIPs see everyone and can like
/// back to match; others see the first two and a blurred rest.
class LikedMeScreen extends StatefulWidget {
  const LikedMeScreen({super.key});

  @override
  State<LikedMeScreen> createState() => _LikedMeScreenState();
}

class _LikedMeScreenState extends State<LikedMeScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiClient.get('/swipe/likes') as Map;
      if (mounted) setState(() => _data = Map<String, dynamic>.from(d));
    } catch (_) {
      if (mounted) setState(() => _data = {'count': 0, 'people': []});
    }
  }

  Future<void> _likeBack(Map<String, dynamic> p) async {
    try {
      final r = await ApiClient.post('/swipe',
          body: {'toUserId': p['id'], 'action': 'like'}) as Map;
      if (!mounted) return;
      if (r['matched'] == true || r['match'] != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MessageThreadScreen(
                userId: p['id'] as String,
                name: p['name'] as String? ?? '',
                avatarUrl: p['avatarUrl'] as String?)));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('You liked ${p['name']}')));
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final people = ((d?['people'] as List?) ?? const []).cast<Map>();
    final vip = d?['vip'] == true;
    final count = (d?['count'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: InIconButton(InIcons.back,
            tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Likes you'),
      ),
      body: d == null
          ? const Center(child: Spinner())
          : count == 0
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'No likes yet. Keep swiping in Discover — people who like you show up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textDim)),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text(
                      count == 1
                          ? '1 person likes you'
                          : '$count people like you',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  if (!vip) ...[
                    const SizedBox(height: 4),
                    const Text('Go VIP to see everyone and match instantly',
                        style: TextStyle(color: AppColors.textDim)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => const VipStoreScreen()))
                          .then((_) => _load()),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.bg,
                          minimumSize: const Size.fromHeight(48)),
                      icon: const InIcon(InIcons.crown,
                          size: 18, color: AppColors.bg),
                      label: const Text('Go VIP',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.78,
                    children: [
                      for (final raw in people)
                        _LikeCard(
                          p: Map<String, dynamic>.from(raw),
                          onLikeBack: _likeBack,
                        ),
                    ],
                  ),
                ]),
    );
  }
}

class _LikeCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final Future<void> Function(Map<String, dynamic>) onLikeBack;
  const _LikeCard({required this.p, required this.onLikeBack});

  @override
  Widget build(BuildContext context) {
    final hidden = p['hidden'] == true;
    final age = p['age'];
    final label = hidden
        ? '••••${age == null ? '' : ', $age'}'
        : '${(p['name'] as String? ?? '').split(' ').first}${age == null ? '' : ', $age'}';
    Widget face = Avatar(
        src: hidden ? null : p['avatarUrl'] as String?,
        name: hidden ? '?' : p['name'] as String?,
        size: AvatarSize.lg);
    if (hidden) {
      face = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: face);
    }
    return Semantics(
      label: hidden ? 'Hidden like. Go VIP to see who.' : 'Liked by $label',
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: p['superlike'] == true
                    ? AppColors.blue
                    : AppColors.border)),
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          face,
          const SizedBox(height: 10),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (p['superlike'] == true)
            const Text('Super like',
                style: TextStyle(color: AppColors.blue, fontSize: 12)),
          const SizedBox(height: 8),
          if (!hidden)
            FilledButton(
              onPressed: () => onLikeBack(p),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  backgroundColor: AppColors.pink),
              child: const Text('Like back'),
            ),
        ]),
      ),
    );
  }
}
