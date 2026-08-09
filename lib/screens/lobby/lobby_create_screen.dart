import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_image.dart';
import '../../widgets/spinner.dart';
import '../party/party_screen.dart';

class LobbyCreateScreen extends StatefulWidget {
  const LobbyCreateScreen({super.key});

  @override
  State<LobbyCreateScreen> createState() => _LobbyCreateScreenState();
}

class _LobbyCreateScreenState extends State<LobbyCreateScreen> {
  String _roomType = 'watch';
  String _gameType = 'tictactoe';
  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  String _visibility = 'public';
  String _sourceType = 'youtube';
  final _driveUrlController = TextEditingController();
  Map<String, dynamic>? _pinnedVideo;
  bool _saving = false;

  final _ytQueryController = TextEditingController();
  Timer? _debounce;
  bool _ytSearching = false;
  List<Map<String, dynamic>> _ytResults = [];

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _ytResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _ytSearching = true);
    try {
      final data = await ApiClient.get('/youtube/search?q=${Uri.encodeQueryComponent(q)}');
      if (!mounted) return;
      setState(() => _ytResults = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _ytResults = []);
    } finally {
      if (mounted) setState(() => _ytSearching = false);
    }
  }

  void _pinVideo(Map<String, dynamic> item) {
    setState(() {
      _pinnedVideo = item;
      _ytQueryController.clear();
      _ytResults = [];
    });
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_roomType == 'watch' && _sourceType == 'youtube' && _pinnedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search and pin a video first')));
      return;
    }
    setState(() => _saving = true);
    try {
      final videoUrl = _roomType == 'watch'
          ? (_sourceType == 'youtube' ? 'https://www.youtube.com/watch?v=${_pinnedVideo!['videoId']}' : _driveUrlController.text.trim())
          : null;
      final room = await ApiClient.post('/rooms', body: {
        'title': _titleController.text.trim(),
        'roomType': _roomType,
        if (_roomType == 'watch') 'sourceType': _sourceType,
        if (_roomType == 'watch') 'videoUrl': videoUrl,
        if (_roomType == 'game') 'gameType': _gameType,
        'visibility': _visibility,
        if (_topicController.text.trim().isNotEmpty) 'topic': _topicController.text.trim(),
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Start a room')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _typeButton('watch', '📺 Watch party')),
              const SizedBox(width: 8),
              Expanded(child: _typeButton('voice', '🎙️ Voice room')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _typeButton('live', '🔴 Go live')),
              const SizedBox(width: 8),
              Expanded(child: _typeButton('game', '🎮 Game room')),
            ],
          ),
          if (_roomType == 'game') ...[
            const SizedBox(height: 12),
            _field(
              'Which game?',
              Column(
                children: [
                  _gameTypeButton('tictactoe', '⭕ Tic Tac Toe', available: true),
                  const SizedBox(height: 8),
                  _gameTypeButton('truth_or_dare', '🎲 Truth or Dare', available: true),
                  const SizedBox(height: 8),
                  _gameTypeButton('ludo', '🟢 Ludo', available: true),
                  const SizedBox(height: 8),
                  _gameTypeButton('chess', '♞ Chess', available: true),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _field('Title', TextField(controller: _titleController, style: const TextStyle(color: AppColors.text))),
          if (_roomType == 'watch') ...[
            const SizedBox(height: 12),
            _field(
              'Source',
              DropdownButton<String>(
                value: _sourceType,
                isExpanded: true,
                dropdownColor: AppColors.surface2,
                items: const [DropdownMenuItem(value: 'youtube', child: Text('YouTube')), DropdownMenuItem(value: 'drive', child: Text('Google Drive'))],
                onChanged: (v) => setState(() {
                  _sourceType = v ?? 'youtube';
                  _pinnedVideo = null;
                }),
              ),
            ),
            const SizedBox(height: 12),
            if (_sourceType == 'youtube')
              _field(
                'Video',
                _pinnedVideo != null
                    ? Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
                              clipBehavior: Clip.antiAlias,
                              child: _pinnedVideo!['thumbnail'] != null ? AppImage(source: _pinnedVideo!['thumbnail'] as String?, fit: BoxFit.cover) : const Center(child: Text('📺')),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_pinnedVideo!['title'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const Text('📌 Pinned', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                                ],
                              ),
                            ),
                            TextButton(onPressed: () => setState(() => _pinnedVideo = null), child: const Text('Change', style: TextStyle(fontSize: 11))),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          TextField(
                            controller: _ytQueryController,
                            onChanged: _onQueryChanged,
                            style: const TextStyle(color: AppColors.text),
                            decoration: const InputDecoration(hintText: 'Search YouTube for a video…'),
                          ),
                          if (_ytSearching) const Padding(padding: EdgeInsets.all(8), child: Spinner(size: 18)),
                          ..._ytResults.map((item) => GestureDetector(
                                onTap: () => _pinVideo(item),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 40,
                                        decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
                                        clipBehavior: Clip.antiAlias,
                                        child: item['thumbnail'] != null ? AppImage(source: item['thumbnail'] as String?, fit: BoxFit.cover) : const Center(child: Text('📺')),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(item['title'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      const Text('📌 Pin', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ),
              )
            else
              _field('Drive file ID / URL', TextField(controller: _driveUrlController, style: const TextStyle(color: AppColors.text))),
          ],
          const SizedBox(height: 12),
          _field('Topic (optional)', TextField(controller: _topicController, style: const TextStyle(color: AppColors.text))),
          const SizedBox(height: 12),
          _field(
            'Visibility',
            DropdownButton<String>(
              value: _visibility,
              isExpanded: true,
              dropdownColor: AppColors.surface2,
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'friends', child: Text('Friends only')),
                DropdownMenuItem(value: 'subscribers', child: Text('Followers only')),
                DropdownMenuItem(value: 'private', child: Text('Private (link only)')),
              ],
              onChanged: (v) => setState(() => _visibility = v ?? 'public'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saving ? null : _create, child: Text(_saving ? 'Creating…' : 'Create room')),
        ],
      ),
    );
  }

  Widget _typeButton(String value, String label) {
    final selected = _roomType == value;
    return GestureDetector(
      onTap: () => setState(() => _roomType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _gameTypeButton(String value, String label, {required bool available}) {
    final selected = _gameType == value;
    return GestureDetector(
      onTap: available ? () => setState(() => _gameType = value) : null,
      child: Opacity(
        opacity: available ? 1 : 0.4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
              if (!available) const Text('Coming soon', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _topicController.dispose();
    _driveUrlController.dispose();
    _ytQueryController.dispose();
    super.dispose();
  }
}
