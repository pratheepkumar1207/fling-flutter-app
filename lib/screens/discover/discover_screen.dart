import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
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

  final _cityController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();
  String? _gender;
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
    setState(() => _deck = deck.sublist(0, deck.length - 1));
    try {
      final res = await ApiClient.post('/swipe', body: {'toUserId': top.id, 'action': action}) as Map<String, dynamic>;
      if (res['matched'] == true) {
        setState(() => _matchName = top.name);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong')));
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discover', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                    child: const Text('Filters', style: TextStyle(color: AppColors.primary)),
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
                    _roundButton('✕', AppColors.danger, () => _handleSwipe('pass')),
                    const SizedBox(width: 20),
                    _roundButton('★', AppColors.accent, () => _handleSwipe('superlike')),
                    const SizedBox(width: 20),
                    _roundButton('♥', AppColors.primary, () => _handleSwipe('like')),
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

  Widget _roundButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, border: Border.all(color: AppColors.border)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: color, fontSize: 24)),
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }
}
