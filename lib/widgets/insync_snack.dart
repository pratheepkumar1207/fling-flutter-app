import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

/// The app's one pop-up notice (approved design A, Nov 2026): a black card
/// with a red outline, a red round icon, an optional bold title over the
/// message, and an action when there's a next step. Sits above the bottom
/// of the screen without covering the chat box.
///
/// Every `SnackBar(...)` in the app goes through this. The icon follows the
/// message: a tick for things that worked, a stop sign for refusals and
/// errors, an "i" otherwise.
SnackBar insyncSnackBar({
  Key? key,
  required Widget content,
  String? title,
  InIconData? icon,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
  // Kept so existing calls still work; the design fixes these.
  SnackBarBehavior? behavior,
  Color? backgroundColor,
}) {
  final text = content is Text ? (content.data ?? '') : '';
  final glyph = icon ?? _iconFor(text);
  return SnackBar(
    key: key,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.black,
    elevation: 0,
    duration: duration,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.primary, width: 1),
    ),
    action: action,
    content: Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: InIcon(glyph, size: 16, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            DefaultTextStyle.merge(
              style: TextStyle(color: Colors.white, fontSize: title != null ? 12 : 13, height: 1.3),
              child: content,
            ),
          ],
        ),
      ),
    ]),
  );
}

final _ok = RegExp(
    r'\b(saved|sent|added|copied|done|updated|created|deleted|removed|shared|posted|joined|followed|unfollowed|blocked|reported|invited|connected|turned on|turned off|boosted|liked|submitted|ready)\b',
    caseSensitive: false);
final _no = RegExp(
    r"(couldn|could not|can't|cannot|can’t|couldn’t|failed|error|denied|declined|not allowed|only the host|only |no internet|not enough|invalid|wrong|too |expired|unavailable|isn’t|isn't|try again|full|taken|limit)",
    caseSensitive: false);

InIconData _iconFor(String text) {
  if (_no.hasMatch(text)) return InIcons.block;
  if (_ok.hasMatch(text)) return InIcons.check;
  return InIcons.info;
}
