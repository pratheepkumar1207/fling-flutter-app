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
import '../../theme/insync_icons.dart';
import '../../widgets/interest_picker.dart';
import '../../widgets/spinner.dart';

const _kMinGalleryPhotos = 5;

const _kLookingForOptions = [
  ['long_term', 'Long-term'],
  ['short_term', 'Short-term'],
  ['friends', 'Friends'],
  ['explore', 'Explore'],
  ['not_sure', 'Not sure yet'],
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
        _gallery = (data as List)
            .map((e) => Photo.fromJson(e as Map<String, dynamic>))
            .toList();
        _galleryLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  bool get _canContinue =>
      _isAdult &&
      _ageConfirmed18 &&
      _interests.length >= kMinInterests &&
      _lookingFor.isNotEmpty &&
      _gallery.length >= _kMinGalleryPhotos;

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final dataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';
    try {
      await ApiClient.post('/gallery', body: {'imageData': dataUri});
      _loadGallery();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to add photo')));
      }
    }
  }

  Future<void> _deletePhoto(String id) async {
    try {
      await ApiClient.delete('/gallery/$id');
      _loadGallery();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove photo')));
      }
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
    final galleryCount = _gallery.length;
    // Always at least one empty slot, and enough to reach the minimum.
    final slots = (galleryCount + 1).clamp(6, 12);
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
                _sectionLabel(
                    'Photos · ${galleryCount.clamp(0, _kMinGalleryPhotos)}/$_kMinGalleryPhotos',
                    hint:
                        'Add at least $_kMinGalleryPhotos so people get a real sense of you.'),
                if (_galleryLoading)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Spinner(size: 20)))
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: slots,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.8),
                    itemBuilder: (context, i) => i < galleryCount
                        ? _photoTile(_gallery[i], main: i == 0)
                        : _addTile(),
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

  Widget _photoTile(Photo p, {required bool main}) {
    return Stack(fit: StackFit.expand, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(base64Decode(p.imageData.split(',').last),
            fit: BoxFit.cover),
      ),
      if (main)
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Main',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
      Positioned(
        top: 2,
        right: 2,
        child: Semantics(
          button: true,
          label: 'Remove photo',
          child: InkResponse(
            onTap: () => _deletePhoto(p.id),
            radius: 20,
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const InIcon(InIcons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _addTile() => Semantics(
        button: true,
        label: 'Add photo',
        child: InkWell(
          onTap: _addPhoto,
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _DashedBorder(),
            child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InIcon(InIcons.plus, size: 22, color: AppColors.textDim),
                  SizedBox(height: 4),
                  Text('Add photo',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                ]),
          ),
        ),
      );

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }
}

/// Dashed rounded outline for empty photo slots.
class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A3548)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(16)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
