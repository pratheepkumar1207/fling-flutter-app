import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';

const _kStatusLabel = {
  'none': ['Not verified', AppColors.textFaint],
  'pending': ['⏳ Pending review', AppColors.gold],
  'verified': ['✅ Verified', AppColors.success],
  'rejected': ['❌ Rejected — try again', AppColors.danger],
};

/// Manual-review "blue check" flow — Dart port of PhotoVerification.jsx.
/// No liveness/face-match provider is integrated; a real admin/mod compares
/// the submitted selfie against the profile photos.
class PhotoVerification extends StatefulWidget {
  final String status;
  final VoidCallback? onSubmitted;
  const PhotoVerification({super.key, required this.status, this.onSubmitted});

  @override
  State<PhotoVerification> createState() => _PhotoVerificationState();
}

class _PhotoVerificationState extends State<PhotoVerification> {
  bool _submitting = false;

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, imageQuality: 80);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final dataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';
    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.post('/verify-photo/submit', body: {'selfieDataUri': dataUri});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selfie submitted — we'll review it shortly.")));
      }
      widget.onSubmitted?.call();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit selfie')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _kStatusLabel[widget.status] ?? _kStatusLabel['none']!;
    final canSubmit = widget.status == 'none' || widget.status == 'rejected';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Photo verification', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(info[0] as String, style: TextStyle(color: info[1] as Color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          const Text("Take a selfie so people know it's really you. Reviewed by a real person.", style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          if (canSubmit) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _submitting ? null : _takeSelfie,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
              child: Text(_submitting ? 'Submitting…' : 'Take a selfie'),
            ),
          ],
        ],
      ),
    );
  }
}
