import '../../widgets/avatar.dart';
import '../experience/experience_hub.dart' show CreatorStudioScreen;
import '../wallet/livestream_dashboard_screen.dart';
import '../wallet/subscriptions_screen.dart';
import '../wallet/wallet_cashout_screen.dart';
import '../wallet/wallet_screen.dart';
import 'account_centers.dart';
import 'creator_account_screen.dart';
import 'my_subscriptions_screen.dart';
import 'room_moderation_screen.dart';
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
import '../../widgets/insync_snack.dart';

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
            insyncSnackBar(
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
            .showSnackBar(insyncSnackBar(content: Text(e.message)));
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
            .showSnackBar(insyncSnackBar(content: Text(e.message)));
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
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const EditProfileSheet())),
            child: Container(
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
                      const Text('Edit profile',
                          style: TextStyle(
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
              const SizedBox(width: 6),
              const InIcon(InIcons.chev, color: AppColors.textFaint, size: 18),
            ]),
          ),
          ),
          _group('Account'),
          _card([
            _tile(context,
                icon: InIcons.star,
                label: 'Account type',
                value: user?.isCreator == true
                    ? 'Creator${user?.creatorCategory == null ? '' : ' · ${user!.creatorCategory}'}'
                    : 'Personal',
                valueColor: user?.isCreator == true ? null : AppColors.lilac,
                builder: (_) => const CreatorAccountScreen()),
            _tile(context,
                icon: InIcons.verified,
                color: AppColors.blue,
                label: 'Verification',
                value: _verificationLabel(user?.photoVerificationStatus),
                valueColor: user?.photoVerificationStatus == 'verified'
                    ? AppColors.success
                    : null,
                builder: (_) => const VerificationScreen()),
            _tile(context,
                icon: InIcons.lock,
                label: 'Security',
                builder: (_) => const SecurityScreen()),
          ]),
          if (user?.isCreator == true) ...[
            _group('Creator'),
            _card([
              _tile(context,
                  icon: InIcons.live,
                  label: 'Going live',
                  value: switch (user?.livestreamStatus) {
                    'approved' => 'Approved',
                    'pending' => 'Under review',
                    'rejected' => 'Not approved',
                    _ => 'Apply',
                  },
                  builder: (_) => const CreatorAccountScreen()),
              _tile(context,
                  icon: InIcons.diamond,
                  label: 'Subscription levels',
                  builder: (_) => const SubscriptionsScreen()),
              _tile(context,
                  icon: InIcons.chart,
                  label: 'Creator Studio',
                  builder: (_) => const CreatorStudioScreen()),
              _tile(context,
                  icon: InIcons.cam,
                  label: 'Live dashboard',
                  builder: (_) => const LivestreamDashboardScreen()),
              _tile(context,
                  icon: InIcons.bank,
                  label: 'Payouts',
                  builder: (_) => const WalletCashoutScreen()),
            ]),
          ],
          _group('Privacy and safety'),
          _card([
            _tile(context,
                icon: InIcons.eye,
                label: 'Privacy centre',
                builder: (_) => const PrivacyCenterScreen()),
            _tile(context,
                icon: InIcons.lock,
                label: 'Room activity and likes',
                builder: (_) => const PrivacyScreen()),
            _tile(context,
                icon: InIcons.shield,
                label: 'Safety Center',
                builder: (_) => const SafetyCenterScreen()),
            _tile(context,
                icon: InIcons.block,
                label: 'Blocked accounts',
                builder: (_) => const BlockedAccountsScreen()),
          ]),
          _group('Subscriptions and money'),
          _card([
            _tile(context,
                icon: InIcons.diamond,
                label: 'My subscriptions',
                builder: (_) => const MySubscriptionsScreen()),
            _tile(context,
                icon: InIcons.wallet,
                label: 'Wallet',
                value: user?.coinBalance == null ? null : '${user!.coinBalance} coins',
                builder: (_) => const WalletScreen()),
          ]),
          _group('Rooms'),
          _card([
            _tile(context,
                icon: InIcons.tune,
                label: 'Room moderation',
                builder: (_) => const RoomModerationScreen()),
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
                label: 'About, privacy policy and terms',
                builder: (_) => Scaffold(
                      backgroundColor: AppColors.bg,
                      appBar: AppBar(title: const Text('About')),
                      body: ListView(children: [
                        for (final (label, page) in [
                          (
                            'About Us',
                            const LegalScreen(
                              title: 'About Us',
                              sections: [
                                LegalSection('Insync',
                                    'Watch parties, voice rooms, and social discovery — all in one app.'),
                                LegalSection('Version', '1.0.0'),
                                // Required credit for the animated emoji in chat.
                                LegalSection('Animated emoji',
                                    'Animated emoji by Google, Noto Emoji Animation, licensed under CC BY 4.0. https://googlefonts.github.io/noto-emoji-animation/'),
                              ],
                            )
                          ),
                          (
                            'Privacy Policy',
                            const LegalScreen(
                                title: 'Privacy Policy',
                                lastUpdated: 'January 2026',
                                sections: kPrivacyPolicySections)
                          ),
                          (
                            'Terms of Service',
                            const LegalScreen(
                                title: 'Terms of Service',
                                lastUpdated: 'January 2026',
                                sections: kTermsOfServiceSections)
                          ),
                          (
                            'Child safety standards',
                            const LegalScreen(
                                title: 'Child safety standards',
                                lastUpdated: 'November 2026',
                                sections: kChildSafetySections)
                          ),
                        ])
                          ListTile(
                            title: Text(label),
                            trailing: const InIcon(InIcons.chev,
                                color: AppColors.textFaint, size: 18),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => page)),
                          ),
                      ]),
                    )),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: const Color(0xFFFF5266),
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: Color(0xFF4A2227)),
            ),
            icon: const InIcon(InIcons.logout,
                size: 18, color: Color(0xFFFF5266)),
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
            if (i > 0) const Divider(height: 1, color: Color(0xFFFFFFFF)),
            rows[i],
          ],
        ]),
      );

  Widget _iconBadge(InIconData icon, Color color) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: const Color(0xFF000000),
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
              flex: 2,
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 14))),
          if (value != null) ...[
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: valueColor ?? AppColors.textDim, fontSize: 13)),
            ),
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
