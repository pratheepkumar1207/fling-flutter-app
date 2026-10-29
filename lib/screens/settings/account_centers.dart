import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/in_icon_button.dart';
import '../../widgets/photo_verification.dart';
import '../../widgets/spinner.dart';
import '../auth/safety_guidelines_screen.dart';
import '../wallet/wallet_kyc_screen.dart';
import 'blocked_accounts_screen.dart';
import 'help_center_screen.dart';
import 'privacy_screen.dart';

// Safety centre, Privacy centre, Security and Verification — each backed
// by the real settings (GET/PATCH /auth/me, /account/*, /social/blocklist).

Future<Map<String, dynamic>> _me() async {
  final d = await ApiClient.get('/auth/me') as Map<String, dynamic>;
  return Map<String, dynamic>.from((d['user'] ?? d) as Map);
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

class _Scaffold extends StatelessWidget {
  final String title;
  final Widget body;
  const _Scaffold({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          leading: InIconButton(InIcons.back,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop()),
          title: Text(title),
        ),
        body: body,
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  final InIconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? color;
  final VoidCallback? onTap;
  const _Row(this.icon, this.title,
      {this.subtitle, this.value, this.color, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: InIcon(icon, size: 20, color: color ?? AppColors.lilac),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                color: color ?? AppColors.text)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null)
            Text(value!,
                style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          if (onTap != null && color == null) ...[
            const SizedBox(width: 4),
            const InIcon(InIcons.right, size: 16, color: AppColors.textDim),
          ],
        ]),
      );
}

/// A banner with a big icon, a title and a line under it.
class _Hero extends StatelessWidget {
  final InIconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _Hero(this.icon, this.title, this.subtitle,
      {this.color = AppColors.success});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16)),
            child: Center(child: InIcon(icon, size: 24, color: color)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 13)),
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- Safety

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});
  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  Map<String, dynamic>? _me_;
  int _blocked = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _me();
      final blocked = await ApiClient.get('/social/blocklist');
      if (!mounted) return;
      setState(() {
        _me_ = me;
        _blocked = blocked is List ? blocked.length : 0;
      });
    } catch (_) {
      if (mounted) setState(() => _me_ = {});
    }
  }

  Future<void> _toggleHiddenWords() async {
    final on = _me_!['hiddenWordsEnabled'] != false;
    setState(() => _me_ = {..._me_!, 'hiddenWordsEnabled': !on});
    try {
      await ApiClient.patch('/auth/me', body: {'hiddenWordsEnabled': !on});
    } catch (_) {
      if (mounted) setState(() => _me_ = {..._me_!, 'hiddenWordsEnabled': on});
    }
  }

  Future<void> _editHiddenWords() async {
    final words = ((_me_!['hiddenWords'] as List?) ?? []).cast<String>();
    final c = TextEditingController(text: words.join(', '));
    final out = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hidden words'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Comments and message requests with these words are hidden from you. Common offensive words are always hidden while this is on.',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 10),
          TextField(
              controller: c,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Words, separated by commas')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(c.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (out == null) return;
    final list = out
        .split(',')
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.isNotEmpty)
        .toList();
    try {
      await ApiClient.patch('/auth/me', body: {'hiddenWords': list});
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final me = _me_;
    final verified = me != null &&
        (me['isVerified'] == true ||
            me['photoVerificationStatus'] == 'verified');
    final hiddenOn = me?['hiddenWordsEnabled'] != false;
    return _Scaffold(
      title: 'Safety Center',
      body: me == null
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                  _Hero(
                      InIcons.shield,
                      verified ? 'You’re protected' : 'Get more protected',
                      [
                        verified ? 'Verified' : 'Not verified yet',
                        if ((me['phone'] as String?)?.isNotEmpty == true)
                          'Phone sign in on',
                      ].join(' · '),
                      color: verified ? AppColors.success : AppColors.gold),
                  const SizedBox(height: 14),
                  _Card([
                    _Row(InIcons.help, 'Report a problem',
                        onTap: () => _push(context, const HelpCenterScreen())),
                    _Row(InIcons.block, 'Blocked accounts',
                        value: '$_blocked',
                        onTap: () =>
                            _push(context, const BlockedAccountsScreen())),
                    _Row(InIcons.lock, 'Limit who can contact you',
                        onTap: () => _push(context, const PrivacyScreen())),
                    ListTile(
                      leading: const InIcon(InIcons.eyeoff,
                          size: 20, color: AppColors.lilac),
                      title: const Text('Hidden words',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14.5)),
                      subtitle: const Text('Tap to add your own words',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                      onTap: _editHiddenWords,
                      trailing: Switch(
                          value: hiddenOn,
                          onChanged: (_) => _toggleHiddenWords(),
                          activeThumbColor: AppColors.primary),
                    ),
                    _Row(InIcons.verified, 'Identity verification',
                        subtitle: 'Build trust',
                        onTap: () =>
                            _push(context, const VerificationScreen())),
                    _Row(InIcons.doc, 'Safety guidelines',
                        onTap: () => _push(context,
                            const SafetyGuidelinesScreen(previewOnly: true))),
                  ]),
                  const _Label('GET URGENT HELP'),
                  _Card([
                    _Row(InIcons.chat, 'Support',
                        onTap: () => _push(context, const HelpCenterScreen())),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2A1018),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF5A2030))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('In danger right now?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 4),
                          const Text('Call emergency services on 112',
                              style: TextStyle(
                                  color: AppColors.textDim, fontSize: 13)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => launchUrl(Uri.parse('tel:112')),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                minimumSize: const Size.fromHeight(46)),
                            icon: const InIcon(InIcons.phone,
                                size: 18, color: Colors.white),
                            label: const Text('Call 112'),
                          ),
                        ]),
                  ),
                ]),
    );
  }
}

// --------------------------------------------------------------- Privacy

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});
  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  Map<String, dynamic>? _u;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _me();
      if (mounted) setState(() => _u = me);
    } catch (_) {
      if (mounted) setState(() => _u = {});
    }
  }

  Future<void> _set(String key, dynamic value) async {
    final before = _u![key];
    setState(() => _u = {..._u!, key: value});
    try {
      await ApiClient.patch('/auth/me', body: {key: value});
      if (key == 'friendsOnlyAccount') _load();
      if (mounted) context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _u = {..._u!, key: before});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final data = await ApiClient.get('/account/export');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/insync-data.json');
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles([XFile(file.path)], text: 'My Insync data');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t prepare your data')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Your profile, followers and sign-ins are removed and can’t be brought back. Coins and diamonds are lost. Type DELETE to confirm.',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 10),
          TextField(controller: c, autofocus: true),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(c.text.trim() == 'DELETE'),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.delete('/account', body: {'confirm': 'DELETE'});
      if (!mounted) return;
      await context.read<AuthProvider>().clearSession();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _u;
    String activity(String? v) => switch (v) {
          'friends' => 'Friends',
          'nobody' => 'Nobody',
          _ => 'Everyone',
        };
    return _Scaffold(
      title: 'Privacy centre',
      body: u == null
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                  _Card([
                    SwitchListTile(
                      value: u['friendsOnlyAccount'] == true,
                      onChanged: (v) => _set('friendsOnlyAccount', v),
                      activeThumbColor: AppColors.primary,
                      secondary: const InIcon(InIcons.lock,
                          size: 20, color: AppColors.lilac),
                      title: const Text('Friends only account',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Only friends see your posts and rooms',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ),
                    SwitchListTile(
                      value: u['allowSharing'] == true,
                      onChanged: (v) => _set('allowSharing', v),
                      activeThumbColor: AppColors.primary,
                      secondary: const InIcon(InIcons.send,
                          size: 20, color: AppColors.lilac),
                      title: const Text('Let others share my posts',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Off: no one can share, repost or add your posts to their story. Screenshots are always blocked in Insync.',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ),
                  ]),
                  const _Label('QUICK CHECK'),
                  _Card([
                    SwitchListTile(
                      value: u['hideOnlineStatus'] != true,
                      onChanged: (v) => _set('hideOnlineStatus', !v),
                      activeThumbColor: AppColors.primary,
                      title: const Text('Online status'),
                      subtitle: Text(
                          u['hideOnlineStatus'] == true ? 'Hidden' : 'Visible',
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ),
                    _Row(InIcons.live, 'Room I’m in',
                        value: activity(u['roomActivityVisibility'] as String?),
                        onTap: () => _push(context, const PrivacyScreen())),
                    SwitchListTile(
                      value: u['locationSharingEnabled'] == true,
                      onChanged: (v) => _set('locationSharingEnabled', v),
                      activeThumbColor: AppColors.primary,
                      title: const Text('Location'),
                      subtitle: Text(
                          u['locationSharingEnabled'] == true ? 'On' : 'Off',
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ),
                    SwitchListTile(
                      value: u['showInDiscover'] != false,
                      onChanged: (v) => _set('showInDiscover', v),
                      activeThumbColor: AppColors.primary,
                      title: const Text('Appear in Discover'),
                      subtitle: Text(
                          u['showInDiscover'] != false ? 'On' : 'Off',
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ),
                  ]),
                  const _Label('YOUR DATA'),
                  _Card([
                    _Row(InIcons.arrowdn, 'Download your data',
                        value: _exporting ? 'Preparing…' : null,
                        onTap: _exporting ? null : _export),
                    SwitchListTile(
                      value: u['analyticsOptOut'] != true,
                      onChanged: (v) => _set('analyticsOptOut', !v),
                      activeThumbColor: AppColors.primary,
                      title: const Text('Ad and analytics choices'),
                      subtitle: const Text(
                          'Let Insync use how you use the app to improve it',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ),
                    _Row(InIcons.tune, 'Privacy settings',
                        onTap: () => _push(context, const PrivacyScreen())),
                  ]),
                  const SizedBox(height: 14),
                  _Card([
                    _Row(InIcons.close, 'Delete my account',
                        color: AppColors.danger, onTap: _delete),
                  ]),
                ]),
    );
  }
}

// -------------------------------------------------------------- Security

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  Map<String, dynamic>? _u;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _me();
      final s = await ApiClient.get('/account/sessions') as List;
      if (!mounted) return;
      setState(() {
        _u = me;
        _sessions = s.cast<Map>().map(Map<String, dynamic>.from).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _u = {});
    }
  }

  Future<void> _signOut(Map<String, dynamic> s) async {
    try {
      await ApiClient.delete('/account/sessions/${s['id']}');
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _endOthers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('End all other sessions?'),
        content: const Text('Every other phone and browser is signed out.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('End sessions')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.post('/account/sessions/end-others');
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Other sessions ended')));
      }
    } catch (_) {}
  }

  static String _mask(String? phone) {
    if (phone == null || phone.length < 4) return 'Not added';
    final cc = phone.startsWith('+91') ? '+91 ' : '';
    return '$cc••• ${phone.substring(phone.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final u = _u;
    final hasPhone = (u?['phone'] as String?)?.isNotEmpty == true;
    return _Scaffold(
      title: 'Security',
      body: u == null
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                  _Card([
                    _Row(InIcons.phone, 'Phone number',
                        value: _mask(u['phone'] as String?)),
                    _Row(InIcons.globe, 'Google account',
                        value: u['googleLinked'] == true
                            ? 'Connected'
                            : 'Not linked'),
                    _Row(InIcons.lock, '2-step sign in',
                        subtitle: hasPhone
                            ? 'New sign-ins need a code sent to your phone'
                            : 'Add a phone number to get sign-in codes',
                        value: hasPhone ? 'On' : 'Off'),
                  ]),
                  const _Label('ACTIVE DEVICES'),
                  _Card([
                    for (final s in _sessions)
                      ListTile(
                        leading: InIcon(
                            s['current'] == true
                                ? InIcons.phone
                                : InIcons.globe,
                            size: 20,
                            color: AppColors.lilac),
                        title: Text(
                            s['current'] == true
                                ? '${s['device']} · this phone'
                                : '${s['device']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            s['current'] == true
                                ? 'Active now'
                                : 'Last active ${formatRelativeTime(DateTime.tryParse('${s['lastActiveAt'] ?? s['signedInAt']}') ?? DateTime.now())}',
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                        trailing: s['current'] == true
                            ? null
                            : TextButton(
                                onPressed: () => _signOut(s),
                                child: const Text('Sign out')),
                      ),
                    if (_sessions.isEmpty)
                      const ListTile(
                          title: Text(
                              'Sign out and back in to see your devices',
                              style: TextStyle(color: AppColors.textDim))),
                  ]),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _endOthers,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: AppColors.danger),
                    child: const Text('End all other sessions'),
                  ),
                ]),
    );
  }
}

// ---------------------------------------------------------- Verification

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  Map<String, dynamic>? _v;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await ApiClient.get('/account/verification') as Map;
      if (mounted) setState(() => _v = Map<String, dynamic>.from(v));
    } catch (_) {
      if (mounted) setState(() => _v = {});
    }
  }

  Future<void> _applyCreator() async {
    try {
      await ApiClient.post('/account/creator-badge');
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You’ve got the Creator badge')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  static String _status(String? s) => switch (s) {
        'verified' || 'approved' => 'Done',
        'pending' || 'submitted' || 'in_review' => 'In review',
        'rejected' => 'Try again',
        _ => 'Start',
      };

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final user = context.watch<AuthProvider>().user;
    Widget status(String text, {bool done = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: done
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(999)),
          child: Text(text,
              style: TextStyle(
                  color: done ? AppColors.success : AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        );
    Widget row(InIconData icon, String title, String sub, Widget trailing,
            {VoidCallback? onTap}) =>
        ListTile(
          onTap: onTap,
          leading: InIcon(icon, size: 20, color: AppColors.lilac),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          trailing: trailing,
        );
    return _Scaffold(
      title: 'Verification',
      body: v == null
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                  Center(
                    child: Column(children: [
                      Avatar(
                          src: user?.avatarUrl,
                          name: user?.name,
                          size: AvatarSize.lg),
                      const SizedBox(height: 10),
                      Text(user?.name ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Verified people get more matches',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  _Card([
                    row(
                        InIcons.phone,
                        'Phone number',
                        (v['phone'] as String?) ?? 'Not added',
                        status(v['phone'] != null ? 'Done' : 'Add',
                            done: v['phone'] != null)),
                    row(
                        InIcons.camera,
                        'Photo verification',
                        'Blue tick on your profile',
                        status(_status(v['photo'] as String?),
                            done: v['photo'] == 'verified'),
                        onTap: v['photo'] == 'verified'
                            ? null
                            : () => Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => PhotoVerificationScreen(
                                        status:
                                            v['photo'] as String? ?? 'none')))
                                .then((_) => _load())),
                    row(
                        InIcons.doc,
                        'ID verification',
                        'Needed for cash out and Creator badge',
                        status(_status(v['id'] as String?),
                            done: v['id'] == 'verified'),
                        onTap: v['id'] == 'verified'
                            ? null
                            : () => Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => const WalletKycScreen()))
                                .then((_) => _load())),
                    row(
                        InIcons.globe,
                        'Google account',
                        (v['email'] as String?) ?? 'Not linked',
                        status(v['google'] == true ? 'Linked' : 'Not linked',
                            done: v['google'] == true)),
                    row(
                        InIcons.badge,
                        'Creator badge',
                        'Needs ID and ${v['creatorMinFollowers'] ?? 500} followers · you have ${v['followers'] ?? 0}',
                        v['creatorBadge'] == true
                            ? status('Done', done: true)
                            : TextButton(
                                onPressed: _applyCreator,
                                child: const Text('Apply'))),
                  ]),
                ]),
    );
  }
}
