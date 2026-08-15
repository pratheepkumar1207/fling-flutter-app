import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../party/party_screen.dart';
import 'source_picker_screen.dart';

class LobbyCreateScreen extends StatefulWidget {
  const LobbyCreateScreen({super.key});

  @override
  State<LobbyCreateScreen> createState() => _LobbyCreateScreenState();
}

class _RoomTypeSpec {
  final String value;
  final String emoji;
  final String label;
  final String description;
  final Color color;
  // 3D room-type icon shipped by design — falls back to [emoji] wherever a
  // matching asset hasn't been provided yet (see assets/icons/rooms/).
  final String? iconAsset;
  const _RoomTypeSpec(this.value, this.emoji, this.label, this.description, this.color, {this.iconAsset});
}

class _VisibilitySpec {
  final String value;
  final IconData icon;
  final String label;
  final String description;
  final String? iconAsset;
  const _VisibilitySpec(this.value, this.icon, this.label, this.description, {this.iconAsset});
}

const _roomTypes = [
  _RoomTypeSpec('watch', '📺', 'Watch Party', 'Watch videos together', Color(0xFFEC4899), iconAsset: 'assets/icons/rooms/watch_party.png'),
  _RoomTypeSpec('game', '🎮', 'Game Room', 'Play games with friends', Color(0xFF6366F1), iconAsset: 'assets/icons/rooms/game_lobby.png'),
  _RoomTypeSpec('voice', '🎙️', 'Voice Room', 'Talk and hang out', Color(0xFF34D399), iconAsset: 'assets/icons/rooms/voice_lobby.png'),
];

const _visibilities = [
  _VisibilitySpec('public', Icons.public_rounded, 'Public', 'Anyone can discover and join', iconAsset: 'assets/icons/rooms/public_room.png'),
  _VisibilitySpec('private', Icons.lock_rounded, 'Private', 'Only people with a link can join', iconAsset: 'assets/icons/rooms/private_room.png'),
  _VisibilitySpec('friends', Icons.group_rounded, 'Friends Only', 'Only your friends can join', iconAsset: 'assets/icons/rooms/friends_room.png'),
  _VisibilitySpec('subscribers', Icons.star_rounded, 'Followers Only', 'Only people who follow you can join'),
];

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Text('Create a Room', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Host a room and vibe together ✨', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(height: 24),
            _sectionLabel('1. Select Room Type'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: _roomTypes.map(_typeCard).toList(),
            ),
            if (_roomType == 'game') ...[
              const SizedBox(height: 20),
              _sectionLabel('1A. Choose a Game'),
              const SizedBox(height: 10),
              Column(
                children: [
                  _gameTypeButton('tictactoe', '⭕', 'Tic Tac Toe', available: true),
                  const SizedBox(height: 8),
                  _gameTypeButton('truth_or_dare', '🎲', 'Truth or Dare', available: true, iconAsset: 'assets/icons/rooms/truth_or_dare.png'),
                  const SizedBox(height: 8),
                  _gameTypeButton('ludo', '🟢', 'Ludo', available: true, iconAsset: 'assets/icons/rooms/ludo.png'),
                  const SizedBox(height: 8),
                  _gameTypeButton('chess', '♞', 'Chess', available: true, iconAsset: 'assets/icons/rooms/chess.png'),
                  const SizedBox(height: 8),
                  _gameTypeButton('uno', '🃏', 'UNO', available: true, iconAsset: 'assets/icons/rooms/uno.png'),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _sectionLabel('2. Room Mode'),
            const SizedBox(height: 4),
            const Text('Choose who can join your room', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            const SizedBox(height: 10),
            Column(children: _visibilities.map(_visibilityCard).toList()),
            const SizedBox(height: 20),
            _sectionLabel('3. Room Details'),
            const SizedBox(height: 10),
            _pillField(_nameController, 'Room Name (optional)'),
            const SizedBox(height: 10),
            _pillField(_topicController, 'Add a description (optional)'),
            const SizedBox(height: 20),
            // Watch parties skip the button below entirely — picking a video in
            // the Rave-style source picker creates the room automatically (see
            // watch_room_creator.dart), so there's nothing left to confirm here.
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(gradient: AppGradients.volaCtaDiagonal, borderRadius: BorderRadius.circular(999)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _roomType == 'watch' ? _openSourcePicker : (_saving ? null : _create),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          _roomType == 'watch' ? 'Choose what to watch' : (_saving ? 'Creating…' : 'Create Room'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700));

  Widget _typeCard(_RoomTypeSpec spec) {
    final selected = _roomType == spec.value;
    return GestureDetector(
      onTap: () => setState(() => _roomType = spec.value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: spec.color.withValues(alpha: 0.18), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: spec.iconAsset != null
                  ? Image.asset(spec.iconAsset!, width: 30, height: 30)
                  : Text(spec.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 8),
            Text(spec.label, style: TextStyle(color: selected ? AppColors.primary : AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(spec.description, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textFaint, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _visibilityCard(_VisibilitySpec spec) {
    final selected = _visibility == spec.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _visibility = spec.value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              spec.iconAsset != null
                  ? Image.asset(spec.iconAsset!, width: 22, height: 22)
                  : Icon(spec.icon, color: selected ? AppColors.primary : AppColors.textDim, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.label, style: TextStyle(color: selected ? AppColors.primary : AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(spec.description, style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 2),
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: selected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameTypeButton(String value, String emoji, String label, {required bool available, String? iconAsset}) {
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
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  iconAsset != null ? Image.asset(iconAsset, width: 24, height: 24) : Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              if (!available) const Text('Coming soon', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }
}
