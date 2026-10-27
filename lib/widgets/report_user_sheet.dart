import '../theme/insync_icons.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const _kReportReasons = [
  'Spam or scam',
  'Fake profile',
  'Harassment or bullying',
  'Nudity or sexual content',
  'Hate speech',
  'Under 18',
  'Something else',
];

/// Report/Block bottom sheet — replaces two separate action-row buttons
/// with a single overflow entry point, matching the reference's dedicated
/// "Report User" sheet. Actual network calls + confirm dialogs stay owned
/// by the caller (see CreatorProfileScreen._report / ._block) — this sheet
/// is just the entry point UI.
void showReportUserSheet(
  BuildContext context, {
  required String userName,
  required VoidCallback onReport,
  required VoidCallback onBlock,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const InIcon(InIcons.flame, color: AppColors.danger),
              title: const Text('Report This User',
                  style: TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReport();
              },
            ),
            ListTile(
              leading: const InIcon(InIcons.block, color: AppColors.danger),
              title: const Text('Block This User',
                  style: TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onBlock();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Matches ReportUserDark.dc.html: a picker of report reasons (radio rows)
/// over a dimmed backdrop, with a danger "Submit report" button and a
/// plain "Cancel". Replaces the old flow, which sent a hardcoded
/// "Reported from profile" string with no reason ever actually collected.
void showReportReasonSheet(
  BuildContext context, {
  required String userName,
  required Future<void> Function(String reason) onSubmit,
  Future<void> Function()? onAlsoBlock,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _ReportReasonSheet(
        userName: userName, onSubmit: onSubmit, onAlsoBlock: onAlsoBlock),
  );
}

/// Pick a reason, add details if you like, optionally block them too.
class _ReportReasonSheet extends StatefulWidget {
  final String userName;
  final Future<void> Function(String reason) onSubmit;
  final Future<void> Function()? onAlsoBlock;

  const _ReportReasonSheet(
      {required this.userName, required this.onSubmit, this.onAlsoBlock});

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  String _selected = _kReportReasons.first;
  bool _submitting = false;
  bool _alsoBlock = false;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final details = _details.text.trim();
      await widget
          .onSubmit(details.isEmpty ? _selected : '$_selected: $details');
      if (_alsoBlock && widget.onAlsoBlock != null) await widget.onAlsoBlock!();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.userName.split(' ').first;
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99))),
                ),
                Text('Report ${widget.userName}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
                const SizedBox(height: 4),
                const Text(
                    'Your report is anonymous. If someone is in danger, call 112.',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                const SizedBox(height: 6),
                for (final reason in _kReportReasons)
                  Semantics(
                    selected: _selected == reason,
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => _selected = reason),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: reason == _kReportReasons.last
                                        ? Colors.transparent
                                        : AppColors.border))),
                        child: Row(children: [
                          Expanded(
                            child: Text(reason,
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _selected == reason
                                        ? AppColors.danger
                                        : AppColors.border,
                                    width: 2)),
                            alignment: Alignment.center,
                            child: _selected == reason
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.danger))
                                : null,
                          ),
                        ]),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                      hintText: 'Add details (optional)', counterText: ''),
                ),
                if (widget.onAlsoBlock != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _alsoBlock,
                    onChanged: (v) => setState(() => _alsoBlock = v),
                    activeThumbColor: AppColors.danger,
                    title: Text('Also block $first',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('They won’t be told',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 12)),
                  ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(50)),
                  child: Text(_submitting ? 'Submitting…' : 'Submit report',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textDim)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
