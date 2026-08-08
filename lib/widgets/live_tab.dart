import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';
import '../screens/party/party_screen.dart';
import 'avatar.dart';
import 'spinner.dart';

/// Live-rooms tab — Dart port of LiveTab.jsx. Lists active 'live' rooms
/// (real camera broadcasts) and lets the current user start their own.
class LiveTab extends StatefulWidget {
  const LiveTab({super.key});

  @override
  State<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<LiveTab> {
  bool _loading = true;
  bool _starting = false;
  List<Map<String, dynamic>> _liveRooms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/rooms/browse') as List;
      final rooms = data.cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _liveRooms = rooms.where((r) => r['roomType'] == 'live' && (r['memberCount'] as int? ?? 0) > 0).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goLive() async {
    setState(() => _starting = true);
    try {
      final room = await ApiClient.post('/rooms', body: {'title': 'Live now', 'roomType': 'live', 'visibility': 'public'}) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: room['id'] as String))).then((_) => _load());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start a live broadcast')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _starting ? null : _goLive,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(_starting ? 'Starting…' : '🔴 Go Live'),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Spinner()))
        else if (_liveRooms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text("Nobody's live right now.\nStart your own broadcast, or check back later.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint))),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: _liveRooms.map((room) {
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: room['id'] as String))).then((_) => _load()),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.danger, AppColors.primary]))),
                      Center(child: Avatar(name: room['hostName'] as String?, size: AvatarSize.lg)),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(999)),
                          child: const Text('🔴 LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(room['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('${room['hostName']} · ${room['memberCount']} watching', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
