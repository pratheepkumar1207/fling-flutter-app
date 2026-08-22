import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const _kReportReasons = [
  'Harassment or bullying',
  'Fake profile',
  'Spam or scam',
  'Inappropriate content',
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
              leading: const Icon(Icons.flag_rounded, color: AppColors.danger),
              title: const Text('Report This User',
                  style: TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.danger),
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
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _ReportReasonSheet(userName: userName, onSubmit: onSubmit),
  );
}

class _ReportReasonSheet extends StatefulWidget {
  final String userName;
  final Future<void> Function(String reason) onSubmit;

  const _ReportReasonSheet({required this.userName, required this.onSubmit});

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  String _selected = _kReportReasons.first;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_selected);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
                "Your report is anonymous. We'll review it within 24 hours.",
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            const SizedBox(height: 6),
            for (final reason in _kReportReasons)
              GestureDetector(
                onTap: () => setState(() => _selected = reason),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: reason == _kReportReasons.last
                                  ? Colors.transparent
                                  : AppColors.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(reason,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5)),
                      Container(
                        width: 19,
                        height: 19,
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
                                width: 9.5,
                                height: 9.5,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.danger))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _submitting ? AppColors.surface2 : AppColors.danger),
                alignment: Alignment.center,
                child: Text(_submitting ? 'Submitting…' : 'Submit report',
                    style: TextStyle(
                        color: _submitting ? AppColors.textFaint : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: AppColors.textFaint,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
