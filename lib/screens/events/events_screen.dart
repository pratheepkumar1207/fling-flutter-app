import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import '../party/party_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/rooms/events');
      if (!mounted) return;
      setState(() {
        _events = (data as List).cast<Map<String, dynamic>>();
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
      appBar: AppBar(title: const Text('Events')),
      body: _loading
          ? const Center(child: Spinner())
          : _events.isEmpty
              ? const Center(child: Text('No upcoming events', style: TextStyle(color: AppColors.textFaint)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, i) {
                    final ev = _events[i];
                    final scheduledAt = DateTime.tryParse(ev['scheduledAt']?.toString() ?? '');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ev['title'] as String? ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                          if (ev['topic'] != null) Text(ev['topic'] as String, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${ev['hostName'] ?? ''}${scheduledAt != null ? ' · ${DateFormat.MMMd().add_jm().format(scheduledAt)}' : ''}',
                              style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: ev['id'] as String))),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('View room →', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
