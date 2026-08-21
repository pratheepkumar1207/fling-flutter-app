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
  _RoomTypeSpec('watch', '📺', 'Watch Party', 'Watch videos together', Color(0xFFEC4899), iconAsset: 'assets/icons/app/watchparty.png'),
  _RoomTypeSpec('game', '🎮', 'Game Room', 'Play games with friends', Color(0xFF6366F1), iconAsset: 'assets/icons/app/gaming.png'),
  _RoomTypeSpec('voice', '🎙️', 'Voice Room', 'Talk and hang out', Color(0xFF34D399), iconAsset: 'assets/icons/app/voice_room.png'),
];

const _visibilities = [
  _VisibilitySpec('public', Icons.public_rounded, 'Public', 'Anyone can discover and join', iconAsset: 'assets/icons/app/public.png'),
  _VisibilitySpec('private', Icons.lock_rounded, 'Private', 'Only people with a link can join', iconAsset: 'assets/icons/rooms/private_room.png'),
  _VisibilitySpec('friends', Icons.group_rounded, 'Friends Only', 'Only your friends can join', iconAsset: 'assets/icons/app/friends_only.png'),
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
  // Matches RoomSetupDark.dc.html's two toggles — only applied for
  // game/voice rooms, which create directly through _create() below. Watch
  // rooms go through the separate source-picker flow (SourcePickerScreen /
  // watch_room_creator.dart) instead, which doesn't thread these through;
  // a watch host can still set them afterward via Room Settings, same as
  // today.
  bool _micEnabled = true;
  bool _songPermission = true;
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
      final roomId = room['id'] as String;
      await ApiClient.patch('/rooms/$roomId/settings', body: {
        'micEnabled': _micEnabled,
        'songPermission': _songPermission ? 'anyone' : 'host',
      }).catchError((_) => null);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
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
            const Text('Create a room', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _sectionLabel('1. Select Room Type'),
            const SizedBox(height: 10),
            // Exactly 3 room types — a single 1x3 row instead of a wrapping
            // grid, matching the reference layout.
            Row(
              children: [
                for (var i = 0; i < _roomTypes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _typeCard(_roomTypes[i])),
                ],
              ],
            ),
            if (_roomType == 'game') ...[
              const SizedBox(height: 20),
              _sectionLabel('1A. Choose a Game'),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _gameTypeTile('tictactoe', '⭕', 'Tic Tac Toe', available: true, iconAsset: 'assets/icons/app/tic_tac_toe.png'),
                    _gameTypeTile('truth_or_dare', '🎲', 'Truth or Dare', available: true, iconAsset: 'assets/icons/app/truth_or_dare.png'),
                    _gameTypeTile('ludo', '🟢', 'Ludo', available: true, iconAsset: 'assets/icons/app/ludo.png'),
                    _gameTypeTile('chess', '♞', 'Chess', available: true, iconAsset: 'assets/icons/app/chess.png'),
                    _gameTypeTile('uno', '🃏', 'UNO', available: true, iconAsset: 'assets/icons/app/uno.png'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _sectionLabel('2. Who can join'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: _visibilities.map(_visibilityPill).toList()),
            if (_roomType != 'game') ...[
              const SizedBox(height: 20),
              _toggleRow('Mics enabled', _micEnabled, (v) => setState(() => _micEnabled = v)),
              _toggleRow('Anyone can add songs', _songPermission, (v) => setState(() => _songPermission = v)),
            ],
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The icon assets are already complete illustrations on their
            // own — no tinted circle backdrop behind them.
            spec.iconAsset != null
                ? Image.asset(spec.iconAsset!, width: 56, height: 56, fit: BoxFit.contain)
                : SizedBox(
                    width: 56,
                    height: 56,
                    child: Center(child: Text(spec.emoji, style: const TextStyle(fontSize: 22))),
                  ),
            const SizedBox(height: 6),
            // Icon-only per design — the description alone is enough, no
            // separate title label under it.
            Text(
              spec.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected ? AppColors.primary : AppColors.textFaint, fontSize: 10, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  // Compact pill row — matches RoomSetupDark.dc.html's "Who can join"
  // section exactly (the previous vertical description-cards were a
  // pre-existing embellishment, not from the mockup).
  Widget _visibilityPill(_VisibilitySpec spec) {
    final selected = _visibility == spec.value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = spec.value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
          border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Text(spec.label, style: TextStyle(color: selected ? AppColors.accent : AppColors.textDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 13.5))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 20,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: value ? const LinearGradient(colors: AppGradients.brand) : null,
                color: value ? null : AppColors.surface2,
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameTypeTile(String value, String emoji, String label, {required bool available, String? iconAsset}) {
    final selected = _gameType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: available ? () => setState(() => _gameType = value) : null,
        child: Opacity(
          opacity: available ? 1 : 0.4,
          child: Container(
            width: 110,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconAsset != null ? Image.asset(iconAsset, width: 72, height: 72) : Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(
                  available ? label : 'Soon',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: selected ? AppColors.primary : AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
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
