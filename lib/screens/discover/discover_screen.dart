import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/language_options.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../messages/messages_screen.dart';
import '../../widgets/interest_picker.dart';
import '../../widgets/spinner.dart';
import 'map_explore_screen.dart';
import 'random_match_screen.dart';
import 'swipe_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<DiscoverProfile>? _deck;
  bool _loading = true;
  String? _matchName;
  DiscoverProfile? _lastSwiped;
  bool _undoing = false;

  final _cityController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();
  final _religionController = TextEditingController();
  String? _gender;
  String? _lookingFor;
  List<String> _languages = [];
  bool _onlineOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final params = <String, String>{};
    if (_cityController.text.trim().isNotEmpty) {
      params['city'] = _cityController.text.trim();
    }
    if (_minAgeController.text.trim().isNotEmpty) {
      params['minAge'] = _minAgeController.text.trim();
    }
    if (_maxAgeController.text.trim().isNotEmpty) {
      params['maxAge'] = _maxAgeController.text.trim();
    }
    if (_gender != null) params['gender'] = _gender!;
    if (_lookingFor != null) params['lookingFor'] = _lookingFor!;
    if (_religionController.text.trim().isNotEmpty) {
      params['religion'] = _religionController.text.trim();
    }
    if (_languages.isNotEmpty) params['languages'] = _languages.join(',');
    if (_onlineOnly) params['onlineOnly'] = 'true';
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    try {
      final data =
          await ApiClient.get('/discover${query.isNotEmpty ? '?$query' : ''}');
      if (!mounted) return;
      setState(() {
        _deck = (data as List)
            .map((e) => DiscoverProfile.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSwipe(String action) async {
    final deck = _deck;
    if (deck == null || deck.isEmpty) return;
    final top = deck.last;
    final previousLastSwiped = _lastSwiped;
    setState(() {
      _deck = deck.sublist(0, deck.length - 1);
      _lastSwiped = top;
    });
    try {
      final res = await ApiClient.post('/swipe',
          body: {'toUserId': top.id, 'action': action}) as Map<String, dynamic>;
      if (!mounted) return;
      if (res['matched'] == true) {
        setState(() {
          _matchName = top.name;
          _lastSwiped =
              null; // matched swipes can't be undone — see /swipe/undo
        });
      }
    } catch (_) {
      if (!mounted) return;
      // The optimistic removal above assumed the request would succeed —
      // on failure the profile was never actually swiped, so put it back
      // on top of the deck instead of leaving it silently dropped, and
      // restore whatever "undo" target was showing before this attempt.
      setState(() {
        _deck = deck;
        _lastSwiped = previousLastSwiped;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong')));
    }
  }

  // Coin-gated "reverse swipe" — see POST /swipe/undo. Puts the most
  // recently swiped profile back on top of the deck.
  Future<void> _undoLastSwipe() async {
    final lastSwiped = _lastSwiped;
    if (lastSwiped == null || _undoing) return;
    setState(() => _undoing = true);
    try {
      await ApiClient.post('/swipe/undo');
      if (!mounted) return;
      setState(() {
        _deck = [...(_deck ?? []), lastSwiped];
        _lastSwiped = null;
      });
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _undoing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Discover',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  InIconButton(InIcons.map,
                      tooltip: 'Explore map',
                      border: true,
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const MapExploreScreen()))),
                  const SizedBox(width: 6),
                  InIconButton(InIcons.dice,
                      tooltip: 'Random match',
                      border: true,
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RandomMatchScreen()))),
                  const SizedBox(width: 6),
                  InIconButton(InIcons.tune,
                      tooltip: 'Filters',
                      border: true,
                      iconSize: 20,
                      badge: _activeFilterCount,
                      onPressed: _openFilters),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: Spinner(size: 28))
                  : (deck == null || deck.isEmpty)
                      ? _EmptyDeck(onFilters: _openFilters)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Stack(
                            children: [
                              if (deck.length > 1)
                                Positioned.fill(
                                  top: 10,
                                  left: 14,
                                  right: 14,
                                  bottom: -6,
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF1A1724),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                            color: AppColors.border)),
                                  ),
                                ),
                              ...deck
                                  .asMap()
                                  .entries
                                  .where((e) => e.key >= deck.length - 3)
                                  .map((e) => Positioned.fill(
                                        child: SwipeCard(
                                          key: ValueKey(e.value.id),
                                          profile: e.value,
                                          active: e.key == deck.length - 1,
                                          onSwipe: _handleSwipe,
                                        ),
                                      )),
                            ],
                          ),
                        ),
            ),
            if (deck != null && deck.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _roundAction(
                        InIcons.undo,
                        'Rewind',
                        AppColors.gold,
                        _lastSwiped != null && !_undoing
                            ? _undoLastSwipe
                            : null,
                        size: 48),
                    const SizedBox(width: 16),
                    _roundAction(InIcons.close, 'Nope', const Color(0xFFFF6B7F),
                        () => _handleSwipe('pass'),
                        size: 62, iconSize: 28),
                    const SizedBox(width: 16),
                    _roundAction(
                        InIcons.star,
                        'Super like',
                        const Color(0xFF6E95FD),
                        () => _handleSwipe('superlike'),
                        size: 48),
                    const SizedBox(width: 16),
                    _roundAction(InIcons.heart, 'Like', Colors.white,
                        () => _handleSwipe('like'),
                        size: 62, iconSize: 28, filled: true),
                  ],
                ),
              ),
          ],
        ),
        if (_matchName != null)
          _MatchOverlay(
            name: _matchName!,
            onClose: () => setState(() => _matchName = null),
            onMessage: () {
              setState(() => _matchName = null);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MessagesScreen()));
            },
          ),
      ],
    );
  }

  int get _activeFilterCount => [
        _cityController.text.trim().isNotEmpty,
        _minAgeController.text.trim().isNotEmpty ||
            _maxAgeController.text.trim().isNotEmpty,
        _gender != null,
        _lookingFor != null,
        _religionController.text.trim().isNotEmpty,
        _languages.isNotEmpty,
        _onlineOnly,
      ].where((x) => x).length;

  Future<void> _openFilters() async {
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          void set(VoidCallback f) {
            setSheet(f);
            setState(() {});
          }

          Widget label(String t) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(t,
                    style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600)),
              );
          Widget choice(String text, bool on, VoidCallback tap) => ChoiceChip(
                label: Text(text),
                selected: on,
                showCheckmark: false,
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: on ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w500),
                onSelected: (_) => tap(),
              );
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  label('SHOW ME'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final g in const [
                      (null, 'Any gender'),
                      ('female', 'Female'),
                      ('male', 'Male'),
                      ('other', 'Other'),
                    ])
                      choice(g.$2, _gender == g.$1,
                          () => set(() => _gender = g.$1)),
                  ]),
                  label('AGE'),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _minAgeController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(hintText: 'From 18'))),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('–')),
                    Expanded(
                        child: TextField(
                            controller: _maxAgeController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(hintText: 'To any'))),
                  ]),
                  label('CITY'),
                  TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                          hintText: 'Anywhere',
                          prefixIcon: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: InIcon(InIcons.pin,
                                  size: 18, color: AppColors.textDim)),
                          prefixIconConstraints:
                              BoxConstraints(minWidth: 0, minHeight: 0))),
                  label('RELATIONSHIP GOAL'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final g in const [
                      (null, 'Any'),
                      ('long_term', 'Long-term'),
                      ('short_term', 'Short-term'),
                      ('friends', 'Friends'),
                      ('not_sure', 'Not sure yet'),
                      ('explore', 'Explore'),
                    ])
                      choice(g.$2, _lookingFor == g.$1,
                          () => set(() => _lookingFor = g.$1)),
                  ]),
                  label('LANGUAGES'),
                  InterestPicker(
                      selected: _languages,
                      onChanged: (v) => set(() => _languages = v),
                      options: kLanguageOptions),
                  label('RELIGION'),
                  TextField(
                      controller: _religionController,
                      decoration: const InputDecoration(hintText: 'Any')),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _onlineOnly,
                    onChanged: (v) => set(() => _onlineOnly = v),
                    title: const Text('Online only'),
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () => set(() {
                          _cityController.clear();
                          _minAgeController.clear();
                          _maxAgeController.clear();
                          _religionController.clear();
                          _gender = null;
                          _lookingFor = null;
                          _languages = [];
                          _onlineOnly = false;
                        }),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50)),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheet).pop(true),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50)),
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (apply == true) _load();
  }

  Widget _roundAction(
      InIconData icon, String label, Color color, VoidCallback? onTap,
      {required double size, double iconSize = 22, bool filled = false}) {
    final disabled = onTap == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: size / 2 + 4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled ? AppGradients.brandDiagonal : null,
            color: filled ? null : AppColors.surface,
            border: filled ? null : Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: InIcon(icon,
              size: iconSize,
              filled: filled || icon == InIcons.star,
              color: disabled ? color.withValues(alpha: 0.35) : color),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _religionController.dispose();
    super.dispose();
  }
}

class _EmptyDeck extends StatelessWidget {
  final VoidCallback onFilters;
  const _EmptyDeck({required this.onFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: const Color(0xFF2A1A10),
                borderRadius: BorderRadius.circular(21)),
            child: const Center(
                child:
                    InIcon(InIcons.flame, size: 30, color: Color(0xFFFF9F5A))),
          ),
          const SizedBox(height: 12),
          const Text('No one new nearby',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Check back later, or widen your filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 14),
          OutlinedButton(
              onPressed: onFilters, child: const Text('Edit filters')),
        ]),
      ),
    );
  }
}

/// "It's a match!" — full-screen celebration after a mutual like.
class _MatchOverlay extends StatelessWidget {
  final String name;
  final VoidCallback onClose;
  final VoidCallback onMessage;
  const _MatchOverlay(
      {required this.name, required this.onClose, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthProvider>().user;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1,
            colors: [Color(0xF04A1A5A), Color(0xF20A0A0D)],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('IT’S A',
              style: TextStyle(
                  color: AppColors.lilac,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700)),
          ShaderMask(
            shaderCallback: (r) => AppGradients.brandDiagonal.createShader(r),
            child: const Text('Match!',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: Colors.white)),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Transform.rotate(
              angle: -0.14,
              child: Avatar(
                  src: me?.avatarUrl,
                  name: me?.name,
                  size: AvatarSize.lg,
                  ring: true),
            ),
            Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                  color: AppColors.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 3)),
              child: const Center(
                  child: InIcon(InIcons.heart,
                      size: 22, color: Colors.white, filled: true)),
            ),
            Transform.rotate(
              angle: 0.14,
              child: Avatar(name: name, size: AvatarSize.lg, ring: true),
            ),
          ]),
          const SizedBox(height: 18),
          Text('You and $name liked each other.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD8D4E2), fontSize: 15)),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onMessage,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const InIcon(InIcons.chat, size: 18, color: Colors.white),
            label: const Text('Send a message'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onClose,
            child: const Text('Keep swiping',
                style: TextStyle(color: AppColors.textDim)),
          ),
        ]),
      ),
    );
  }
}
