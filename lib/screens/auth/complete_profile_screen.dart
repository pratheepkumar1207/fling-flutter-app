import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/dynamic_options_cache.dart';
import '../../core/interest_options.dart';
import '../../core/language_options.dart';
import '../../models/photo.dart';
import '../../theme/app_colors.dart';
import '../../widgets/interest_picker.dart';
import '../../widgets/spinner.dart';

const _kMinGalleryPhotos = 5;

const _kLookingForOptions = [
  ['friends', '🤝 Friends'],
  ['explore', '✨ Explore'],
  ['short_term', '💫 Short-term relationship'],
  ['long_term', '💍 Long-term relationship'],
  ['not_sure', '🤔 Not sure yet'],
];

/// Shown right after login, before anything else — see SplashScreen, which
/// routes here instead of AppShell whenever auth.user.profileComplete is
/// false, and blocks every other screen until it's true. Dart port of
/// CompleteProfilePage.jsx.
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
  bool _ageConfirmed18 = false;
  List<Photo> _gallery = [];
  bool _galleryLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _interests = List<String>.from(user?.interests ?? []);
    _languages = List<String>.from(user?.languages ?? []);
    _lookingFor = user?.lookingFor ?? '';
    _ageController.text = user?.age?.toString() ?? '';
    _ageConfirmed18 = user?.ageConfirmed18 ?? false;
    _loadGallery();
    InterestOptionsCache.load().then((options) {
      if (mounted) setState(() => _interestOptions = options);
    });
  }

  int? get _age => int.tryParse(_ageController.text.trim());
  bool get _isAdult => _age != null && _age! >= 18;

  Future<void> _loadGallery() async {
    setState(() => _galleryLoading = true);
    try {
      final data = await ApiClient.get('/gallery/me');
      if (!mounted) return;
      setState(() {
        _gallery = (data as List).map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
        _galleryLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  bool get _canContinue =>
      _isAdult && _ageConfirmed18 && _interests.length >= kMinInterests && _lookingFor.isNotEmpty && _gallery.length >= _kMinGalleryPhotos;

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final dataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';
    try {
      await ApiClient.post('/gallery', body: {'imageData': dataUri});
      _loadGallery();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add photo')));
    }
  }

  Future<void> _deletePhoto(String id) async {
    try {
      await ApiClient.delete('/gallery/$id');
      _loadGallery();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove photo')));
    }
  }

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/auth/me', body: {
        'interests': _interests,
        'languages': _languages,
        'lookingFor': _lookingFor,
        'age': _age,
        'ageConfirmed18': _ageConfirmed18,
      });
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save your profile')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final galleryCount = _gallery.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text('Complete your profile', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Just a few details before you jump in.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDim, fontSize: 13)),
                const SizedBox(height: 24),

                const Text('Your age', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(hintText: 'Age', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  ),
                ),
                if (_ageController.text.isNotEmpty && !_isAdult)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('You must be at least 18 to use Insync.', style: TextStyle(color: AppColors.danger, fontSize: 11)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GestureDetector(
                    onTap: _isAdult ? () => setState(() => _ageConfirmed18 = !_ageConfirmed18) : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _ageConfirmed18,
                          onChanged: _isAdult ? (v) => setState(() => _ageConfirmed18 = v ?? false) : null,
                          activeColor: AppColors.primary,
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'I confirm I am 18 years or older and the information I\'ve provided is accurate.',
                              style: TextStyle(color: AppColors.textDim, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text('What are you looking for?', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final o in _kLookingForOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _lookingFor = o[0]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _lookingFor == o[0] ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _lookingFor == o[0] ? AppColors.accent : AppColors.border, width: _lookingFor == o[0] ? 1.5 : 1),
                        ),
                        child: Text(o[1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _lookingFor == o[0] ? AppColors.accent : AppColors.textDim)),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                Text('Your interests (${_interests.length}/$kMinInterests min)', style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InterestPicker(selected: _interests, onChanged: (v) => setState(() => _interests = v), options: _interestOptions),
                const SizedBox(height: 4),
                Text('Pick at least $kMinInterests — this helps match you with people who vibe with you.', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),

                const SizedBox(height: 16),
                const Text('Languages you speak (optional)', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InterestPicker(selected: _languages, onChanged: (v) => setState(() => _languages = v), options: kLanguageOptions),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gallery photos (${galleryCount.clamp(0, _kMinGalleryPhotos)}/$_kMinGalleryPhotos)', style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    TextButton(onPressed: _addPhoto, child: const Text('+ Add photo')),
                  ],
                ),
                const Text('Add at least 5 photos so people can get a real sense of you.', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                const SizedBox(height: 8),
                if (_galleryLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: Spinner(size: 20)))
                else if (galleryCount == 0)
                  const Text('No photos yet.', style: TextStyle(color: AppColors.textFaint, fontSize: 13))
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _gallery.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemBuilder: (context, i) {
                      final p = _gallery[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              base64Decode(p.imageData.split(',').last),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _deletePhoto(p.id),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Icon(Icons.close, size: 13, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 24),
                GestureDetector(
                  onTap: (_canContinue && !_saving) ? _continue : null,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: (_canContinue && !_saving) ? const LinearGradient(colors: AppGradients.brand) : null,
                      color: (_canContinue && !_saving) ? null : AppColors.surface2,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _saving ? 'Saving…' : 'Continue',
                      style: TextStyle(color: (_canContinue && !_saving) ? Colors.white : AppColors.textFaint, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }
}
