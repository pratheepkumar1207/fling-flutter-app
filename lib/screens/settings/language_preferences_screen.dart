import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/language_options.dart';
import '../../theme/app_colors.dart';

// Native-script label for the 7 languages LanguagePreferencesDark.dc.html
// shows written out — the mockup is the source for these exact strings,
// so only languages it actually names get one; the rest of
// kLanguageOptions just shows its English name, same as before.
const _kNativeLabels = {
  'hindi': 'हिन्दी',
  'tamil': 'தமிழ்',
  'telugu': 'తెలుగు',
  'bengali': 'বাংলা',
  'marathi': 'मराठी',
  'kannada': 'ಕನ್ನಡ',
};

/// Settings > Select Language — edits the same User.languages field the
/// Profile edit form's language picker does (see profile_screen.dart), just
/// surfaced as its own discoverable screen too, matching the reference's
/// dedicated Settings entry. No separate app-display-language/i18n system
/// exists yet — this is the real, working "which languages do you speak"
/// field, not a stub. Matches LanguagePreferencesDark.dc.html's row-list
/// styling, but keeps a filled-checkmark indicator instead of the mockup's
/// plain radio dot: this field is genuinely multi-select (you can speak
/// more than one language), so a single-choice radio would misrepresent
/// what tapping a row actually does.
class LanguagePreferencesScreen extends StatefulWidget {
  const LanguagePreferencesScreen({super.key});

  @override
  State<LanguagePreferencesScreen> createState() =>
      _LanguagePreferencesScreenState();
}

class _LanguagePreferencesScreenState extends State<LanguagePreferencesScreen> {
  late List<String> _languages;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _languages =
        List<String>.from(context.read<AuthProvider>().user?.languages ?? []);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/auth/me', body: {'languages': _languages});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Language'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (var i = 0; i < kLanguageOptions.length; i++) _row(i),
        ],
      ),
    );
  }

  Widget _row(int i) {
    final code = kLanguageOptions[i][0];
    final english = kLanguageOptions[i][1];
    final native = _kNativeLabels[code];
    final selected = _languages.contains(code);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _languages.remove(code);
        } else {
          _languages.add(code);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: i == kLanguageOptions.length - 1
                        ? Colors.transparent
                        : AppColors.border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5),
                children: [
                  TextSpan(text: native ?? english),
                  if (native != null)
                    TextSpan(
                        text: '  $english',
                        style: const TextStyle(
                            color: AppColors.textFaint,
                            fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.accent2 : Colors.transparent,
                  border: Border.all(
                      color: selected ? AppColors.accent2 : AppColors.border,
                      width: 2)),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
