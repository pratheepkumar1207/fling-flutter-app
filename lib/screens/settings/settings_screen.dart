import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';
import 'complaint_form_screen.dart';
import 'language_preferences_screen.dart';
import 'legal_screen.dart';
import 'my_complaints_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _savingNotifications = false;

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            value: notificationsEnabled,
            onChanged: _savingNotifications ? null : _toggleNotifications,
            activeThumbColor: AppColors.primary,
            title: const Text('Notification', style: TextStyle(color: AppColors.text)),
            secondary: const Text('🔔', style: TextStyle(fontSize: 20)),
          ),
          const Divider(color: AppColors.border, height: 1),
          _tile(context, emoji: '💬', label: 'Have an Issue', builder: (_) => const ComplaintFormScreen()),
          _tile(context, emoji: '📋', label: 'My Complaints', builder: (_) => const MyComplaintsScreen()),
          _tile(context, emoji: '🌐', label: 'Select Language', builder: (_) => const LanguagePreferencesScreen()),
          _tile(context, emoji: '📄', label: 'Terms of Service', builder: (_) => const LegalScreen(title: 'Terms of Service', body: kTermsOfServicePlaceholder)),
          _tile(context, emoji: '🛡️', label: 'Privacy Policy', builder: (_) => const LegalScreen(title: 'Privacy Policy', body: kPrivacyPolicyPlaceholder)),
          _tile(context, emoji: 'ℹ️', label: 'About Us', builder: (_) => const LegalScreen(title: 'About Us', body: 'This app connects people through shared watch parties, voice rooms, and social discovery.\n\nVersion 1.0.0')),
          const Divider(color: AppColors.border, height: 1),
          ListTile(
            leading: const Text('🚪', style: TextStyle(fontSize: 20)),
            title: const Text('Log Out', style: TextStyle(color: AppColors.danger)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, {required String emoji, required String label, required WidgetBuilder builder}) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 20)),
      title: Text(label, style: const TextStyle(color: AppColors.text)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textFaint),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
    );
  }
}
