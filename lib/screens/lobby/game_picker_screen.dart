import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../party/party_screen.dart';

const _kGames = [
  (
    value: 'chess',
    icon: Icons.shield_rounded,
    label: 'Chess',
    subtitle: '1 vs 1 · classic',
    colors: [Color(0xFF7FA8D9), Color(0xFF4272D9)]
  ),
  (
    value: 'ludo',
    icon: Icons.grid_view_rounded,
    label: 'Ludo',
    subtitle: '2–4 players',
    colors: [Color(0xFF6ED9A0), Color(0xFF2E9B5F)]
  ),
  (
    value: 'tictactoe',
    icon: Icons.apps_rounded,
    label: 'Tic Tac Toe',
    subtitle: '1 vs 1 · quick',
    colors: [Color(0xFFE0836B), Color(0xFFB8422C)]
  ),
  (
    value: 'uno',
    icon: Icons.style_rounded,
    label: 'UNO',
    subtitle: '2–6 players',
    colors: [Color(0xFFDBB155), Color(0xFFB98A3D)]
  ),
  (
    value: 'truth_or_dare',
    icon: Icons.mood_rounded,
    label: 'Truth or Dare',
    subtitle: 'Group · party',
    colors: [Color(0xFFE0836B), Color(0xFFB8422C)]
  ),
];

/// Matches GamePickerDark.dc.html: a dedicated "Choose a game" screen with
/// radio-selectable game cards and a "Create room" CTA. A quick-create
/// path — creates a public game room with no custom title/topic, same as
/// the mockup shows no fields for either. LobbyCreateScreen's full form
/// (name/topic/visibility) is still there for anyone who wants those set
/// at creation; this is the fast path, and visibility can always be
/// changed afterward via Room Settings.
class GamePickerScreen extends StatefulWidget {
  const GamePickerScreen({super.key});

  @override
  State<GamePickerScreen> createState() => _GamePickerScreenState();
}

class _GamePickerScreenState extends State<GamePickerScreen> {
  String _selected = _kGames.first.value;
  bool _creating = false;

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final room = await ApiClient.post('/rooms', body: {
        'roomType': 'game',
        'gameType': _selected,
        'visibility': 'public',
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _creating = false);
    } catch (_) {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Choose a game')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              children: [
                for (final game in _kGames) _card(game),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
            child: GestureDetector(
              onTap: _creating ? null : _create,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: _creating
                      ? null
                      : const LinearGradient(colors: AppGradients.brand),
                  color: _creating ? AppColors.surface2 : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _creating ? 'Creating…' : 'Create room',
                  style: TextStyle(
                      color: _creating ? AppColors.textFaint : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
      ({
        String value,
        IconData icon,
        String label,
        String subtitle,
        List<Color> colors
      }) game) {
    final selected = _selected == game.value;
    return GestureDetector(
      onTap: () => setState(() => _selected = game.value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.accent2 : AppColors.border,
              width: 1.5),
          color: selected
              ? AppColors.accent2.withValues(alpha: 0.1)
              : AppColors.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: game.colors)),
              alignment: Alignment.center,
              child: Icon(game.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.label,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(game.subtitle,
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: 11.5)),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent2 : null,
                border: selected
                    ? null
                    : Border.all(color: AppColors.border, width: 2),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
