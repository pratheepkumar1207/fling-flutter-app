import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/countdown_badge.dart';
import '../../widgets/member_avatar_strip.dart';
import '../../widgets/spinner.dart';
import '../party/party_screen.dart';
import 'lobby_create_screen.dart';

class LobbyJoinScreen extends StatefulWidget {
  const LobbyJoinScreen({super.key});

  @override
  State<LobbyJoinScreen> createState() => _LobbyJoinScreenState();
}

class _LobbyJoinScreenState extends State<LobbyJoinScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _scheduledEvents = [];
  final _roomIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiClient.get('/rooms/browse').catchError((_) => []),
      ApiClient.get('/rooms/events').catchError((_) => []),
    ]);
    if (!mounted) return;
    setState(() {
      _rooms = ((results[0] as List?) ?? []).cast<Map<String, dynamic>>().where((r) => (r['memberCount'] as num? ?? 0) > 0).toList();
      _scheduledEvents = ((results[1] as List?) ?? []).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  void _joinById() {
    final id = _roomIdController.text.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: id)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Rooms', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyCreateScreen())).then((_) => _load()),
                child: const Text('+ Start'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomIdController,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(hintText: 'Have a room ID or link?'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _joinById, child: const Text('Join')),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Spinner()))
          else if (_rooms.isEmpty && _scheduledEvents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('No live rooms.\nStart your own, or check back once one is scheduled.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint)),
              ),
            )
          else ...[
            ..._rooms.map((room) {
              final thumbnail = room['nowPlayingThumbnail'] as String?;
              final members = room['members'] as List?;
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: room['id'] as String))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 96,
                        child: (thumbnail != null && thumbnail.isNotEmpty)
                            ? AppImage(source: thumbnail, fit: BoxFit.cover)
                            : Container(
                                color: AppColors.surface3,
                                alignment: Alignment.center,
                                child: Text(room['roomType'] == 'voice' ? '🎙️' : '📺', style: const TextStyle(fontSize: 20)),
                              ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(room['title'] as String? ?? 'Untitled room', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                              Text('${room['hostName'] ?? ''} · ${room['memberCount'] ?? 0} watching', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                              if (members != null && members.isNotEmpty) MemberAvatarStrip(members: members),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            ..._scheduledEvents.map((ev) {
              final scheduledAt = DateTime.tryParse(ev['scheduledAt'] as String? ?? '');
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: ev['id'] as String))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text(ev['roomType'] == 'voice' ? '🎙️' : '📺', style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ev['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                            Text(ev['hostName'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (scheduledAt != null) CountdownBadge(scheduledAt: scheduledAt),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }
}
