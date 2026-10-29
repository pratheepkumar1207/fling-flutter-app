import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_provider.dart';
import '../../core/dynamic_options_cache.dart';
import '../../core/interest_options.dart';
import '../../core/language_options.dart';
import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/interest_picker.dart';

const _kLookingForOptions = [
  ['long_term', 'Long-term'],
  ['short_term', 'Short-term'],
  ['friends', 'Friends'],
  ['explore', 'Explore'],
  ['not_sure', 'Not sure yet'],
];

/// Shown right after login, before anything else — see SplashScreen, which
/// routes here instead of AppShell whenever auth.user.profileComplete is
/// false, and blocks every other screen until it's true. A profile picture,
/// your name and your @username are required, plus age, what you're
/// looking for and interests.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  List<String> _interests = [];
  List<String> _languages = [];
  List<List<String>> _interestOptions = kInterestOptions;
  String _lookingFor = '';
  final _ageController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _ageConfirmed18 = false;
  String? _avatar;
  String? _usernameError;
  bool _saving = false;

  static final _generated = RegExp(r'^user[a-z0-9]{6,}$');

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _interests = List<String>.from(user?.interests ?? []);
    _languages = List<String>.from(user?.languages ?? []);
    _lookingFor = user?.lookingFor ?? '';
    _ageController.text = user?.age?.toString() ?? '';
    _ageConfirmed18 = user?.ageConfirmed18 ?? false;
    _avatar = user?.avatarUrl;
    final name = user?.name ?? '';
    _nameController.text = name == 'Test User' ? '' : name;
    final handle = user?.username ?? '';
    _usernameController.text = _generated.hasMatch(handle) ? '' : handle;
    InterestOptionsCache.load().then((options) {
      if (mounted) setState(() => _interestOptions = options);
    });
  }

  int? get _age => int.tryParse(_ageController.text.trim());
  bool get _isAdult => _age != null && _age! >= 18;

  String get _handle => _usernameController.text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  bool get _canContinue =>
      _avatar != null &&
      _nameController.text.trim().length >= 2 &&
      _handle.length >= 3 &&
      _isAdult &&
      _ageConfirmed18 &&
      _interests.length >= kMinInterests &&
      _lookingFor.isNotEmpty;

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1080);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    if (mounted) {
      setState(() => _avatar = 'data:image/$ext;base64,${base64Encode(bytes)}');
    }
  }

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() {
      _saving = true;
      _usernameError = null;
    });
    try {
      await ApiClient.patch('/auth/me', body: {
        'name': _nameController.text.trim(),
        'username': _handle,
        if (_avatar != context.read<AuthProvider>().user?.avatarUrl)
          'avatarUrl': _avatar,
        'completeSetup': true,
        'interests': _interests,
        'languages': _languages,
        'lookingFor': _lookingFor,
        'age': _age,
        'ageConfirmed18': _ageConfirmed18,
      });
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
    } on ApiException catch (e) {
      if (mounted) {
        if (e.message.toLowerCase().contains('username')) {
          setState(() => _usernameError = e.message);
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save your profile')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                const Text('Complete your profile',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4)),
                const SizedBox(height: 4),
                const Text('Just a few details before you jump in.',
                    style: TextStyle(color: AppColors.textDim, fontSize: 14)),
                const SizedBox(height: 18),
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Add profile picture',
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(
                                color: _avatar == null
                                    ? AppColors.border
                                    : AppColors.primary,
                                width: 2),
                          ),
                          child: _avatar == null
                              ? const Center(
                                  child: InIcon(InIcons.camera,
                                      size: 30, color: AppColors.textDim))
                              : ClipOval(
                                  child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: Avatar(
                                          src: _avatar, size: AvatarSize.lg))),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                            child: const Center(
                                child: InIcon(InIcons.plus,
                                    size: 16, color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                      _avatar == null
                          ? 'Add a profile picture (required)'
                          : 'Tap to change',
                      style: const TextStyle(
                          color: AppColors.textFaint, fontSize: 12)),
                ),
                const SizedBox(height: 18),
                _sectionLabel('Your name'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.text, fontSize: 15),
                  decoration:
                      const InputDecoration(hintText: 'Name', counterText: ''),
                ),
                const SizedBox(height: 14),
                _sectionLabel('Your @username',
                    hint:
                        'Letters, numbers and _. You can change it once every 15 days.'),
                TextField(
                  controller: _usernameController,
                  maxLength: 30,
                  autocorrect: false,
                  onChanged: (_) => setState(() => _usernameError = null),
                  style: const TextStyle(color: AppColors.text, fontSize: 15),
                  decoration: InputDecoration(
                      hintText: 'username',
                      prefixText: '@',
                      counterText: '',
                      errorText: _usernameError),
                ),
                const SizedBox(height: 22),
                _sectionLabel('Your age'),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.text, fontSize: 15),
                  decoration: const InputDecoration(hintText: 'Age'),
                ),
                const SizedBox(height: 6),
                Text('You must be at least 18 to use Insync.',
                    style: TextStyle(
                        color: _ageController.text.isNotEmpty && !_isAdult
                            ? AppColors.danger
                            : AppColors.textFaint,
                        fontSize: 12)),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isAdult
                      ? () => setState(() => _ageConfirmed18 = !_ageConfirmed18)
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _ageConfirmed18,
                        onChanged: _isAdult
                            ? (v) =>
                                setState(() => _ageConfirmed18 = v ?? false)
                            : null,
                        activeColor: AppColors.primary,
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'I confirm I am 18 or older and what I’ve shared is accurate.',
                            style: TextStyle(
                                color: AppColors.textDim, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionLabel('What are you looking for?'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in _kLookingForOptions)
                    ChoiceChip(
                      label: Text(o[1]),
                      selected: _lookingFor == o[0],
                      showCheckmark: false,
                      labelStyle: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                              color: _lookingFor == o[0]
                                  ? Colors.white
                                  : AppColors.text,
                              fontWeight: FontWeight.w500),
                      onSelected: (_) => setState(() => _lookingFor = o[0]),
                    ),
                ]),
                const SizedBox(height: 22),
                _sectionLabel(
                    'Your interests · ${_interests.length}/$kMinInterests',
                    hint:
                        'Pick at least $kMinInterests so we can match you with people who vibe with you.'),
                InterestPicker(
                    selected: _interests,
                    onChanged: (v) => setState(() => _interests = v),
                    options: _interestOptions),
                const SizedBox(height: 22),
                _sectionLabel('Languages you speak (optional)'),
                InterestPicker(
                    selected: _languages,
                    onChanged: (v) => setState(() => _languages = v),
                    options: kLanguageOptions),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: FilledButton(
              onPressed: (_canContinue && !_saving) ? _continue : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(_saving ? 'Saving…' : 'Continue'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint,
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ],
        ]),
      );

  @override
  void dispose() {
    _ageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
