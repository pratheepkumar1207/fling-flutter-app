import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/language_options.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../theme/glass.dart';
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
  bool _showFilters = false;
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
    if (_cityController.text.trim().isNotEmpty) params['city'] = _cityController.text.trim();
    if (_minAgeController.text.trim().isNotEmpty) params['minAge'] = _minAgeController.text.trim();
    if (_maxAgeController.text.trim().isNotEmpty) params['maxAge'] = _maxAgeController.text.trim();
    if (_gender != null) params['gender'] = _gender!;
    if (_lookingFor != null) params['lookingFor'] = _lookingFor!;
    if (_religionController.text.trim().isNotEmpty) params['religion'] = _religionController.text.trim();
    if (_languages.isNotEmpty) params['languages'] = _languages.join(',');
    if (_onlineOnly) params['onlineOnly'] = 'true';
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    try {
      final data = await ApiClient.get('/discover${query.isNotEmpty ? '?$query' : ''}');
      if (!mounted) return;
      setState(() {
        _deck = (data as List).map((e) => DiscoverProfile.fromJson(e as Map<String, dynamic>)).toList();
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
      final res = await ApiClient.post('/swipe', body: {'toUserId': top.id, 'action': action}) as Map<String, dynamic>;
      if (!mounted) return;
      if (res['matched'] == true) {
        setState(() {
          _matchName = top.name;
          _lastSwiped = null; // matched swipes can't be undone — see /swipe/undo
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong')));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Text('Discover', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    child: GlassIcon.circle(
                      size: 34,
                      colors: const [AppColors.accent2, AppColors.primary],
                      glowColor: AppColors.primary.withValues(alpha: 0.4),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _segmentButton(
                      icon: Icons.casino_rounded,
                      label: 'Random Match',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RandomMatchScreen())),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _segmentButton(
                      icon: Icons.map_rounded,
                      label: 'Explore Map',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapExploreScreen())),
                    ),
                  ),
                ],
              ),
            ),
            if (_showFilters)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    TextField(controller: _cityController, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: 'City')),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextField(controller: _minAgeController, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: 'Min age'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _maxAgeController, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: 'Max age'))),
                    ]),
                    const SizedBox(height: 8),
                    DropdownButton<String?>(
                      value: _gender,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Any gender', style: TextStyle(color: AppColors.textFaint)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Any gender')),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String?>(
                      value: _lookingFor,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      hint: const Text('Any relationship goal', style: TextStyle(color: AppColors.textFaint)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Any relationship goal')),
                        DropdownMenuItem(value: 'friends', child: Text('🤝 Friends')),
                        DropdownMenuItem(value: 'explore', child: Text('✨ Explore')),
                        DropdownMenuItem(value: 'short_term', child: Text('💫 Short-term')),
                        DropdownMenuItem(value: 'long_term', child: Text('💍 Long-term')),
                        DropdownMenuItem(value: 'not_sure', child: Text('🤔 Not sure yet')),
                      ],
                      onChanged: (v) => setState(() => _lookingFor = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _religionController, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: 'Religion')),
                    const SizedBox(height: 8),
                    const Align(alignment: Alignment.centerLeft, child: Text('Languages', style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
                    const SizedBox(height: 6),
                    InterestPicker(selected: _languages, onChanged: (v) => setState(() => _languages = v), options: kLanguageOptions),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _onlineOnly,
                      onChanged: (v) => setState(() => _onlineOnly = v ?? false),
                      title: const Text('Online only', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _load, child: const Text('Apply filters'))),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: Spinner(size: 28))
                  : (deck == null || deck.isEmpty)
                      ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No more profiles.\nCheck back later, or widen your filters.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint))))
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Stack(
                            children: deck
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
                                    ))
                                .toList(),
                          ),
                        ),
            ),
            if (deck != null && deck.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_lastSwiped != null) ...[
                      _roundButton('↺', AppColors.gold, _undoing ? () {} : _undoLastSwipe, small: true),
                      const SizedBox(width: 14),
                    ],
                    _roundButton('✕', AppColors.danger, () => _handleSwipe('pass')),
                    const SizedBox(width: 20),
                    _roundButton('★', AppColors.accent, () => _handleSwipe('superlike')),
                    const SizedBox(width: 20),
                    _roundButton('♥', AppColors.primary, () => _handleSwipe('like'), filled: true),
                  ],
                ),
              ),
          ],
        ),
        if (_matchName != null)
          GestureDetector(
            onTap: () => setState(() => _matchName = null),
            child: Container(
              color: Colors.black.withValues(alpha: 0.8),
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("It's a match! 🎉", style: TextStyle(color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('You and $_matchName liked each other.', style: const TextStyle(color: AppColors.textDim), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _roundButton(String label, Color color, VoidCallback onTap, {bool small = false, bool filled = false}) {
    final size = small ? 42.0 : 56.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled ? AppGradients.volaCtaDiagonal : null,
          color: filled ? null : AppColors.surface,
          border: filled ? null : Border.all(color: AppColors.border),
          boxShadow: filled ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 3))] : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: filled ? Colors.white : color, fontSize: small ? 18 : 24)),
      ),
    );
  }

  Widget _segmentButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
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
