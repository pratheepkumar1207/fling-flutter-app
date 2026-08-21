import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import 'community_detail_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  String _tab = 'browse';
  bool _loading = true;
  List<Map<String, dynamic>> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get(_tab == 'browse' ? '/communities/browse' : '/communities/mine');
      if (!mounted) return;
      setState(() {
        _list = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(String id) async {
    try {
      await ApiClient.post('/communities/$id/join');
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to join')));
    }
  }

  void _openCreate() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final rulesController = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
              const Text('Create a community', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              _sheetField(nameController, 'Name'),
              const SizedBox(height: 10),
              _sheetField(descController, 'Description', maxLines: 2),
              const SizedBox(height: 10),
              _sheetField(rulesController, 'Rules', maxLines: 2),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: saving
                    ? null
                    : () async {
                        if (nameController.text.trim().isEmpty) return;
                        setSheetState(() => saving = true);
                        try {
                          await ApiClient.post('/communities', body: {'name': nameController.text.trim(), 'description': descController.text, 'rules': rulesController.text});
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          _load();
                        } catch (_) {
                          setSheetState(() => saving = false);
                        }
                      },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: saving ? null : const LinearGradient(colors: AppGradients.brand),
                    color: saving ? AppColors.surface2 : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(saving ? 'Creating…' : 'Create', style: TextStyle(color: saving ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
      rulesController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Communities'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: TextButton(onPressed: _openCreate, child: const Text('+ Create'))),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _tabChip('browse', 'Browse'),
                const SizedBox(width: 8),
                _tabChip('mine', 'Mine'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Spinner())
                : _list.isEmpty
                    ? const Center(child: Text('No communities', style: TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _list.length,
                        itemBuilder: (context, i) => _communityCard(context, _list[i]),
                      ),
          ),
        ],
      ),
    );
  }

  // Deterministic-per-community gradient banner (no bannerColor field from
  // the API) — matches CommunitiesDark.dc.html's banner+overlapping-logo
  // card, just without a real uploaded banner image to show.
  static const _bannerGradients = [
    [Color(0xFFB251C5), Color(0xFF8E3AAF)],
    [Color(0xFF4FB98A), Color(0xFF2E8C64)],
    [Color(0xFFE8A23F), Color(0xFFC66B2E)],
    [Color(0xFF4272D9), Color(0xFF2E4FA3)],
  ];

  Widget _communityCard(BuildContext context, Map<String, dynamic> c) {
    final name = c['name'] as String? ?? '';
    final gradient = _bannerGradients[name.hashCode.abs() % _bannerGradients.length];
    final joined = _tab == 'mine';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(communityId: c['id'] as String, name: name))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(height: 74, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient))),
                Positioned(
                  left: 16,
                  bottom: -20,
                  child: Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                    child: Container(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient), borderRadius: BorderRadius.circular(11)),
                      alignment: Alignment.center,
                      child: const Text('🏘️', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 14.5))),
                      GestureDetector(
                        onTap: joined ? null : () => _join(c['id'] as String),
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: joined ? null : const LinearGradient(colors: AppGradients.brand),
                            color: joined ? AppColors.surface2 : null,
                            border: joined ? Border.all(color: AppColors.border) : null,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(joined ? 'Joined' : 'Join', style: TextStyle(color: joined ? AppColors.textDim : Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${c['memberCount'] ?? 0} members', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController controller, String hint, {int maxLines = 1}) => Container(
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.text),
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        ),
      );

  Widget _tabChip(String key, String label) => ChoiceChip(
        label: Text(label),
        selected: _tab == key,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: _tab == key ? AppColors.primary : AppColors.textDim, fontSize: 12),
        backgroundColor: AppColors.surface,
        onSelected: (_) {
          setState(() => _tab = key);
          _load();
        },
      );
}
