import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/glass.dart';
import 'app_image.dart';

const _kGameTypes = [
  ['tictactoe', '⭕ Tic Tac Toe'],
  ['truth_or_dare', '🎲 Truth or Dare'],
  ['ludo', '🟢 Ludo'],
  ['chess', '♞ Chess'],
  ['uno', '🃏 UNO'],
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
  // Only shows the "Current video" placeholder when the room is actually
  // already a watch room with a video — a room entering 'watch' fresh from
  // voice/game has nothing to keep, so it goes straight to search instead
  // of showing a misleading placeholder for content that doesn't exist.
  late Map<String, dynamic>? _pinned =
      (widget.room['roomType'] == 'watch' && widget.room['videoUrl'] != null) ? {'title': 'Current video'} : null;
  // True only once the host actually picks a *new* video via search — see
  // _save(): staying false means "don't touch sourceType/videoUrl at all",
  // which is what lets saving unrelated settings (mic, visibility, ...) on
  // a Drive/streaming-platform room stop silently overwriting it to
  // sourceType 'youtube' with the old video's URL.
  bool _videoChanged = false;
  bool _searching = false;
  bool _saving = false;

  late String _visibility = widget.room['visibility'] == 'subscribers' ? 'public' : (widget.room['visibility'] as String? ?? 'public');
  late bool _micEnabled = widget.room['micEnabled'] != false;
  late String _songPermission = widget.room['songPermission'] as String? ?? 'anyone';
  late bool _autoPlay = widget.room['autoPlay'] != false;
  late String _pinPermission = widget.room['pinPermission'] as String? ?? 'host';
  // Voice-room cover shown in the Lobby list — null keeps the client's
  // default mic-icon tile. Only meaningful/host-editable for voice rooms;
  // watch parties derive their thumbnail from the picked video instead.
  late String? _thumbnail = widget.room['thumbnail'] as String?;
  bool _thumbnailChanged = false;

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    setState(() {
      _thumbnail = 'data:image/$ext;base64,${base64Encode(bytes)}';
      _thumbnailChanged = true;
    });
  }

  void _clearThumbnail() {
    setState(() {
      _thumbnail = null;
      _thumbnailChanged = true;
    });
  }

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
      _videoChanged = true;
      _urlController.text = 'https://www.youtube.com/watch?v=${item['videoId']}';
      _results = [];
    });
  }

  // Entering 'watch' from a room type that had no video needs a fresh
  // pick; staying in 'watch' with the existing video kept (_pinned still
  // set, nothing re-picked) doesn't.
  bool get _enteringWatchFresh => _roomType == 'watch' && widget.room['roomType'] != 'watch';

  Future<void> _save() async {
    if (_roomType == 'watch' && _pinned == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search and pick a video first')));
      return;
    }
    setState(() => _saving = true);
    try {
      final sendVideo = _roomType == 'watch' && (_videoChanged || _enteringWatchFresh);
      await ApiClient.patch('/rooms/${widget.room['id']}/type', body: {
        'roomType': _roomType,
        if (sendVideo) 'sourceType': 'youtube',
        if (sendVideo) 'videoUrl': _urlController.text.trim(),
        if (sendVideo) 'videoTitle': _pinned?['title'],
        if (sendVideo) 'videoThumbnail': _pinned?['thumbnail'],
        'gameType': _roomType == 'game' ? _gameType : null,
      });
      await ApiClient.patch('/rooms/${widget.room['id']}/settings', body: {
        'visibility': _visibility,
        'micEnabled': _micEnabled,
        'songPermission': _songPermission,
        'autoPlay': _autoPlay,
        'pinPermission': _pinPermission,
        if (_roomType == 'voice' && _thumbnailChanged) 'thumbnail': _thumbnail,
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

  Widget _optionRow({required List<List<String>> options, required String value, required ValueChanged<String> onChanged}) {
    return Row(
      children: [
        for (final o in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => onChanged(o[0]),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == o[0] ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: value == o[0] ? AppColors.primary : AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(o[1], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: value == o[0] ? AppColors.primary : AppColors.textDim)),
                ),
              ),
            ),
          ),
      ],
    );
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
              if (_roomType == 'voice') ...[
                const SizedBox(height: 14),
                const Text('ROOM COVER', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: (_thumbnail != null && _thumbnail!.isNotEmpty)
                            ? AppImage(source: _thumbnail, fit: BoxFit.cover)
                            : Container(
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: const Text('🎙️', style: TextStyle(fontSize: 22)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton(onPressed: _pickThumbnail, child: const Text('Change cover')),
                          if (_thumbnail != null && _thumbnail!.isNotEmpty)
                            TextButton(onPressed: _clearThumbnail, child: const Text('Use default')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              const Text('LOBBY VISIBILITY', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _optionRow(
                options: const [['public', 'Public'], ['friends', 'Friends only'], ['private', 'Private']],
                value: _visibility,
                onChanged: (v) => setState(() => _visibility = v),
              ),
              const SizedBox(height: 14),
              const Text('MIC', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _optionRow(
                options: const [['on', 'Enabled for all'], ['off', 'Disabled for all']],
                value: _micEnabled ? 'on' : 'off',
                onChanged: (v) => setState(() => _micEnabled = v == 'on'),
              ),
              const SizedBox(height: 14),
              const Text('WHO CAN ADD SONGS', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _optionRow(
                options: const [['anyone', 'Anyone'], ['host', "Leader's choice only"]],
                value: _songPermission,
                onChanged: (v) => setState(() => _songPermission = v),
              ),
              const SizedBox(height: 14),
              const Text('WHO CAN PIN A SONG TO PLAY NOW', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _optionRow(
                options: const [['host', 'Host only'], ['anyone', 'Anyone can pin']],
                value: _pinPermission,
                onChanged: (v) => setState(() => _pinPermission = v),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Auto-play next song', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
                    Switch(value: _autoPlay, onChanged: (v) => setState(() => _autoPlay = v), activeThumbColor: AppColors.primary),
                  ],
                ),
              ),
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
