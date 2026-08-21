import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

/// Matches KYCDark.dc.html: the info banner, "1. Government ID" and
/// "2. Selfie verification" upload cards (base64 data-URI submission, same
/// pattern as widgets/photo_verification.dart's blue-check flow), a submit
/// button, and the "Phone verified / Identity review" step list. The
/// mockup has no fields for payout details, but POST /kyc/submit still
/// needs PAN + bank account to actually pay a cash-out out — CashOutScreen
/// depends on this data — so those are kept as a third "Payout details"
/// section rather than dropped.
class WalletKycScreen extends StatefulWidget {
  const WalletKycScreen({super.key});

  @override
  State<WalletKycScreen> createState() => _WalletKycScreenState();
}

class _WalletKycScreenState extends State<WalletKycScreen> {
  bool _loading = true;
  String? _status;
  final _pan = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _accountHolder = TextEditingController();
  bool _submitting = false;

  String? _idPhotoDataUri;
  String? _selfieDataUri;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/kyc/status') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _status = data['status'] as String? ?? 'none';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _pickImage(ImageSource source,
      {CameraDevice device = CameraDevice.rear}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: source, preferredCameraDevice: device, imageQuality: 80);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    return 'data:image/$ext;base64,${base64Encode(bytes)}';
  }

  Future<void> _pickIdPhoto() async {
    final uri = await _pickImage(ImageSource.gallery);
    if (uri != null && mounted) setState(() => _idPhotoDataUri = uri);
  }

  Future<void> _pickSelfie() async {
    final uri =
        await _pickImage(ImageSource.camera, device: CameraDevice.front);
    if (uri != null && mounted) setState(() => _selfieDataUri = uri);
  }

  bool get _canSubmit =>
      _idPhotoDataUri != null &&
      _selfieDataUri != null &&
      _pan.text.trim().isNotEmpty &&
      _bankAccount.text.trim().isNotEmpty &&
      _ifsc.text.trim().isNotEmpty &&
      _accountHolder.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.post('/kyc/submit', body: {
        'panNumber': _pan.text.trim().toUpperCase(),
        'bankAccountNumber': _bankAccount.text.trim(),
        'ifsc': _ifsc.text.trim().toUpperCase(),
        'accountHolderName': _accountHolder.text.trim(),
        'idPhotoDataUri': _idPhotoDataUri,
        'selfieDataUri': _selfieDataUri,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Submitted for review')));
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _pan.dispose();
    _bankAccount.dispose();
    _ifsc.dispose();
    _accountHolder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit =
        _status == null || _status == 'none' || _status == 'rejected';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Verify your identity')),
      body: _loading
          ? const Center(child: Spinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: AppColors.success, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Required once before you can cash out coins. Reviewed by our team, not verified automatically — takes about 2 minutes.',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _stepLabel('1. Government ID'),
                _uploadCard(
                  icon: Icons.badge_outlined,
                  title: 'Upload a photo of your ID',
                  subtitle: "Passport, driver's license, or national ID",
                  dataUri: _idPhotoDataUri,
                  onTap: canEdit ? _pickIdPhoto : null,
                ),
                const SizedBox(height: 20),
                _stepLabel('2. Selfie verification'),
                _uploadCard(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'Take a quick selfie',
                  subtitle: 'Make sure your face is well-lit and clear',
                  dataUri: _selfieDataUri,
                  onTap: canEdit ? _pickSelfie : null,
                ),
                const SizedBox(height: 20),
                _stepLabel('3. Payout details'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      _field('PAN number', _pan, canEdit),
                      _field('Bank account number', _bankAccount, canEdit),
                      _field('IFSC', _ifsc, canEdit),
                      _field('Account holder name', _accountHolder, canEdit,
                          last: true),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (canEdit)
                  GestureDetector(
                    onTap: (_canSubmit && !_submitting) ? _submit : null,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: (_canSubmit && !_submitting)
                            ? const LinearGradient(colors: AppGradients.brand)
                            : null,
                        color: (_canSubmit && !_submitting)
                            ? null
                            : AppColors.surface2,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _submitting ? 'Submitting…' : 'Submit for review',
                        style: TextStyle(
                            color: (_canSubmit && !_submitting)
                                ? Colors.white
                                : AppColors.textFaint,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Container(
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border))),
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: [
                      _step(
                          colors: const [Color(0xFF43B966), Color(0xFF2C8A49)],
                          icon: Icons.check_rounded,
                          label: 'Phone verified'),
                      _step(
                        colors: _statusStepColors(),
                        icon:
                            _status == 'verified' ? Icons.check_rounded : null,
                        number: _status == 'verified' ? null : 2,
                        label: 'Identity review',
                        trailing: _statusLabel(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Color> _statusStepColors() {
    switch (_status) {
      case 'verified':
        return const [Color(0xFF43B966), Color(0xFF2C8A49)];
      case 'rejected':
        return const [Color(0xFFED4B43), Color(0xFFB93A34)];
      case 'pending':
        return const [Color(0xFFDBB155), Color(0xFFB98A3D)];
      default:
        return const [Color(0xFF676871), Color(0xFF4A4B54)];
    }
  }

  Widget? _statusLabel() {
    switch (_status) {
      case 'pending':
        return const Text('Pending',
            style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 11));
      case 'verified':
        return const Text('Verified',
            style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 11));
      case 'rejected':
        return const Text('Rejected',
            style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 11));
      default:
        return const Text('Not started',
            style: TextStyle(
                color: AppColors.textFaint,
                fontWeight: FontWeight.w700,
                fontSize: 11));
    }
  }

  Widget _stepLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _uploadCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required String? dataUri,
      required VoidCallback? onTap}) {
    final filled = dataUri != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: filled ? AppColors.success : AppColors.border, width: 1.5),
        ),
        child: Column(
          children: [
            if (filled)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(base64Decode(dataUri.split(',').last),
                    height: 90, fit: BoxFit.cover),
              )
            else
              Icon(icon, color: AppColors.textFaint, size: 26),
            const SizedBox(height: 10),
            Text(filled ? 'Selected — tap to change' : title,
                style: TextStyle(
                    color: filled ? AppColors.success : AppColors.textDim,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5)),
            if (!filled) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 10.5),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, bool enabled,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(
      {required List<Color> colors,
      IconData? icon,
      int? number,
      required String label,
      Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors)),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 14)
                : Text('$number',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: AppColors.text, fontSize: 12.5))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
