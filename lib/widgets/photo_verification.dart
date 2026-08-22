import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';
import 'app_image.dart';

const _kStatusLabel = {
  'pending': ['Pending review', AppColors.gold],
  'verified': ['Verified', AppColors.success],
  'rejected': ['Rejected — try again', AppColors.danger],
};

/// Full-screen selfie capture/status flow — manual-review "blue check", no
/// liveness/face-match provider integrated; a real admin/mod compares the
/// submitted selfie against the profile photos. Matches
/// PhotoVerificationDark.dc.html: a dashed viewfinder frame (showing the
/// last-submitted selfie once there is one), title/description, a status
/// pill, and a pinned "Take/Retake a selfie" CTA — retaking stays
/// available even while a submission is pending review, same as the
/// mockup shows both at once.
class PhotoVerificationScreen extends StatefulWidget {
  final String status;
  final String? selfieUrl;
  final VoidCallback? onSubmitted;

  const PhotoVerificationScreen(
      {super.key, required this.status, this.selfieUrl, this.onSubmitted});

  @override
  State<PhotoVerificationScreen> createState() =>
      _PhotoVerificationScreenState();
}

class _PhotoVerificationScreenState extends State<PhotoVerificationScreen> {
  bool _submitting = false;
  String? _localSelfieUrl;

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final dataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';
    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.post('/verify-photo/submit',
          body: {'selfieDataUri': dataUri});
      if (mounted) {
        setState(() => _localSelfieUrl = dataUri);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Selfie submitted — we'll review it shortly.")));
      }
      widget.onSubmitted?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit selfie')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selfieUrl = _localSelfieUrl ?? widget.selfieUrl;
    final everSubmitted = widget.status != 'none' || selfieUrl != null;
    final statusInfo =
        _kStatusLabel[_localSelfieUrl != null ? 'pending' : widget.status];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Photo verification')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 220,
                    height: 280,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: selfieUrl != null
                        ? AppImage(source: selfieUrl, fit: BoxFit.cover)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.center_focus_weak_rounded,
                                  color: AppColors.textFaint, size: 52),
                              const SizedBox(height: 12),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text('Center your face in the frame',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 12.5)),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text('Take a quick selfie',
                      style: GoogleFonts.bricolageGrotesque(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 19)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "A real person on our team reviews it and compares it to your profile photos — no AI, no face data stored.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12.5,
                          height: 1.6),
                    ),
                  ),
                  if (statusInfo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              (statusInfo[1] as Color).withValues(alpha: 0.12),
                          border: Border.all(
                              color: (statusInfo[1] as Color)
                                  .withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded,
                                color: statusInfo[1] as Color, size: 14),
                            const SizedBox(width: 8),
                            Text(statusInfo[0] as String,
                                style: TextStyle(
                                    color: statusInfo[1] as Color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
            child: GestureDetector(
              onTap: _submitting ? null : _takeSelfie,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: _submitting
                      ? null
                      : const LinearGradient(colors: AppGradients.brand),
                  color: _submitting ? AppColors.surface2 : null,
                  boxShadow: _submitting
                      ? null
                      : [
                          BoxShadow(
                              color: AppColors.accent2.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 10))
                        ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _submitting
                      ? 'Submitting…'
                      : (everSubmitted ? 'Retake selfie' : 'Take a selfie'),
                  style: TextStyle(
                      color: _submitting ? AppColors.textFaint : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact status row for ProfileScreen's main list — taps through to
/// PhotoVerificationScreen for the actual capture/status flow.
class PhotoVerificationEntry extends StatelessWidget {
  final String status;
  final String? selfieUrl;
  final VoidCallback? onSubmitted;

  const PhotoVerificationEntry(
      {super.key, required this.status, this.selfieUrl, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final info = _kStatusLabel[status];
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PhotoVerificationScreen(
            status: status, selfieUrl: selfieUrl, onSubmitted: onSubmitted),
      )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            const Icon(Icons.face_retouching_natural_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Photo verification',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600))),
            Text(info?[0] as String? ?? 'Not verified',
                style: TextStyle(
                    color: (info?[1] as Color?) ?? AppColors.textFaint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textFaint, size: 18),
          ],
        ),
      ),
    );
  }
}
