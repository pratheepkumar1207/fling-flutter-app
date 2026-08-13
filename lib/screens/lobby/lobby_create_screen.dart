import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../party/party_screen.dart';
import 'source_picker_screen.dart';

class LobbyCreateScreen extends StatefulWidget {
  const LobbyCreateScreen({super.key});

  @override
  State<LobbyCreateScreen> createState() => _LobbyCreateScreenState();
}

class _LobbyCreateScreenState extends State<LobbyCreateScreen> {
  String _roomType = 'watch';
  String _gameType = 'tictactoe';
  final _nameController = TextEditingController();
  // Reused as the reference's "Room Description" field — topic already
  // covers exactly that concept server-side, so there's no need for a
  // second, redundant description column.
  final _topicController = TextEditingController();
  String _visibility = 'public';
  bool _saving = false;
  bool _applying = false;

  Future<void> _applyToGoLive() async {
    setState(() => _applying = true);
    try {
      await ApiClient.post('/creators/me/livestream-apply');
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted — you\'ll be notified once reviewed.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final room = await ApiClient.post('/rooms', body: {
        'roomType': _roomType,
        if (_roomType == 'game') 'gameType': _gameType,
        'visibility': _visibility,
        if (_nameController.text.trim().isNotEmpty) 'title': _nameController.text.trim(),
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

  void _openSourcePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SourcePickerScreen(visibility: _visibility, topic: _topicController.text.trim().isEmpty ? null : _topicController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final livestreamStatus = context.watch<AuthProvider>().user?.livestreamStatus ?? 'none';
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
                  const SizedBox(height: 8),
                  _gameTypeButton('uno', '🃏 UNO', available: true),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _field('Room name (optional)', TextField(controller: _nameController, style: const TextStyle(color: AppColors.text))),
          const SizedBox(height: 12),
          _field('Description (optional)', TextField(controller: _topicController, style: const TextStyle(color: AppColors.text))),
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
          if (_roomType == 'live' && livestreamStatus != 'approved') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (livestreamStatus) {
                      'pending' => 'Your application to go live is pending review.',
                      'rejected' => 'Your last application to go live was rejected. You can apply again.',
                      _ => 'Going live needs approval first — apply below.',
                    },
                    style: const TextStyle(color: AppColors.textDim, fontSize: 13),
                  ),
                  if (livestreamStatus != 'pending') ...[
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _applying ? null : _applyToGoLive, child: Text(_applying ? 'Applying…' : 'Apply to go live')),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Watch parties skip the button below entirely — picking a video in
          // the Rave-style source picker creates the room automatically (see
          // watch_room_creator.dart), so there's nothing left to confirm here.
          if (_roomType == 'watch')
            ElevatedButton(onPressed: _openSourcePicker, child: const Text('Choose what to watch'))
          else if (_roomType == 'live' && livestreamStatus != 'approved')
            const SizedBox.shrink()
          else
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
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }
}
