import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';

/// Settings > Have an Issue — submits to POST /support/complaints; reviewed
/// by admins at /admin/complaints (see ComplaintsPage.jsx). Past submissions
/// are visible via MyComplaintsScreen.
class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  String _type = 'complaint';
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.post('/support/complaints', body: {
        'type': _type,
        'contact': _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
        'message': _messageController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted — thanks for letting us know.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Complaint / Suggestion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _typeChip('complaint', '⚠️ Complaint')),
                const SizedBox(width: 8),
                Expanded(child: _typeChip('suggestion', '💡 Suggestion')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Contact details (optional)', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _contactController,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'Enter mobile number or e-mail address'),
            ),
            const SizedBox(height: 16),
            const Text('Message', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 6,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'Tell us what happened…'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Submitting…' : 'Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textDim, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
