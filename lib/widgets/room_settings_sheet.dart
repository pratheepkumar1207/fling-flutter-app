import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'package:provider/provider.dart';
import '../core/api_exception.dart';
import '../core/auth_provider.dart';
import '../theme/insync_icons.dart';
import '../theme/app_colors.dart';
import 'glass.dart';
import '../theme/room_themes.dart';

const _kGameTypes = [
  ['tictactoe', 'Tic Tac Toe'],
  ['truth_or_dare', 'Truth or Dare'],
  ['ludo', 'Ludo'],
  ['chess', 'Chess'],
  ['uno', 'UNO'],
];

/// Host-only room settings — a short half-height sheet, one-line rows,
/// every change saved the moment it's made (no Save button to forget):
///
///   Boost      100 coins for a day of top placement (POST /boost)
///   Type       Voice · Game           (voice/game rooms only — PATCH /type)
///   Join       Public · Friends · Subs · Private
///   Mics       on/off
///   Music      Everyone · Host        (who can add songs AND play one now)
///   Next song  Auto · Vote · Off      (nextTrackMode + autoPlay)
///
/// "Music" and "Next song" each set two backend fields — see _musicValue /
/// _nextValue for the mapping. Switching to Game needs one extra pick (which
/// game), shown inline right under the Type row. Watch rooms have no Type row:
/// what plays there is changed through the source picker (Search & queue).
Future<void> showRoomSettingsSheet(BuildContext context,
    {required Map<String, dynamic> room, required VoidCallback onChanged}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    showDragHandle: false,
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
  late String _roomType = widget.room['roomType'] as String? ?? 'watch';
  // The type the server actually has — differs from _roomType only while a
  // switch to Game is waiting for its game pick.
  late String _savedType = _roomType;
  late String _gameType = widget.room['gameType'] as String? ?? 'tictactoe';
  late String _visibility = widget.room['visibility'] as String? ?? 'public';
  late bool _micEnabled = widget.room['micEnabled'] != false;
  late String _songPermission =
      widget.room['songPermission'] as String? ?? 'anyone';
  late String _pinPermission =
      widget.room['pinPermission'] as String? ?? 'host';
  late bool _autoPlay = widget.room['autoPlay'] != false;
  late String _nextTrackMode =
      widget.room['nextTrackMode'] as String? ?? 'justPlay';
  late String _theme = widget.room['theme'] as String? ?? 'midnight';

  bool _saving = false;
  bool _savedOnce = false;
  late DateTime? _boostedUntil =
      DateTime.tryParse(widget.room['boostedUntil'] as String? ?? '')
          ?.toLocal();
  bool _boosting = false;

  // Same price as the backend's BOOST_COST_PER_DAY (routes/room.js).
  static const _boostCost = 100;

  String get _musicValue => _songPermission == 'host' ? 'host' : 'everyone';
  String get _nextValue =>
      !_autoPlay ? 'off' : (_nextTrackMode == 'voting' ? 'vote' : 'auto');

  // ---- saving ---------------------------------------------------------

  Future<bool> _patch(String path, Map<String, dynamic> body) async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/rooms/${widget.room['id']}$path', body: body);
      widget.onChanged();
      if (mounted) setState(() => _savedOnce = true);
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't save — check your connection")));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Applies a setting immediately and rolls it back if the save fails.
  Future<void> _saveSettings(Map<String, dynamic> body, VoidCallback apply,
      VoidCallback revert) async {
    setState(apply);
    final ok = await _patch('/settings', body);
    if (!ok && mounted) setState(revert);
  }

  void _setVisibility(String v) {
    final old = _visibility;
    _saveSettings(
        {'visibility': v}, () => _visibility = v, () => _visibility = old);
  }

  void _setTheme(String v) {
    final old = _theme;
    _saveSettings({'theme': v}, () => _theme = v, () => _theme = old);
  }

  // One swatch per lobby theme; everyone in the room sees the host's pick.
  Widget _themePicker() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in RoomTheme.all)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Semantics(
                button: true,
                selected: _theme == t.id,
                label: '${t.label} theme',
                child: GestureDetector(
                  onTap:
                      _saving || _theme == t.id ? null : () => _setTheme(t.id),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [t.bgGradient.colors.last, t.primary]),
                      border: Border.all(
                          color: _theme == t.id
                              ? AppColors.accent
                              : Colors.white24,
                          width: _theme == t.id ? 2.5 : 1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  void _setMics(bool v) {
    _saveSettings(
        {'micEnabled': v}, () => _micEnabled = v, () => _micEnabled = !v);
  }

  void _setMusic(String v) {
    final oldSong = _songPermission, oldPin = _pinPermission;
    final perm = v == 'host' ? 'host' : 'anyone';
    _saveSettings({'songPermission': perm, 'pinPermission': perm}, () {
      _songPermission = perm;
      _pinPermission = perm;
    }, () {
      _songPermission = oldSong;
      _pinPermission = oldPin;
    });
  }

  void _setNext(String v) {
    final oldAuto = _autoPlay, oldMode = _nextTrackMode;
    final body = <String, dynamic>{
      'autoPlay': v != 'off',
      if (v == 'auto') 'nextTrackMode': 'autoFill',
      if (v == 'vote') 'nextTrackMode': 'voting',
    };
    _saveSettings(body, () {
      _autoPlay = v != 'off';
      if (v == 'auto') _nextTrackMode = 'autoFill';
      if (v == 'vote') _nextTrackMode = 'voting';
    }, () {
      _autoPlay = oldAuto;
      _nextTrackMode = oldMode;
    });
  }

  // Voice switches straight away; Game waits for its pick below.
  Future<void> _setType(String t) async {
    if (t == _roomType) return;
    setState(() => _roomType = t);
    if (t == _savedType) return; // switched back before picking anything
    if (t == 'voice') {
      final ok = await _patch('/type', {'roomType': 'voice', 'gameType': null});
      if (!mounted) return;
      setState(() => ok ? _savedType = 'voice' : _roomType = _savedType);
    }
  }

  Future<void> _pickGame(String g) async {
    final old = _gameType;
    setState(() => _gameType = g);
    final ok = await _patch('/type', {'roomType': 'game', 'gameType': g});
    if (!mounted) return;
    setState(() => ok ? _savedType = 'game' : _gameType = old);
  }

  Future<void> _boost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(_isBoosted ? 'Add another day?' : 'Boost this room?'),
        content: const Text(
            'Boosted rooms show at the top of the room list for a day. It costs $_boostCost coins.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Boost · $_boostCost coins')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _boosting = true);
    try {
      final res = await ApiClient.post('/rooms/${widget.room['id']}/boost',
          body: {'days': 1}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _boostedUntil =
          DateTime.tryParse(res['boostedUntil'] as String? ?? '')?.toLocal());
      widget.onChanged();
      // The coins were spent — update the balance shown in the app bar.
      context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't boost — check your connection")));
      }
    } finally {
      if (mounted) setState(() => _boosting = false);
    }
  }

  bool get _isBoosted =>
      _boostedUntil != null && _boostedUntil!.isAfter(DateTime.now());

  Widget _boostRow() {
    final left = _isBoosted ? _boostedUntil!.difference(DateTime.now()) : null;
    final leftText = left == null
        ? null
        : left.inHours >= 1
            ? '${left.inHours}h left'
            : '${left.inMinutes.clamp(1, 59)}m left';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const InIcon(InIcons.star,
              size: 18, color: AppColors.gold, filled: true),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              leftText == null ? 'Boost' : 'Boosted · $leftText',
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _boosting ? null : _boost,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: _boosting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.ink))
                : Text(_isBoosted ? 'Add a day' : '$_boostCost coins'),
          ),
        ],
      ),
    );
  }

  // ---- UI -------------------------------------------------------------

  Widget _segments(
      {required List<(String, Widget)> options,
      required String value,
      required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: AppColors.surface2.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (key, label) in options)
            GestureDetector(
              onTap: _saving ? null : () => onChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: value == key
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color:
                          value == key ? AppColors.accent : AppColors.textDim),
                  child: IconTheme.merge(
                    data: IconThemeData(
                        size: 14,
                        color: value == key
                            ? AppColors.accent
                            : AppColors.textDim),
                    child: label,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(InIconData icon, String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: const Color(0xFF1F1A2C),
                borderRadius: BorderRadius.circular(10)),
            child:
                Center(child: InIcon(icon, size: 17, color: AppColors.lilac)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: control),
          ),
        ],
      ),
    );
  }

  Widget _gamePicker() {
    return Padding(
      padding: const EdgeInsets.only(left: 26, bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final g in _kGameTypes)
            ChoiceChip(
              label: Text(g[1], style: const TextStyle(fontSize: 12)),
              selected: _savedType == 'game' && _gameType == g[0],
              onSelected: _saving ? null : (_) => _pickGame(g[0]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingPick = _roomType != _savedType;
    // Only voice and game rooms can switch between each other here.
    final canSwitchType = _savedType == 'voice' || _savedType == 'game';
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: GlassPanel(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          tintAlpha: 0.8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999))),
                ),
                Row(
                  children: [
                    const Text('Room settings',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_saving)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else if (_savedOnce)
                      const Row(
                        children: [
                          InIcon(InIcons.check,
                              size: 14, color: AppColors.success),
                          SizedBox(width: 3),
                          Text('Saved',
                              style: TextStyle(
                                  color: AppColors.success, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _boostRow(),
                if (canSwitchType)
                  _row(
                    InIcons.tv,
                    'Type',
                    _segments(
                      options: const [
                        ('voice', Text('Voice')),
                        ('game', Text('Game')),
                      ],
                      value: _roomType,
                      onChanged: _setType,
                    ),
                  ),
                if (pendingPick && _roomType == 'game') _gamePicker(),
                _row(
                  InIcons.globe,
                  'Join',
                  _segments(
                    options: const [
                      ('public', Text('Public')),
                      ('friends', Text('Friends')),
                      ('subscribers', Text('Subs')),
                      (
                        'private',
                        InIcon(InIcons.lock,
                            size: 16, semanticLabel: 'Private (link only)')
                      ),
                    ],
                    value: _visibility,
                    onChanged: _setVisibility,
                  ),
                ),
                _row(InIcons.spark, 'Theme', _themePicker()),
                _row(
                  InIcons.mic,
                  'Mics',
                  Switch(
                    value: _micEnabled,
                    onChanged: _saving ? null : _setMics,
                    activeThumbColor: AppColors.accent,
                  ),
                ),
                _row(
                  InIcons.music,
                  'Music',
                  _segments(
                    options: const [
                      ('everyone', Text('Everyone')),
                      ('host', Text('Host')),
                    ],
                    value: _musicValue,
                    onChanged: _setMusic,
                  ),
                ),
                _row(
                  InIcons.skipNext,
                  'Next song',
                  _segments(
                    options: const [
                      ('auto', Text('Auto')),
                      ('vote', Text('Vote')),
                      ('off', Text('Off')),
                    ],
                    value: _nextValue,
                    onChanged: _setNext,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
