import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import 'tournament_live.dart';
import 'tournament_screen.dart';

const _purple = Color(0xFF808080);
const _purpleLine = Color(0xFFFFFFFF);

/// New tournament: game, players, start time, who can join. Free to enter;
/// hosting is free with VIP, 200 coins otherwise.
class TournamentCreateScreen extends StatefulWidget {
  const TournamentCreateScreen({super.key});

  @override
  State<TournamentCreateScreen> createState() => _TournamentCreateScreenState();
}

class _TournamentCreateScreenState extends State<TournamentCreateScreen> {
  final _name = TextEditingController();
  String _game = 'uno';
  int _size = 16;
  String _when = '1h';
  DateTime? _custom;
  String _who = 'public';
  bool _saving = false;

  static const _pairSizes = [8, 16, 32];
  static const _tableSizes = [8, 16, 32, 64];
  bool get _pairs => _game == 'chess' || _game == 'tictactoe';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DateTime get _startsAt {
    final now = DateTime.now();
    switch (_when) {
      case '30m':
        return now.add(const Duration(minutes: 30));
      case '1h':
        return now.add(const Duration(hours: 1));
      case 'tonight':
        final t = DateTime(now.year, now.month, now.day, 20);
        return t.isAfter(now.add(const Duration(minutes: 10))) ? t : t.add(const Duration(days: 1));
      default:
        return _custom ?? now.add(const Duration(hours: 1));
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(
        context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
    if (time == null || !mounted) return;
    setState(() {
      _custom = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      _when = 'custom';
    });
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final t = await ApiClient.post('/tournaments', body: {
        'title': _name.text.trim(),
        'gameType': _game,
        'size': _size,
        'startsAt': _startsAt.toUtc().toIso8601String(),
        'visibility': _who,
      }) as Map;
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          settings: RouteSettings(name: 'tournament:${t['id']}'),
          builder: (_) => TournamentScreen(tournamentId: t['id'] as String)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t create it. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF8B8B8B),
        backgroundColor: const Color(0xFF222222),
        labelStyle: TextStyle(color: on ? const Color(0xFFE0E0E0) : AppColors.text, fontSize: 13),
        side: BorderSide(color: on ? _purpleLine : AppColors.border),
        showCheckmark: false,
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final vip = user?.isVip == true && (user?.vipExpiresAt == null || user!.vipExpiresAt!.isAfter(DateTime.now()));
    final sizes = _pairs ? _pairSizes : _tableSizes;
    final s = _startsAt;
    final h = s.hour % 12 == 0 ? 12 : s.hour % 12;
    final whenText = '${s.day}/${s.month} · $h:${s.minute.toString().padLeft(2, '0')} ${s.hour < 12 ? 'AM' : 'PM'}';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('New tournament'), actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF412402),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFBA7517))),
              child: Text(vip ? 'VIP · free' : '200 coins',
                  style: const TextStyle(color: Color(0xFFFAC775), fontSize: 11.5)),
            ),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        TextField(
          controller: _name,
          maxLength: 60,
          decoration: InputDecoration(hintText: '${user?.name.split(' ').first ?? 'My'}’s ${kTourGames[_game]!.$2} Cup'),
        ),
        _label('Game'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 3.4,
          children: [
            for (final g in const ['uno', 'ludo', 'tictactoe', 'chess'])
              Material(
                color: _game == g ? const Color(0xFF8B8B8B) : const Color(0xFF1D1D1D),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _game == g ? _purpleLine : AppColors.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _game = g;
                    if (!(_pairs ? _pairSizes : _tableSizes).contains(_size)) _size = 16;
                  }),
                  child: Center(child: Text(tourGameLabel(g))),
                ),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Truth or dare has no winner, so it can’t be a tournament.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
        ),
        _label('Players'),
        Wrap(spacing: 6, children: [for (final n in sizes) _chip('$n', _size == n, () => setState(() => _size = n))]),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
              _pairs
                  ? '1 vs 1 knockout${_game == 'tictactoe' ? ' · best of 3' : ' · 10 min chess clock each'}'
                  : 'Tables of 4 · top players go through to one final table',
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
        ),
        _label('Starts'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('In 30 min', _when == '30m', () => setState(() => _when = '30m')),
          _chip('In 1 hour', _when == '1h', () => setState(() => _when = '1h')),
          _chip('Tonight 8 PM', _when == 'tonight', () => setState(() => _when = 'tonight')),
          _chip(_when == 'custom' ? whenText : 'Pick…', _when == 'custom', _pickTime),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(whenText, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
        ),
        _label('Who can join'),
        Wrap(spacing: 6, children: [
          _chip('Everyone', _who == 'public', () => setState(() => _who = 'public')),
          _chip('Friends', _who == 'friends', () => setState(() => _who = 'friends')),
          if (user?.isCreator == true)
            _chip('Subscribers', _who == 'subscribers', () => setState(() => _who = 'subscribers')),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF1D1D1D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: const Text(
              '🎟️  Free to enter · winners get 🏆 Trophy coins (🥇 300 · 🥈 150 · 🥉 50 · 4th 50). Trophy coins only buy VIP.',
              style: TextStyle(fontSize: 12.5)),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
          onPressed: _saving ? null : _create,
          child: Text(_saving ? 'Creating…' : 'Create tournament'),
        ),
        const SizedBox(height: 6),
        Text(vip ? 'Free for VIP' : 'Hosting costs 200 coins · free with VIP',
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
      ]),
    );
  }
}
