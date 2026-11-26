import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/spinner.dart';
import '../messages/message_thread_screen.dart';
import '../party/party_screen.dart';
import 'discover_ui.dart';
import 'peek_card.dart';

/// Your matches (GET /swipe/matches): the newest along the top, then
/// everyone, with Join when they're in a lobby you can see.
class DiscoverMatchesScreen extends StatefulWidget {
  const DiscoverMatchesScreen({super.key});

  @override
  State<DiscoverMatchesScreen> createState() => _DiscoverMatchesScreenState();
}

class _DiscoverMatchesScreenState extends State<DiscoverMatchesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _matches = [];
  bool _searching = false;
  String _q = '';

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
        _matches = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _chat(Map m) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MessageThreadScreen(
          userId: m['userId'] as String,
          name: '${m['name']}',
          avatarUrl: m['avatarUrl'] as String?)));

  String _when(DateTime? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return 'Matched just now';
    if (d.inHours < 24) return 'Matched today';
    if (d.inDays == 1) return 'Matched yesterday';
    if (d.inDays < 30) return 'Matched ${d.inDays} days ago';
    return 'Matched a while ago';
  }

  @override
  Widget build(BuildContext context) {
    final list = _q.isEmpty
        ? _matches
        : _matches
            .where(
                (m) => '${m['name']}'.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    final fresh = _matches
        .where((m) =>
            DateTime.tryParse('${m['matchedAt']}')
                ?.isAfter(DateTime.now().subtract(const Duration(days: 7))) ??
            false)
        .toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const InIcon(InIcons.back, color: Colors.white)),
        title: _searching
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                    hintText: 'Search matches', border: InputBorder.none),
              )
            : const Text('Matches'),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _q = '';
            }),
            icon: InIcon(_searching ? InIcons.close : InIcons.search,
                color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: Spinner())
          : _matches.isEmpty
              ? const Center(
                  child: Text('No matches yet.\nKeep swiping in Discover.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textFaint)))
              : RefreshIndicator(
                  color: DColors.red,
                  onRefresh: _load,
                  child: ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        if (fresh.isNotEmpty && _q.isEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                            child: Text('New',
                                style: TextStyle(
                                    color: DColors.dim,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                          SizedBox(
                            height: 86,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: fresh.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final m = fresh[i];
                                return GestureDetector(
                                  onTap: () => _chat(m),
                                  onLongPress: () => showPeekCard(
                                      context, m['userId'] as String),
                                  child: Column(children: [
                                    PersonFace(
                                        avatarUrl: m['avatarUrl'] as String?,
                                        name: '${m['name']}',
                                        size: 56,
                                        ring: RingKind.lobby,
                                        online: m['online'] == true),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 64,
                                      child: Text(
                                          '${m['name']}'.split(' ').first,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                  ]),
                                );
                              },
                            ),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('All matches',
                              style: TextStyle(
                                  color: DColors.dim,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        for (final m in list) _row(m),
                      ]),
                ),
    );
  }

  Widget _row(Map<String, dynamic> m) {
    final room = m['activeRoom'] as Map?;
    final age = m['age'];
    return InkWell(
      onTap: () => _chat(m),
      onLongPress: () => showPeekCard(context, m['userId'] as String),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1C1C1C)))),
        child: Row(children: [
          PersonFace(
            avatarUrl: m['avatarUrl'] as String?,
            name: '${m['name']}',
            size: 44,
            ring: room != null ? RingKind.lobby : RingKind.close,
            online: m['online'] == true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text:
                          age != null ? '${m['name']}, $age' : '${m['name']}'),
                  if (room != null)
                    const TextSpan(
                        text: '  in a lobby',
                        style: TextStyle(color: DColors.redSoft, fontSize: 12)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                  room != null && room['title'] != null
                      ? '${room['title']}'
                      : m['online'] == true
                          ? 'Active now'
                          : _when(DateTime.tryParse('${m['matchedAt']}')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DColors.dim, fontSize: 12)),
            ]),
          ),
          if (room?['roomId'] != null)
            DChip('Join',
                tone: DTone.outline,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        PartyScreen(roomId: room!['roomId'] as String)))),
        ]),
      ),
    );
  }
}
