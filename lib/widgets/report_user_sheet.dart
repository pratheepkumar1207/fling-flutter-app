import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: AppColors.danger),
              title: const Text('Report This User', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.danger),
              title: const Text('Block This User', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
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
