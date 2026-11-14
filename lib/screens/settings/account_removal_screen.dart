import 'package:flutter/material.dart';
import '../../widgets/insync_brand.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2 Dec", in the phone's own time.
String shortDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day} ${_months[local.month - 1]}';
}

/// Deactivate for now, or delete permanently after 30 days.
class AccountRemovalScreen extends StatefulWidget {
  final VoidCallback onExport;
  const AccountRemovalScreen({super.key, required this.onExport});

  @override
  State<AccountRemovalScreen> createState() => _AccountRemovalScreenState();
}

class _AccountRemovalScreenState extends State<AccountRemovalScreen> {
  bool _delete = false;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/account/status');
      if (mounted) setState(() => _status = Map.from(data as Map));
    } catch (_) {
      if (mounted) setState(() => _status = const {});
    }
  }

  Widget _option(String title, String body, bool value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _delete = value),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        _delete == value ? AppColors.lilac : AppColors.border)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body,
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 13)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Deactivate or delete')),
      body: SafeArea(
        child: status == null
            ? const Center(child: InsyncSpinner(size: 32))
            : ListView(padding: const EdgeInsets.all(16), children: [
                _option(
                    'Deactivate for now',
                    'Your profile, posts and stories are hidden. Log in any time to bring everything back.',
                    false),
                _option(
                    'Delete permanently',
                    'Deleted after 30 days. Log in before then to cancel.',
                    true),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _delete
                          ? _DeleteScreen(
                              status: status, onExport: widget.onExport)
                          : const _DeactivateScreen())),
                  child: const Text('Continue'),
                ),
              ]),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warn;
  const _Point(this.icon, this.text, {this.warn = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon,
              size: 20, color: warn ? AppColors.danger : AppColors.lilac),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.text, fontSize: 14))),
        ]),
      );
}

/// Sends the request. If the last login is too old, asks for a fresh one:
/// that's the OTP or Google check that proves it's really them.
Future<bool> _confirmedRequest(
    BuildContext context, Future<dynamic> Function() request) async {
  final messenger = ScaffoldMessenger.of(context);
  final auth = context.read<AuthProvider>();
  final navigator = Navigator.of(context);
  try {
    await request();
    return true;
  } on ApiException catch (e) {
    if (e.status != 428) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
    if (!context.mounted) return false;
    final again = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Log in again to confirm'),
        content: const Text(
            'To protect your account, log in again, then come back here within 10 minutes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Log in')),
        ],
      ),
    );
    if (again == true) {
      await auth.clearSession();
      navigator.popUntil((r) => r.isFirst);
    }
    return false;
  } catch (_) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Couldn’t do that. Try again.')));
    return false;
  }
}

class _DeactivateScreen extends StatefulWidget {
  const _DeactivateScreen();

  @override
  State<_DeactivateScreen> createState() => _DeactivateScreenState();
}

class _DeactivateScreenState extends State<_DeactivateScreen> {
  final _reason = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() => _working = true);
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final done = await _confirmedRequest(
        context,
        () => ApiClient.post('/account/deactivate',
            body: {'reason': _reason.text.trim()}));
    if (done) {
      await auth.clearSession();
      navigator.popUntil((r) => r.isFirst);
      return;
    }
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Deactivate account')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const _Point(
                Icons.visibility_off_outlined, 'People can’t find or see you'),
            const _Point(Icons.lock_outline, 'Nothing is deleted'),
            const _Point(
                Icons.savings_outlined, 'Coins and purchases stay safe'),
            const _Point(Icons.refresh_rounded, 'Log in to come back'),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              maxLength: 300,
              decoration: const InputDecoration(
                  hintText: 'Why are you leaving? (optional)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _working ? null : _go,
              child: Text(_working ? 'Deactivating…' : 'Deactivate'),
            ),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
          ]),
        ),
      );
}

class _DeleteScreen extends StatefulWidget {
  final Map<String, dynamic> status;
  final VoidCallback onExport;
  const _DeleteScreen({required this.status, required this.onExport});

  @override
  State<_DeleteScreen> createState() => _DeleteScreenState();
}

class _DeleteScreenState extends State<_DeleteScreen> {
  final _confirm = TextEditingController();
  bool _working = false;

  DateTime get _on => DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() => _working = true);
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final on = shortDate(_on);
    final done = await _confirmedRequest(context,
        () => ApiClient.delete('/account', body: {'confirm': 'DELETE'}));
    if (done) {
      await auth.clearSession();
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(SnackBar(
          content:
              Text('Your account will be deleted on $on. Log in to cancel.')));
      return;
    }
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final coins = (widget.status['coinBalance'] as num?)?.toInt() ?? 0;
    final vip = widget.status['isVip'] == true;
    final ready = _confirm.text.trim() == 'DELETE';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const _Point(Icons.delete_outline_rounded,
              'Posts, photos and profile go for good',
              warn: true),
          if (coins > 0)
            _Point(Icons.savings_outlined, 'Coins are lost: $coins left',
                warn: true),
          if (vip)
            const _Point(
                Icons.workspace_premium_outlined, 'VIP ends with no refund',
                warn: true),
          InkWell(
            onTap: widget.onExport,
            child: const _Point(
                Icons.download_rounded, 'Download your data first'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirm,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Type DELETE'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: ready && !_working ? _go : null,
            child: Text(_working ? 'Working…' : 'Delete on ${shortDate(_on)}'),
          ),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep my account')),
        ]),
      ),
    );
  }
}

/// Logged back in during the 30 days. Returns whether the account stays.
Future<bool> showDeletionPendingDialog(
    BuildContext context, DateTime on, int daysLeft) async {
  final keep = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (d) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Your account is set to be deleted on ${shortDate(on)}'),
        content:
            Text('$daysLeft days left. It’s hidden from everyone until then.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Continue deleting')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Keep my account')),
        ],
      ),
    ),
  );
  return keep == true;
}
