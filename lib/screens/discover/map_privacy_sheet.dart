import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/insync_icons.dart';
import 'discover_ui.dart';

/// "Who can see me": ghost mode (with a timer), who sees you on the map,
/// who sees which lobby you're in, and hiding your age on the map.
Future<void> showMapPrivacySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: DColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _PrivacySheet(),
  );
}

class _PrivacySheet extends StatefulWidget {
  const _PrivacySheet();
  @override
  State<_PrivacySheet> createState() => _PrivacySheetState();
}

class _PrivacySheetState extends State<_PrivacySheet> {
  late final _u = context.read<AuthProvider>().user;
  late bool _ghost =
      _u?.ghostUntil != null && _u!.ghostUntil!.isAfter(DateTime.now());
  int _ghostMinutes = 480; // 8 hours
  late String _mapTo = _u?.mapVisibility ?? 'everyone';
  late String _lobbyTo = _u?.roomActivityVisibility ?? 'everyone';
  late bool _hideAge = _u?.hideAgeOnMap ?? false;
  bool _saving = false;

  Future<void> _save(Map<String, dynamic> body) async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/auth/me', body: body);
      if (mounted) await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t save. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _options(List<(String, String)> opts, String value,
          void Function(String) pick) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts)
          DChip(o.$2,
              tone: value == o.$1 ? DTone.white : DTone.plain,
              fontSize: 13,
              onTap: () => pick(o.$1)),
      ]);

  @override
  Widget build(BuildContext context) {
    final until = context.watch<AuthProvider>().user?.ghostUntil;
    final forever = until != null && until.year >= 2900;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          Row(children: [
            const Expanded(
                child: Text('Who can see me',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            if (_saving)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: DColors.red)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: DColors.chip, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const InIcon(InIcons.eyeoff, size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ghost mode',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                          _ghost
                              ? forever
                                  ? 'Hidden until you turn it off'
                                  : until != null
                                      ? 'Hidden until ${TimeOfDay.fromDateTime(until.toLocal()).format(context)}'
                                      : 'Nobody sees you on the map'
                              : 'Nobody sees you on the map',
                          style: const TextStyle(
                              color: DColors.dim, fontSize: 12)),
                    ]),
              ),
              Switch(
                value: _ghost,
                activeTrackColor: DColors.red,
                activeThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFF333333),
                inactiveThumbColor: const Color(0xFF888888),
                onChanged: (v) {
                  setState(() => _ghost = v);
                  _save({'ghostMinutes': v ? _ghostMinutes : 0});
                },
              ),
            ]),
          ),
          const DLabel('Ghost mode turns off after'),
          _options(
              const [('60', '1 hour'), ('480', '8 hours'), ('-1', 'Never')],
              '$_ghostMinutes', (v) {
            setState(() => _ghostMinutes = int.parse(v));
            if (_ghost) _save({'ghostMinutes': _ghostMinutes});
          }),
          const DLabel('Show me on the map to'),
          _options(const [
            ('friends', 'Friends'),
            ('matches', 'Friends and matches'),
            ('everyone', 'Everyone')
          ], _mapTo, (v) {
            setState(() => _mapTo = v);
            _save({'mapVisibility': v});
          }),
          const DLabel('Show which lobby I’m in to'),
          _options(const [
            ('nobody', 'Nobody'),
            ('friends', 'Friends'),
            ('everyone', 'Everyone')
          ], _lobbyTo, (v) {
            setState(() => _lobbyTo = v);
            _save({'roomActivityVisibility': v});
          }),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(
                child: Text('Hide my age on the map',
                    style: TextStyle(fontSize: 14))),
            Switch(
              value: _hideAge,
              activeTrackColor: DColors.red,
              activeThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF333333),
              inactiveThumbColor: const Color(0xFF888888),
              onChanged: (v) {
                setState(() => _hideAge = v);
                _save({'hideAgeOnMap': v});
              },
            ),
          ]),
          const SizedBox(height: 6),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InIcon(InIcons.lock, size: 14, color: DColors.dim),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Only friends and matches see your exact spot. Everyone else sees your area, about 1 km.',
                  style:
                      TextStyle(color: DColors.dim, fontSize: 12, height: 1.4)),
            ),
          ]),
        ]),
      ),
    );
  }
}
