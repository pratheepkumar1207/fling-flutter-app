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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to join')));
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
              const Text('Create a community', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(controller: nameController, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: descController, maxLines: 2, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: 'Description')),
              const SizedBox(height: 8),
              TextField(controller: rulesController, maxLines: 2, style: const TextStyle(color: AppColors.text), decoration: const InputDecoration(hintText: 'Rules')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameController.text.trim().isEmpty) return;
                        setSheetState(() => saving = true);
                        try {
                          await ApiClient.post('/communities', body: {'name': nameController.text.trim(), 'description': descController.text, 'rules': rulesController.text});
                          if (mounted) Navigator.of(sheetContext).pop();
                          _load();
                        } catch (_) {
                          setSheetState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Creating…' : 'Create'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final c = _list[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                            child: Row(
                              children: [
                                Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.surface3, shape: BoxShape.circle), alignment: Alignment.center, child: const Text('🏘️', style: TextStyle(fontSize: 18))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(communityId: c['id'] as String, name: c['name'] as String?))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['name'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                                        Text('${c['memberCount'] ?? 0} members', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_tab == 'browse') ElevatedButton(onPressed: () => _join(c['id'] as String), child: const Text('Join', style: TextStyle(fontSize: 12))),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

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
