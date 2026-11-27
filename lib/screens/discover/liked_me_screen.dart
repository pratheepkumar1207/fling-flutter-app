import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/app_image.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/spinner.dart';
import '../messages/message_thread_screen.dart';
import '../wallet/vip_store_screen.dart';
import 'discover_sheets.dart';
import 'discover_ui.dart';
import 'peek_card.dart';

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
      if (!mounted) return;
      if (e.status == 429 && e.data is Map) {
        await showOutOfLikesSheet(context, e.data as Map);
      } else {
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
    final locked = people.where((p) => p['hidden'] == true).length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: InIconButton(InIcons.back,
            tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        title: Row(children: [
          const Text('Liked you'),
          if (count > 0) ...[
            const SizedBox(width: 8),
            DChip('$count', tone: DTone.red, fontSize: 12)
          ],
        ]),
      ),
      body: d == null
          ? const Center(child: Spinner())
          : count == 0
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'No likes yet. Keep swiping in Discover. People who like you show up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textDim)),
                  ),
                )
              : Column(children: [
                  Expanded(
                    child: GridView.count(
                      padding: const EdgeInsets.all(14),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.78,
                      children: [
                        for (final raw in people)
                          _LikeCard(
                              p: Map<String, dynamic>.from(raw),
                              onLikeBack: _likeBack),
                      ],
                    ),
                  ),
                  if (!vip && locked > 0)
                    SafeArea(
                      top: false,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: DColors.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: DColors.line),
                        ),
                        child: Column(children: [
                          Text('See all $count who liked you',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          const Text(
                              'Free: the first 2. VIP: everyone, and like back in one tap.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: DColors.dim, fontSize: 12)),
                          const SizedBox(height: 10),
                          DButton('Get VIP',
                              icon: InIcons.crown,
                              kind: DButtonKind.white, onPressed: () {
                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => const VipStoreScreen()))
                                .then((_) => _load());
                          }),
                        ]),
                      ),
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
    final superLike = p['superlike'] == true;
    if (hidden) {
      return Semantics(
        label: 'Hidden like. Get VIP to see who.',
        child: Container(
          decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(16)),
          child: Stack(children: [
            const Center(
                child:
                    InIcon(InIcons.lock, size: 30, color: Color(0xFFFFFFFF))),
            if (age != null)
              Positioned(
                  left: 8, bottom: 8, child: DChip('••••, $age', fontSize: 11)),
            if (superLike)
              const Positioned(
                  right: 8,
                  top: 8,
                  child: DChip('Super like',
                      icon: InIcons.star, tone: DTone.red, fontSize: 11)),
          ]),
        ),
      );
    }
    final name = (p['name'] as String? ?? '').split(' ').first;
    return Semantics(
      label: 'Liked by $name',
      child: GestureDetector(
        onTap: () => showPeekCard(context, p['id'] as String),
        onLongPress: () => showPeekCard(context, p['id'] as String),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            p['avatarUrl'] != null
                ? AppImage(source: p['avatarUrl'] as String, fit: BoxFit.cover)
                : Container(color: DColors.photo),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0xE6000000), Color(0x00000000)]),
              ),
            ),
            if (superLike)
              const Positioned(
                  right: 8,
                  top: 8,
                  child: DChip('Super like',
                      icon: InIcons.star, tone: DTone.red, fontSize: 11)),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(children: [
                Expanded(
                  child: Text(age == null ? name : '$name, $age',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Semantics(
                  button: true,
                  label: 'Like back',
                  child: GestureDetector(
                    onTap: () => onLikeBack(p),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                          color: DColors.red, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const InIcon(InIcons.heart,
                          size: 17, color: Colors.white, filled: true),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
