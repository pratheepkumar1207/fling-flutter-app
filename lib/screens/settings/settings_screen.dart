import '../../widgets/avatar.dart';
import '../../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/push_notifications.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'blocked_accounts_screen.dart';
import 'privacy_screen.dart';
import 'help_center_screen.dart';
import 'language_preferences_screen.dart';
import 'legal_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _savingNotifications = false;
  bool _savingLocation = false;

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _savingNotifications = true);
    try {
      // Turning it on is also the one place in the app that actually
      // requests the OS notification permission and registers the FCM
      // token (see push_notifications.dart) — the preference flag alone
      // doesn't get anyone a push if the device was never asked.
      if (value) {
        final result = await requestPushPermissionAndRegister();
        if (result == PushRequestResult.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Notifications blocked — enable them for this app in your device settings.')),
          );
        }
      }
      await ApiClient.patch('/auth/me',
          body: {'pushNotificationsEnabled': value});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _savingNotifications = false);
    }
  }

  Future<void> _toggleLocation(bool value) async {
    setState(() => _savingLocation = true);
    try {
      await ApiClient.patch('/auth/me',
          body: {'locationSharingEnabled': value});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _savingLocation = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final notificationsEnabled = user?.pushNotificationsEnabled ?? true;
    final locationEnabled = user?.locationSharingEnabled ?? false;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Avatar(
                  src: user?.avatarUrl,
                  name: user?.name,
                  size: AvatarSize.md,
                  ring: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      if (user?.phone != null && user!.phone!.isNotEmpty)
                        Text(user.phone!,
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                    ]),
              ),
              if (user?.isVip == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('VIP',
                      style: TextStyle(
                          color: Color(0xFF2A1E00),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          _group('Account'),
          _card([
            _tile(context,
                icon: InIcons.user,
                label: 'Edit profile',
                builder: (_) => const EditProfileSheet()),
            _tile(context,
                icon: InIcons.verified,
                color: AppColors.blue,
                label: 'Verification',
                value: _verificationLabel(user?.photoVerificationStatus),
                valueColor: user?.photoVerificationStatus == 'verified'
                    ? AppColors.success
                    : null,
                builder: (_) => const ProfileScreen()),
            _tile(context,
                icon: InIcons.lock,
                label: 'Room activity and likes',
                builder: (_) => const PrivacyScreen()),
            _tile(context,
                icon: InIcons.block,
                label: 'Blocked accounts',
                builder: (_) => const BlockedAccountsScreen()),
          ]),
          _group('App'),
          _card([
            _switchTile(
              icon: InIcons.bell,
              label: 'Notifications',
              value: notificationsEnabled,
              onChanged: _savingNotifications ? null : _toggleNotifications,
            ),
            _switchTile(
              icon: InIcons.pin,
              label: 'Location sharing',
              value: locationEnabled,
              onChanged: _savingLocation ? null : _toggleLocation,
            ),
            _tile(context,
                icon: InIcons.lang,
                label: 'Language',
                builder: (_) => const LanguagePreferencesScreen()),
          ]),
          _group('Support'),
          _card([
            _tile(context,
                icon: InIcons.help,
                label: 'Help Center',
                builder: (_) => const HelpCenterScreen()),
            _tile(context,
                icon: InIcons.info,
                label: 'About Us',
                builder: (_) => const LegalScreen(
                      title: 'About Us',
                      sections: [
                        LegalSection('Insync',
                            'Watch parties, voice rooms, and social discovery — all in one app.'),
                        LegalSection('Version', '1.0.0'),
                      ],
                    )),
            _tile(context,
                icon: InIcons.doc,
                label: 'Privacy Policy',
                builder: (_) => const LegalScreen(
                    title: 'Privacy Policy',
                    lastUpdated: 'January 2026',
                    sections: kPrivacyPolicySections)),
            _tile(context,
                icon: InIcons.doc,
                label: 'Terms of Service',
                builder: (_) => const LegalScreen(
                    title: 'Terms of Service',
                    lastUpdated: 'January 2026',
                    sections: kTermsOfServiceSections)),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: const Color(0xFFFF8AA0),
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: Color(0xFF4A2230)),
            ),
            icon: const InIcon(InIcons.logout,
                size: 18, color: Color(0xFFFF8AA0)),
            label: const Text('Log out'),
          ),
          const SizedBox(height: 10),
          const Text('Insync 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
        ],
      ),
    );
  }

  String _verificationLabel(String? status) => switch (status) {
        'verified' => 'Verified',
        'pending' => 'Pending',
        'rejected' => 'Rejected',
        _ => 'Not verified',
      };

  Widget _group(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6)),
      );

  Widget _card(List<Widget> rows) => Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFF221F2C)),
            rows[i],
          ],
        ]),
      );

  Widget _iconBadge(InIconData icon, Color color) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: const Color(0xFF1F1A2C),
            borderRadius: BorderRadius.circular(11)),
        alignment: Alignment.center,
        child: InIcon(icon, size: 18, color: color),
      );

  Widget _tile(BuildContext context,
      {required InIconData icon,
      required String label,
      required WidgetBuilder builder,
      Color color = AppColors.lilac,
      String? value,
      Color? valueColor}) {
    return InkWell(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: builder)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          _iconBadge(icon, color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.text, fontSize: 14))),
          if (value != null) ...[
            Text(value,
                style: TextStyle(
                    color: valueColor ?? AppColors.textDim, fontSize: 13)),
            const SizedBox(width: 6),
          ],
          const InIcon(InIcons.chev, color: AppColors.textFaint, size: 18),
        ]),
      ),
    );
  }

  Widget _switchTile(
      {required InIconData icon,
      required String label,
      required bool value,
      required ValueChanged<bool>? onChanged}) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      secondary: _iconBadge(icon, AppColors.lilac),
      title: Text(label,
          style: const TextStyle(color: AppColors.text, fontSize: 14)),
    );
  }
}
