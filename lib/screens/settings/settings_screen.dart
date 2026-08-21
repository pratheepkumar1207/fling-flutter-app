import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';
import 'blocked_accounts_screen.dart';
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
      await ApiClient.patch('/auth/me', body: {'pushNotificationsEnabled': value});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingNotifications = false);
    }
  }

  Future<void> _toggleLocation(bool value) async {
    setState(() => _savingLocation = true);
    try {
      await ApiClient.patch('/auth/me', body: {'locationSharingEnabled': value});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
        children: [
          _group('Privacy & Safety'),
          _tile(context, emoji: '🚫', label: 'Blocked accounts', builder: (_) => const BlockedAccountsScreen()),
          _switchTile(
            emoji: '📍',
            label: 'Location sharing',
            value: locationEnabled,
            onChanged: _savingLocation ? null : _toggleLocation,
          ),
          _group('Preferences'),
          _switchTile(
            emoji: '🔔',
            label: 'Notifications',
            value: notificationsEnabled,
            onChanged: _savingNotifications ? null : _toggleNotifications,
          ),
          _tile(context, emoji: '🌐', label: 'Language', builder: (_) => const LanguagePreferencesScreen()),
          _group('Support'),
          _tile(context, emoji: '🆘', label: 'Help Center', builder: (_) => const HelpCenterScreen()),
          _tile(context, emoji: '📄', label: 'Terms of Service', builder: (_) => const LegalScreen(title: 'Terms of Service', body: kTermsOfServicePlaceholder)),
          _tile(context, emoji: '🛡️', label: 'Privacy Policy', builder: (_) => const LegalScreen(title: 'Privacy Policy', body: kPrivacyPolicyPlaceholder)),
          _tile(context, emoji: 'ℹ️', label: 'About Us', builder: (_) => const LegalScreen(title: 'About Us', body: 'This app connects people through shared watch parties, voice rooms, and social discovery.\n\nVersion 1.0.0')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Text(title.toUpperCase(), style: const TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );

  Widget _iconBadge(String emoji) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 15)),
      );

  Widget _tile(BuildContext context, {required String emoji, required String label, required WidgetBuilder builder}) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          _iconBadge(emoji),
          const SizedBox(width: 13),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 13.5))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint, size: 18),
        ]),
      ),
    );
  }

  Widget _switchTile({required String emoji, required String label, required bool value, required ValueChanged<bool>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        _iconBadge(emoji),
        const SizedBox(width: 13),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 13.5))),
        Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
      ]),
    );
  }
}
