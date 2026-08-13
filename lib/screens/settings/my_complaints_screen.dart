import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

/// Settings > My Complaints — history of what this user has submitted via
/// ComplaintFormScreen, and whether an admin has resolved it yet.
class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _complaints = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/support/complaints/mine');
      if (!mounted) return;
      setState(() {
        _complaints = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('My Complaints')),
      body: _loading
          ? const Center(child: Spinner())
          : _complaints.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nothing submitted yet.', style: TextStyle(color: AppColors.textFaint))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _complaints.length,
                  itemBuilder: (context, i) {
                    final c = _complaints[i];
                    final resolved = c['status'] == 'resolved';
                    final isSuggestion = c['type'] == 'suggestion';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: (isSuggestion ? AppColors.gold : AppColors.warning).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                                child: Text(isSuggestion ? 'Suggestion' : 'Complaint', style: TextStyle(color: isSuggestion ? AppColors.gold : AppColors.warning, fontSize: 11)),
                              ),
                              const Spacer(),
                              Text(resolved ? 'Resolved' : 'Open', style: TextStyle(color: resolved ? AppColors.success : AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(c['message'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
