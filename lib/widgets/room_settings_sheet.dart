import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'package:provider/provider.dart';
import '../core/api_exception.dart';
import '../core/auth_provider.dart';
import '../theme/insync_icons.dart';
import '../theme/app_colors.dart';
import 'guest_settings_sheet.dart';
import 'room_sheet.dart';
import '../core/room_prefs.dart';
import '../theme/room_themes.dart';

const _kGameTypes = [
  ['tictactoe', 'Tic Tac Toe'],
  ['truth_or_dare', 'Truth or Dare'],
  ['ludo', 'Ludo'],
  ['chess', 'Chess'],
  ['uno', 'UNO'],
];

/// Room settings for the host, as a black sheet under the video (see
/// showRoomSheet): the room's name; Boost · Theme · Moderation · Chat ·
/// Wait for ads tiles; Who can join; Mics (Off · Ask first · Open);
/// Playback (Let's vote · Just play · Autoplay · Only me); then the host's
/// own sound bar and switches (RoomPersonalSettings) and End room. Every
/// change saves the moment it's made.
///
/// Mics and Playback each set more than one backend field — see _micValue /
/// _playbackValue for the mapping. Voice and game rooms also get a Type row;
/// switching to Game needs one extra pick (which game), shown right under it.
Future<void> showRoomSettingsSheet(BuildContext context,
    {required Map<String, dynamic> room,
    required VoidCallback onChanged,
    VoidCallback? onModeration,
    VoidCallback? onEndRoom,
    bool hasVideo = true,
    double halfFraction = 0.62}) {
  RoomPrefs.instance.load();
  return showRoomSheet(
    context,
    halfFraction: halfFraction,
    builder: (_, scroll) => _RoomSettingsSheet(
        room: room,
        scroll: scroll,
        onChanged: onChanged,
        onModeration: onModeration,
        onEndRoom: onEndRoom,
        hasVideo: hasVideo),
  );
}

class _RoomSettingsSheet extends StatefulWidget {
  final Map<String, dynamic> room;
  final ScrollController scroll;
  final VoidCallback onChanged;
  final VoidCallback? onModeration;
  final VoidCallback? onEndRoom;
  final bool hasVideo;
  const _RoomSettingsSheet(
      {required this.room,
      required this.scroll,
      required this.onChanged,
      this.onModeration,
      this.onEndRoom,
      this.hasVideo = true});

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
  late String _nextTrackMode =
      widget.room['nextTrackMode'] as String? ?? 'justPlay';
  late String _theme = widget.room['theme'] as String? ?? 'dark';
  late bool _openMics = widget.room['micApproval'] == 'everyone';
  late bool _chatOn = widget.room['chatEnabled'] != false;
  late bool _waitForAds = widget.room['waitForAds'] != false;
  bool _showThemes = false;
  late final _name =
      TextEditingController(text: widget.room['title'] as String? ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _saveName() {
    final v = _name.text.trim();
    if (v.isEmpty || v == widget.room['title']) return;
    _patch('/settings', {'title': v});
  }

  void _setChat(bool v) =>
      _saveSettings({'chatEnabled': v}, () => _chatOn = v, () => _chatOn = !v);

  void _setWaitForAds(bool v) => _saveSettings(
      {'waitForAds': v}, () => _waitForAds = v, () => _waitForAds = !v);

  // Closes the sheet, then runs [action] (Moderation, End room).
  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  bool _saving = false;
  late DateTime? _boostedUntil =
      DateTime.tryParse(widget.room['boostedUntil'] as String? ?? '')
          ?.toLocal();
  bool _boosting = false;

  // Same price as the backend's BOOST_COST_PER_DAY (routes/room.js).
  static const _boostCost = 100;

  // Off · Ask first · Open — micEnabled plus micApproval.
  String get _micValue => !_micEnabled
      ? 'off'
      : _openMics
          ? 'open'
          : 'ask';

  // Let's vote · Just play · Autoplay · Only me — who can add songs plus
  // what plays next (nextTrackMode; songs always move on by themselves).
  String get _playbackValue => _songPermission == 'host'
      ? 'me'
      : _nextTrackMode == 'voting'
          ? 'vote'
          : _nextTrackMode == 'autoFill'
              ? 'auto'
              : 'just';

  // ---- saving ---------------------------------------------------------

  Future<bool> _patch(String path, Map<String, dynamic> body) async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/rooms/${widget.room['id']}$path', body: body);
      widget.onChanged();
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
    _saveSettings({'theme': v}, () {
      _theme = v;
      _showThemes = false;
    }, () => _theme = old);
  }

  void _setMicMode(String v) {
    final oldOn = _micEnabled, oldOpen = _openMics;
    _saveSettings({
      'micEnabled': v != 'off',
      if (v != 'off') 'micApproval': v == 'open' ? 'everyone' : 'host',
    }, () {
      _micEnabled = v != 'off';
      if (v != 'off') _openMics = v == 'open';
    }, () {
      _micEnabled = oldOn;
      _openMics = oldOpen;
    });
  }

  void _setPlayback(String v) {
    final oldSong = _songPermission,
        oldPin = _pinPermission,
        oldMode = _nextTrackMode;
    final perm = v == 'me' ? 'host' : 'anyone';
    final mode = v == 'vote'
        ? 'voting'
        : v == 'auto'
            ? 'autoFill'
            : 'justPlay';
    _saveSettings({
      'songPermission': perm,
      'pinPermission': perm,
      'autoPlay': true,
      'nextTrackMode': mode,
    }, () {
      _songPermission = perm;
      _pinPermission = perm;
      _nextTrackMode = mode;
    }, () {
      _songPermission = oldSong;
      _pinPermission = oldPin;
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

  String get _boostLabel {
    if (!_isBoosted) return 'Boost';
    final left = _boostedUntil!.difference(DateTime.now());
    return left.inHours >= 1
        ? '${left.inHours}h left'
        : '${left.inMinutes.clamp(1, 59)}m left';
  }

  RoomTheme get _currentTheme => RoomTheme.all
      .firstWhere((t) => t.id == _theme, orElse: () => RoomTheme.all.first);

  Widget _themeDot(RoomTheme t, double size, {bool picked = false}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.bgGradient.colors.last, t.primary]),
          border: Border.all(
              color: picked ? Colors.white : Colors.white24,
              width: picked ? 2 : 1),
        ),
      );

  // One circle per lobby theme; everyone in the room sees the host's pick.
  Widget _themeRow() => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kSheetBorder)),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in RoomTheme.all)
              Semantics(
                button: true,
                selected: _theme == t.id,
                label: '${t.label} theme',
                child: GestureDetector(
                  onTap:
                      _saving || _theme == t.id ? null : () => _setTheme(t.id),
                  child: _themeDot(t, 32, picked: _theme == t.id),
                ),
              ),
          ],
        ),
      );

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
    const off = Color(0xFF666666);
    return ListView(
      controller: widget.scroll,
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
      children: [
        const RoomSheetHandle(),
        TextField(
          controller: _name,
          maxLength: 60,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveName(),
          onTapOutside: (_) => _saveName(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Room name',
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF111111),
            suffixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child:
                    InIcon(InIcons.edit, size: 16, color: Color(0xFF888888))),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kSheetBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kSheetBorder)),
          ),
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: RoomQuickTile(
              icon: _boosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))
                  : const InIcon(InIcons.star,
                      size: 20, color: AppColors.gold, filled: true),
              label: _boostLabel,
              onTap: _boosting ? null : _boost,
            ),
          ),
          Expanded(
            child: RoomQuickTile(
              icon: _themeDot(_currentTheme, 22, picked: true),
              label: 'Theme',
              onTap: () => setState(() => _showThemes = !_showThemes),
            ),
          ),
          Expanded(
            child: RoomQuickTile(
              icon: const InIcon(InIcons.shield,
                  size: 20, color: AppColors.lilac),
              label: 'Moderation',
              onTap: widget.onModeration == null
                  ? null
                  : () => _closeThen(widget.onModeration!),
            ),
          ),
          Expanded(
            child: RoomQuickTile(
              icon: InIcon(InIcons.chat,
                  size: 20, color: _chatOn ? Colors.white : off),
              label: _chatOn ? 'Chat on' : 'Chat off',
              on: _chatOn,
              onTap: _saving ? null : () => _setChat(!_chatOn),
            ),
          ),
          Expanded(
            child: RoomQuickTile(
              icon: InIcon(InIcons.hourglass,
                  size: 20, color: _waitForAds ? Colors.white : off),
              label: _waitForAds ? 'Wait for ads' : 'Ads: no wait',
              on: _waitForAds,
              onTap: _saving ? null : () => _setWaitForAds(!_waitForAds),
            ),
          ),
        ]),
        if (_showThemes) _themeRow(),
        if (canSwitchType) ...[
          const RoomSheetLabel('TYPE'),
          RoomChoiceRow(
            options: const [
              ('voice', InIcons.mic, 'Voice'),
              ('game', InIcons.game, 'Game'),
            ],
            value: _roomType,
            onChanged: _setType,
          ),
          if (pendingPick && _roomType == 'game') _gamePicker(),
        ],
        const RoomSheetLabel('WHO CAN JOIN'),
        RoomChoiceRow(
          options: const [
            ('public', InIcons.globe, 'Anyone'),
            ('friends', InIcons.users, 'Friends'),
            ('subscribers', InIcons.star, 'Subs'),
            ('private', InIcons.lock, 'Link only'),
          ],
          value: _visibility,
          onChanged: _saving ? null : _setVisibility,
        ),
        const RoomSheetLabel('MICS'),
        RoomChoiceRow(
          options: const [
            ('off', InIcons.micoff, 'Off'),
            ('ask', InIcons.wave, 'Ask first'),
            ('open', InIcons.mic, 'Open'),
          ],
          value: _micValue,
          onChanged: _saving ? null : _setMicMode,
        ),
        const RoomSheetLabel('PLAYBACK'),
        RoomChoiceRow(
          options: const [
            ('vote', InIcons.poll, "Let's vote"),
            ('just', InIcons.queue, 'Just play'),
            ('auto', InIcons.spark, 'Autoplay'),
            ('me', InIcons.crown, 'Only me'),
          ],
          value: _playbackValue,
          onChanged: _saving ? null : _setPlayback,
        ),
        RoomPersonalSettings(hasVideo: widget.hasVideo),
        if (widget.onEndRoom != null) ...[
          const SizedBox(height: 18),
          RoomSheetButton(
            icon: InIcons.close,
            label: 'End room for everyone',
            danger: true,
            onTap: () => _closeThen(widget.onEndRoom!),
          ),
        ],
      ],
    );
  }
}
