import '../../widgets/permission_primer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../theme/room_themes.dart';
import '../../widgets/in_icon_button.dart';
import '../party/party_screen.dart';
import 'source_picker_screen.dart';
import 'watch_room_creator.dart';

// Plain line-icon-on-gradient treatment, matching GamePickerDark.dc.html's
// game cards — inlined here (was its own GamePickerScreen/second page)
// since choosing a game now happens on this same Create Room page.
const _kGames = [
  (
    value: 'chess',
    icon: InIcons.crown,
    label: 'Chess',
    subtitle: '1 vs 1 · classic',
    colors: [Color(0xFF7FA8D9), Color(0xFF4272D9)]
  ),
  (
    value: 'ludo',
    icon: InIcons.dice,
    label: 'Ludo',
    subtitle: '2–4 players',
    colors: [Color(0xFF6ED9A0), Color(0xFF2E9B5F)]
  ),
  (
    value: 'tictactoe',
    icon: InIcons.close,
    label: 'Tic Tac Toe',
    subtitle: '1 vs 1 · quick',
    colors: [Color(0xFFE0836B), Color(0xFFB8422C)]
  ),
  (
    value: 'uno',
    icon: InIcons.ticket,
    label: 'UNO',
    subtitle: '2–6 players',
    colors: [Color(0xFFDBB155), Color(0xFFB98A3D)]
  ),
  (
    value: 'truth_or_dare',
    icon: InIcons.smile,
    label: 'Truth or Dare',
    subtitle: 'Group · party',
    colors: [Color(0xFFE0836B), Color(0xFFB8422C)]
  ),
];

class LobbyCreateScreen extends StatefulWidget {
  /// 'watch', 'voice', 'game' or 'live' — preselected when opened from Create.
  final String initialRoomType;
  const LobbyCreateScreen({super.key, this.initialRoomType = 'watch'});

  @override
  State<LobbyCreateScreen> createState() => _LobbyCreateScreenState();
}

class _RoomTypeSpec {
  final String value;
  final InIconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color tile;
  const _RoomTypeSpec(
      this.value, this.icon, this.label, this.subtitle, this.color, this.tile);
}

class _VisibilitySpec {
  final String value;
  final String label;
  const _VisibilitySpec(this.value, this.label);
}

const _roomTypes = [
  _RoomTypeSpec('watch', InIcons.tv, 'Watch party',
      'YouTube, Netflix, Prime and more', AppColors.pink, Color(0xFF24102A)),
  _RoomTypeSpec('voice', InIcons.mic, 'Voice room', 'Talk and sing together',
      Color(0xFFB97CF8), Color(0xFF1C1638)),
  _RoomTypeSpec('game', InIcons.game, 'Game room', 'Ludo, UNO, Chess…',
      Color(0xFF6E95FD), Color(0xFF122046)),
  _RoomTypeSpec('live', InIcons.live, 'Go live',
      'Stream to followers, earn gifts', AppColors.pink, Color(0xFF2A1028)),
];

// Short labels so all four fit on one line; Private shows as a lock icon
// (its full label is still read out by screen readers — see _visibilityChip).
const _visibilities = [
  _VisibilitySpec('public', 'Public'),
  _VisibilitySpec('friends', 'Friends'),
  _VisibilitySpec('subscribers', 'Subs'),
  _VisibilitySpec('private', 'Private (link only)'),
];

class _LobbyCreateScreenState extends State<LobbyCreateScreen> {
  late String _roomType = widget.initialRoomType;
  final _nameController = TextEditingController();
  // Reused as the reference's "Room Description" field — topic already
  // covers exactly that concept server-side, so there's no need for a
  // second, redundant description column.
  final _topicController = TextEditingController();
  String _visibility = 'public';
  // Applied to voice rooms by _create() below, and to watch rooms by
  // watch_room_creator.dart via WatchRoomOptions (carried through the
  // source picker), along with the room name.
  bool _micEnabled = true;
  bool _hostApprovesMics = true;
  bool _songPermission = true;
  String _theme = RoomTheme.midnight.id;
  bool _saving = false;
  bool _moreOptions = false;
  String _selectedGame = _kGames.first.value;

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final room = await ApiClient.post('/rooms', body: {
        'roomType': _roomType,
        'visibility': _visibility,
        if (_nameController.text.trim().isNotEmpty)
          'title': _nameController.text.trim(),
        if (_topicController.text.trim().isNotEmpty)
          'topic': _topicController.text.trim(),
      }) as Map<String, dynamic>;
      final roomId = room['id'] as String;
      await ApiClient.patch('/rooms/$roomId/settings', body: {
        'micEnabled': _micEnabled,
        'micApproval': _hostApprovesMics ? 'host' : 'everyone',
        'songPermission': _songPermission ? 'anyone' : 'host',
        'theme': _theme,
      }).catchError((_) => null);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Quick-create path for Game rooms — mirrors the old GamePickerScreen's
  // _create() exactly: public visibility, no title/topic, just the chosen
  // game type.
  Future<void> _createGame() async {
    setState(() => _saving = true);
    try {
      final room = await ApiClient.post('/rooms', body: {
        'roomType': 'game',
        'gameType': _selectedGame,
        'visibility': 'public',
      }) as Map<String, dynamic>;
      await ApiClient.patch('/rooms/${room['id']}/settings',
          body: {'theme': _theme}).catchError((_) => null);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _goLive() async {
    await ensurePermissionPrimer(context);
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final room = await ApiClient.post('/rooms', body: {
        'title': _nameController.text.trim().isEmpty
            ? 'Live now'
            : _nameController.text.trim(),
        'roomType': 'live',
        'visibility': _visibility,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PartyScreen(roomId: room['id'] as String)));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openSourcePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SourcePickerScreen(
            visibility: _visibility,
            topic: _topicController.text.trim().isEmpty
                ? null
                : _topicController.text.trim(),
            options: WatchRoomOptions(
              title: _nameController.text.trim().isEmpty
                  ? null
                  : _nameController.text.trim(),
              micEnabled: _micEnabled,
              hostApprovesMics: _hostApprovesMics,
              anyoneCanAddSongs: _songPermission,
              theme: _theme,
            )),
      ),
    );
  }

  // Mirrors the backend's fallbackTitle (routes/room.js), so the hint shows
  // exactly the name the room gets if this is left empty.
  String _defaultName(String? hostName) {
    final name = (hostName == null || hostName.trim().isEmpty)
        ? 'Someone'
        : hostName.trim();
    return _roomType == 'voice' ? "$name's Voice Room" : "$name's Watch Party";
  }

  @override
  Widget build(BuildContext context) {
    final hostName = context.watch<AuthProvider>().user?.name;
    final isGame = _roomType == 'game';
    final isLive = _roomType == 'live';
    final VoidCallback? action = _saving
        ? null
        : switch (_roomType) {
            'watch' => _openSourcePicker,
            'game' => _createGame,
            'live' => _goLive,
            _ => _create,
          };
    final actionLabel = _saving
        ? 'Creating…'
        : switch (_roomType) {
            'watch' => 'Next · pick what to watch',
            'live' => 'Go live',
            _ => 'Create room',
          };
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: [
                  InIconButton(InIcons.back,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 4),
                  const Text('New room',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                children: [
                  _typeCards(),
                  if (isGame) ...[
                    const SizedBox(height: 18),
                    _sectionLabel('Choose a game'),
                    const SizedBox(height: 8),
                    for (final game in _kGames) _gameCard(game),
                  ] else ...[
                    const SizedBox(height: 18),
                    _sectionLabel('Room name'),
                    const SizedBox(height: 8),
                    _pillField(
                        _nameController,
                        isLive
                            ? 'What’s your live about?'
                            : _defaultName(hostName)),
                    const SizedBox(height: 18),
                    _sectionLabel('Who can join'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final v in _visibilities) _visibilityChip(v),
                    ]),
                  ],
                  if (!isLive) ...[
                    const SizedBox(height: 18),
                    _sectionLabel('Lobby theme'),
                    const SizedBox(height: 8),
                    _themePicker(),
                  ],
                  if (!isGame && !isLive) ...[
                    const SizedBox(height: 14),
                    Material(
                      color: AppColors.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppColors.border),
                          borderRadius: BorderRadius.circular(18)),
                      child: Column(children: [
                        _toggleRow(
                            InIcons.mic,
                            'Mics on for everyone',
                            _micEnabled,
                            (v) => setState(() => _micEnabled = v)),
                        if (_micEnabled) ...[
                          const Divider(height: 1, color: Color(0xFF221F2C)),
                          _toggleRow(
                              InIcons.shield,
                              'Host approves mics',
                              _hostApprovesMics,
                              (v) => setState(() => _hostApprovesMics = v)),
                        ],
                        const Divider(height: 1, color: Color(0xFF221F2C)),
                        _toggleRow(
                            InIcons.music,
                            'Anyone can add songs',
                            _songPermission,
                            (v) => setState(() => _songPermission = v)),
                        const Divider(height: 1, color: Color(0xFF221F2C)),
                        InkWell(
                          onTap: () =>
                              setState(() => _moreOptions = !_moreOptions),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(children: [
                              _tile(InIcons.tune),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Text('More options',
                                      style: TextStyle(fontSize: 14))),
                              InIcon(_moreOptions ? InIcons.down : InIcons.chev,
                                  size: 18, color: AppColors.textFaint),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                    if (_moreOptions) ...[
                      const SizedBox(height: 10),
                      _pillField(_topicController, 'Description (optional)'),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
              child: FilledButton(
                onPressed: action,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(color: AppColors.textDim, fontSize: 13));

  Widget _tile(InIconData icon) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: const Color(0xFF1F1A2C),
            borderRadius: BorderRadius.circular(10)),
        child: Center(child: InIcon(icon, size: 17, color: AppColors.lilac)),
      );

  Widget _typeCards() {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final t in _roomTypes)
          SizedBox(
            width: w,
            child: Semantics(
              button: true,
              selected: _roomType == t.value,
              label: t.label,
              child: InkWell(
                onTap: () => setState(() => _roomType = t.value),
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _roomType == t.value ? t.tile : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: _roomType == t.value
                            ? AppColors.purple
                            : AppColors.border,
                        width: _roomType == t.value ? 2 : 1),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InIcon(t.icon, size: 22, color: t.color),
                        const SizedBox(height: 6),
                        Text(t.label,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(t.subtitle,
                            maxLines: 2,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textDim)),
                      ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }

  Widget _themePicker() {
    return SizedBox(
      // Swatch + label; grows with the system text size.
      height: 60 + MediaQuery.textScalerOf(context).scale(11) * 1.6,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final t in RoomTheme.all)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              button: true,
              selected: _theme == t.id,
              label: '${t.label} theme',
              child: GestureDetector(
                onTap: () => setState(() => _theme = t.id),
                child: Column(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: t.bgGradient,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              _theme == t.id ? Colors.white : AppColors.border,
                          width: _theme == t.id ? 2 : 1),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(t.label.split(' ').first,
                      style: TextStyle(
                          fontSize: 11,
                          color: _theme == t.id
                              ? AppColors.text
                              : AppColors.textDim)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _gameCard(
      ({
        String value,
        InIconData icon,
        String label,
        String subtitle,
        List<Color> colors
      }) game) {
    final selected = _selectedGame == game.value;
    return Semantics(
      button: true,
      selected: selected,
      label: game.label,
      child: InkWell(
        onTap: () => setState(() => _selectedGame = game.value),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.purple : AppColors.border,
                width: selected ? 2 : 1),
            color: selected ? const Color(0xFF1C1638) : AppColors.surface,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF122046)),
                alignment: Alignment.center,
                child:
                    InIcon(game.icon, size: 22, color: const Color(0xFF8FB0FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(game.subtitle,
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12)),
                  ],
                ),
              ),
              if (selected)
                const InIcon(InIcons.check, size: 20, color: AppColors.lilac),
            ],
          ),
        ),
      ),
    ).withBottomGap(10);
  }

  Widget _visibilityChip(_VisibilitySpec spec) {
    final selected = _visibility == spec.value;
    return ChoiceChip(
      avatar: spec.value == 'private'
          ? InIcon(InIcons.lock,
              size: 14, color: selected ? Colors.white : AppColors.text)
          : null,
      label: Text(spec.value == 'private' ? 'Private' : spec.label),
      tooltip: spec.label,
      selected: selected,
      showCheckmark: false,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected ? Colors.white : AppColors.text,
          fontWeight: FontWeight.w500),
      onSelected: (_) => setState(() => _visibility = spec.value),
    );
  }

  Widget _toggleRow(
      InIconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      secondary: _tile(icon),
      title: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _pillField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(hintText: hint),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }
}

extension on Widget {
  Widget withBottomGap(double gap) =>
      Padding(padding: EdgeInsets.only(bottom: gap), child: this);
}
