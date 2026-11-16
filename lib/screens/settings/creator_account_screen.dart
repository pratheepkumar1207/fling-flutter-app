import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/spinner.dart';
import 'account_centers.dart';

/// Switch between a personal and a creator account. Creators can offer
/// Silver/Gold/Platinum subscriptions, post subscriber-only content and go
/// live once approved (switching sends the live application).
class CreatorAccountScreen extends StatefulWidget {
  const CreatorAccountScreen({super.key});

  @override
  State<CreatorAccountScreen> createState() => _CreatorAccountScreenState();
}

class _CreatorAccountScreenState extends State<CreatorAccountScreen> {
  Map<String, dynamic>? _data;
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = Map<String, dynamic>.from(
          await ApiClient.get('/creators/me/account') as Map);
      if (!mounted) return;
      setState(() {
        _data = d;
        _category ??= d['creatorCategory'] as String? ?? 'Music';
      });
    } catch (_) {
      if (mounted) setState(() => _data = const {});
    }
  }

  Future<void> _switch(String type) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    setState(() => _saving = true);
    try {
      await ApiClient.post('/creators/me/account',
          body: {'type': type, 'category': _category});
      await auth.refreshUser();
      await _load();
      messenger.showSnackBar(SnackBar(
          content: Text(type == 'creator'
              ? 'You’re a creator now. Going live is under review.'
              : 'Switched back to a personal account')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _benefit(InIconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InIcon(icon, size: 18, color: const Color(0xFFB9A7FF)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, height: 1.3))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final creator = d?['accountType'] == 'creator';
    final reqs = ((d?['requirements'] as List?) ?? const []).cast<Map>();
    final ready = reqs.isNotEmpty && reqs.every((r) => r['ok'] == true);
    final cats = ((d?['categories'] as List?) ?? const ['Music', 'Other'])
        .cast<String>();
    final live = d?['livestreamStatus'] as String?;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Creator account')),
      body: d == null
          ? const Center(child: Spinner())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF2A1E55), Color(0xFF3A1430)]),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(creator ? 'You’re a creator' : 'Earn from your fans',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _benefit(InIcons.diamond,
                          'Silver, Gold and Platinum subscriptions'),
                      _benefit(InIcons.lock,
                          'Subscriber-only posts, reels and rooms'),
                      _benefit(InIcons.live,
                          'Go live and get gifts (after approval)'),
                      _benefit(InIcons.chart,
                          'Creator Studio: insights and earnings'),
                    ]),
              ),
              if (creator) ...[
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const InIcon(InIcons.live, color: Colors.white),
                  title: const Text('Going live'),
                  trailing: Text(
                      switch (live) {
                        'approved' => 'Approved',
                        'pending' => 'Under review',
                        'rejected' => 'Not approved',
                        _ => 'Not applied',
                      },
                      style: TextStyle(
                          color: live == 'approved'
                              ? AppColors.success
                              : const Color(0xFFFAC775))),
                ),
              ],
              const SizedBox(height: 18),
              const Text('WHAT YOU NEED',
                  style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              for (final r in reqs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: InIcon(r['ok'] == true ? InIcons.check : InIcons.close,
                      color: r['ok'] == true
                          ? AppColors.success
                          : const Color(0xFFFF8AA0)),
                  title: Text('${r['label']}'),
                  trailing: r['ok'] == true
                      ? null
                      : TextButton(
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) => const VerificationScreen()))
                              .then((_) => _load()),
                          child: const Text('Add')),
                ),
              const SizedBox(height: 14),
              const Text('YOUR CATEGORY',
                  style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in cats)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ]),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _saving || (!creator && !ready)
                    ? null
                    : () => _switch('creator'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: Text(creator ? 'Save category' : 'Switch to creator'),
              ),
              const SizedBox(height: 6),
              if (creator)
                TextButton(
                  onPressed: _saving ? null : () => _switch('personal'),
                  child: const Text('Switch back to personal'),
                )
              else
                const Text('Free · switch back any time',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ]),
    );
  }
}
