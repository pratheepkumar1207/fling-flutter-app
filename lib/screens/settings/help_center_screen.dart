import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/spinner.dart';

const _kTopics = ['Account & login', 'Payments', 'Safety concern', 'Bug report', 'Something else'];

/// Help Center / "Report a problem" — matches HelpCenterDark.dc.html.
/// Combines what used to be two separate Settings screens
/// (ComplaintFormScreen + MyComplaintsScreen) into one, since the design
/// shows the report form and past-reports history on the same screen.
/// The topic chips aren't a backend field (Complaint.type is a fixed
/// complaint/suggestion enum) — the chosen topic is prefixed onto the
/// message text instead, same as how other free-form context gets carried
/// in this app without a schema change.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _topic = _kTopics[0];
  final _messageController = TextEditingController();
  String? _screenshotDataUri;
  bool _submitting = false;
  bool _pastLoading = true;
  List<Map<String, dynamic>> _past = [];

  @override
  void initState() {
    super.initState();
    _loadPast();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPast() async {
    try {
      final data = await ApiClient.get('/support/complaints/mine');
      if (!mounted) return;
      setState(() {
        _past = (data as List).cast<Map<String, dynamic>>();
        _pastLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _pastLoading = false);
    }
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1080);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    if (!mounted) return;
    setState(() => _screenshotDataUri = 'data:image/$ext;base64,${base64Encode(bytes)}');
  }

  Future<void> _submit() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.post('/support/complaints', body: {
        'type': 'complaint',
        'message': '[$_topic] $text',
        if (_screenshotDataUri != null) 'attachmentUrl': _screenshotDataUri,
      });
      if (!mounted) return;
      _messageController.clear();
      setState(() => _screenshotDataUri = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted — thanks for letting us know.')));
      _loadPast();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Report a problem')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const Text('WHAT\'S THIS ABOUT?', style: TextStyle(color: AppColors.textDim, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kTopics.map((t) {
              final selected = _topic == t;
              return GestureDetector(
                onTap: () => setState(() => _topic = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 1.5 : 1),
                    color: selected ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
                  ),
                  child: Text(t, style: TextStyle(color: selected ? AppColors.accent : AppColors.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Text('DESCRIBE THE ISSUE', style: TextStyle(color: AppColors.textDim, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: TextField(
              controller: _messageController,
              maxLines: 5,
              minLines: 4,
              style: const TextStyle(color: AppColors.text, fontSize: 13.5),
              decoration: const InputDecoration(hintText: 'Tell us what happened, and when…', border: InputBorder.none, contentPadding: EdgeInsets.all(13)),
            ),
          ),
          const SizedBox(height: 18),
          const Text('ATTACH A SCREENSHOT', style: TextStyle(color: AppColors.textDim, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickScreenshot,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              clipBehavior: Clip.antiAlias,
              child: _screenshotDataUri != null
                  ? Image.memory(base64Decode(_screenshotDataUri!.split(',').last), fit: BoxFit.cover)
                  : const Icon(Icons.image_outlined, color: AppColors.textFaint, size: 22),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _submitting ? null : _submit,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _submitting ? null : const LinearGradient(colors: AppGradients.brand),
                color: _submitting ? AppColors.surface2 : null,
              ),
              alignment: Alignment.center,
              child: Text(_submitting ? 'Submitting…' : 'Submit report', style: TextStyle(color: _submitting ? AppColors.textFaint : Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 28),
          const Text('YOUR PAST REPORTS', style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          if (_pastLoading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Spinner(size: 20)))
          else if (_past.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nothing submitted yet.', style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)))
          else
            ..._past.map((c) {
              final resolved = c['status'] == 'resolved';
              final rawMessage = c['message'] as String? ?? '';
              final match = RegExp(r'^\[(.+?)\]\s*(.*)$', dotAll: true).firstMatch(rawMessage);
              final title = match?.group(1) ?? (c['type'] == 'suggestion' ? 'Suggestion' : 'Complaint');
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          Text('Submitted', style: const TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: (resolved ? AppColors.success : AppColors.warning).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                      child: Text(resolved ? 'Resolved' : 'Open', style: TextStyle(color: resolved ? AppColors.success : AppColors.warning, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
