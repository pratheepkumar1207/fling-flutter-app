import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';
import '../party/party_screen.dart';

const _kRoomTypeStyles = {
  'watch': (
    icon: Icons.play_arrow_rounded,
    colors: [Color(0xFFE0836B), Color(0xFFB8422C)],
    label: 'Watch Party'
  ),
  'voice': (
    icon: Icons.mic_rounded,
    colors: [Color(0xFF6ED9A0), Color(0xFF2E9B5F)],
    label: 'Voice Room'
  ),
  'game': (
    icon: Icons.casino_rounded,
    colors: [Color(0xFF7FA8D9), Color(0xFF4272D9)],
    label: 'Game Room'
  ),
  'live': (
    icon: Icons.wifi_tethering_rounded,
    colors: [Color(0xFFED8B6B), Color(0xFFED4B43)],
    label: 'Live'
  ),
};

/// Matches EventsDark.dc.html: date-grouped ("Today"/"Tomorrow"/...) rows
/// with a time badge, a room-type gradient icon, host/type subtitle, and a
/// "Remind" pill — a real toggle backed by POST /rooms/:id/remind (added
/// alongside this rewrite) and a server-side poller that pushes a
/// notification a few minutes before the room's scheduledAt, not just a
/// relabeled "View room" link.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];
  final Set<String> _toggling = {};

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

  Future<void> _toggleRemind(String roomId) async {
    setState(() => _toggling.add(roomId));
    try {
      final res =
          await ApiClient.post('/rooms/$roomId/remind') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        final ev = _events.firstWhere((e) => e['id'] == roomId);
        ev['remindMe'] = res['remindMe'];
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update reminder')));
      }
    } finally {
      if (mounted) setState(() => _toggling.remove(roomId));
    }
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat.MMMEd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Upcoming')),
      body: _loading
          ? const Center(child: Spinner())
          : _events.isEmpty
              ? const Center(
                  child: Text('No upcoming events',
                      style: TextStyle(color: AppColors.textFaint)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                  children: _buildGroupedList(),
                ),
    );
  }

  List<Widget> _buildGroupedList() {
    final widgets = <Widget>[];
    String? lastLabel;
    for (final ev in _events) {
      final scheduledAt =
          DateTime.tryParse(ev['scheduledAt']?.toString() ?? '');
      final label = scheduledAt != null ? _dayLabel(scheduledAt) : 'Later';
      if (label != lastLabel) {
        lastLabel = label;
        widgets.add(Padding(
          padding: EdgeInsets.fromLTRB(0, widgets.isEmpty ? 0 : 18, 0, 10),
          child: Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
        ));
      }
      widgets.add(_row(ev, scheduledAt));
    }
    return widgets;
  }

  Widget _row(Map<String, dynamic> ev, DateTime? scheduledAt) {
    final roomId = ev['id'] as String;
    final style =
        _kRoomTypeStyles[ev['roomType']] ?? _kRoomTypeStyles['watch']!;
    final remindMe = ev['remindMe'] == true;
    final toggling = _toggling.contains(roomId);
    final timeStr =
        scheduledAt != null ? DateFormat.jm().format(scheduledAt) : '';
    final timeParts = timeStr.split(' ');

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              constraints: const BoxConstraints(minWidth: 46),
              decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timeParts.isNotEmpty ? timeParts[0] : '',
                      style: const TextStyle(
                          color: AppColors.accent2,
                          fontWeight: FontWeight.w800,
                          fontSize: 17)),
                  if (timeParts.length > 1)
                    Text(timeParts[1],
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: style.colors)),
              alignment: Alignment.center,
              child: Icon(style.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev['title'] as String? ?? '',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                        'Hosted by ${ev['hostName'] ?? ''} · ${style.label}',
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: toggling ? null : () => _toggleRemind(roomId),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.accent2, width: 1.5),
                  color: remindMe
                      ? AppColors.accent2.withValues(alpha: 0.16)
                      : null,
                ),
                child: Text(remindMe ? 'Reminding' : 'Remind',
                    style: const TextStyle(
                        color: AppColors.accent2,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
