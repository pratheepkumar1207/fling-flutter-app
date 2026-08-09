import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';

const _kGameTypes = [
  ['tictactoe', '⭕ Tic Tac Toe'],
  ['truth_or_dare', '🎲 Truth or Dare'],
  ['ludo', '🟢 Ludo'],
  ['chess', '♞ Chess'],
];

/// Host-only: switch an already-created room between watch/voice/game
/// without everyone having to leave and start a new one — see PATCH
/// /rooms/:id/type on the backend. "Go live" isn't offered here since going
/// live is an action (start broadcasting), not just a field flip.
Future<void> showRoomSettingsSheet(BuildContext context, {required Map<String, dynamic> room, required VoidCallback onChanged}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RoomSettingsSheet(room: room, onChanged: onChanged),
  );
}

class _RoomSettingsSheet extends StatefulWidget {
  final Map<String, dynamic> room;
  final VoidCallback onChanged;
  const _RoomSettingsSheet({required this.room, required this.onChanged});

  @override
  State<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends State<_RoomSettingsSheet> {
  late String _roomType = widget.room['roomType'] == 'live' ? 'watch' : (widget.room['roomType'] as String? ?? 'watch');
  late String _gameType = widget.room['gameType'] as String? ?? 'tictactoe';
  late final _urlController = TextEditingController(text: widget.room['videoUrl'] as String? ?? '');
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _pinned = {'title': 'Current video'};
  bool _searching = false;
  bool _saving = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final data = await ApiClient.get('/youtube/search?q=${Uri.encodeQueryComponent(q.trim())}');
      if (mounted) setState(() => _results = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pin(Map<String, dynamic> item) {
    setState(() {
      _pinned = item;
      _urlController.text = 'https://www.youtube.com/watch?v=${item['videoId']}';
      _results = [];
    });
  }

  Future<void> _save() async {
    if (_roomType == 'watch' && _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search and pick a video first')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/rooms/${widget.room['id']}/type', body: {
        'roomType': _roomType,
        'sourceType': _roomType == 'watch' ? 'youtube' : null,
        'videoUrl': _roomType == 'watch' ? _urlController.text.trim() : null,
        'gameType': _roomType == 'game' ? _gameType : null,
      });
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room updated')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999))),
              ),
              const Text('Room settings', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final t in [['watch', '📺 Watch'], ['voice', '🎙️ Voice'], ['game', '🎮 Game']])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setState(() => _roomType = t[0]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _roomType == t[0] ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _roomType == t[0] ? AppColors.primary : AppColors.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(t[1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _roomType == t[0] ? AppColors.primary : AppColors.textDim)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_roomType == 'game') ...[
                const SizedBox(height: 14),
                for (final g in _kGameTypes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _gameType = g[0]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _gameType == g[0] ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _gameType == g[0] ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(g[1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _gameType == g[0] ? AppColors.primary : AppColors.textDim)),
                      ),
                    ),
                  ),
              ],
              if (_roomType == 'watch') ...[
                const SizedBox(height: 14),
                if (_pinned != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        Expanded(child: Text(_pinned!['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 13))),
                        TextButton(
                          onPressed: () => setState(() {
                            _pinned = null;
                            _urlController.clear();
                          }),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextField(
                    onChanged: _search,
                    decoration: const InputDecoration(hintText: 'Search YouTube for a video…'),
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                  if (_searching) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                  if (_results.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(r['thumbnail'] as String? ?? '', width: 56, height: 40, fit: BoxFit.cover)),
                            title: Text(r['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 12)),
                            onTap: () => _pin(r),
                          );
                        },
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
