import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/language_options.dart';
import '../../theme/app_colors.dart';
import '../../widgets/interest_picker.dart';

/// Settings > Select Language — edits the same User.languages field the
/// Profile edit form's language picker does (see profile_screen.dart), just
/// surfaced as its own discoverable screen too, matching the reference's
/// dedicated Settings entry. No separate app-display-language/i18n system
/// exists yet (see task #32's scope check) — this is the real, working
/// "which languages do you speak" field, not a stub.
class LanguagePreferencesScreen extends StatefulWidget {
  const LanguagePreferencesScreen({super.key});

  @override
  State<LanguagePreferencesScreen> createState() => _LanguagePreferencesScreenState();
}

class _LanguagePreferencesScreenState extends State<LanguagePreferencesScreen> {
  late List<String> _languages;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _languages = List<String>.from(context.read<AuthProvider>().user?.languages ?? []);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/auth/me', body: {'languages': _languages});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Select Language'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Languages you speak', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(height: 12),
            InterestPicker(selected: _languages, onChanged: (v) => setState(() => _languages = v), options: kLanguageOptions),
          ],
        ),
      ),
    );
  }
}
