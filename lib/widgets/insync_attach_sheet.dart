import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';
import 'app_image.dart';

/// Everything that can be attached, in the order the sheet shows them.
enum AttachKind {
  gallery,
  camera,
  viewOnce,
  audio,
  document,
  gif,
  sticker,
  poll,
  location,
}

const _look = {
  AttachKind.gallery: (
    InIcons.image,
    'Gallery',
    Color(0xFF2B1640),
    AppColors.lilac
  ),
  AttachKind.camera: (
    InIcons.camera,
    'Camera',
    Color(0xFF3A1430),
    AppColors.pink
  ),
  AttachKind.viewOnce: (
    InIcons.eye,
    'View once',
    Color(0xFF2B1640),
    AppColors.lilac
  ),
  AttachKind.audio: (
    InIcons.mic,
    'Audio',
    Color(0xFF1E3324),
    AppColors.success
  ),
  AttachKind.document: (
    InIcons.doc,
    'Document',
    Color(0xFF1A2A40),
    AppColors.diamond
  ),
  AttachKind.gif: (InIcons.gif, 'GIF', Color(0xFF3A2E10), AppColors.gold),
  AttachKind.sticker: (
    InIcons.smile,
    'Sticker',
    Color(0xFF3A2E10),
    AppColors.gold
  ),
  AttachKind.poll: (
    InIcons.poll,
    'Poll',
    Color(0xFF2A2436),
    AppColors.inkMuted
  ),
  AttachKind.location: (
    InIcons.map,
    'Location',
    Color(0xFF1E2E2E),
    Color(0xFF5DCAA5)
  ),
};

/// One Instagram-style attach sheet for chats, rooms, posts, reels and
/// stories — each passes just the options that make sense there.
Future<AttachKind?> showInsyncAttachSheet(BuildContext context,
    {required List<AttachKind> options, String title = 'Share'}) {
  return showModalBottomSheet<AttachKind>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
            children: [
              for (final k in AttachKind.values)
                if (options.contains(k))
                  _Option(k, () => Navigator.of(sheet).pop(k)),
            ],
          ),
        ]),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  final AttachKind kind;
  final VoidCallback onTap;
  const _Option(this.kind, this.onTap);

  @override
  Widget build(BuildContext context) {
    final (icon, label, bg, fg) = _look[kind]!;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(17),
              border: kind == AttachKind.viewOnce
                  ? Border.all(color: AppColors.lilac, width: 1.5)
                  : null,
            ),
            child: Center(child: InIcon(icon, size: 23, color: fg)),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
        ]),
      ),
    );
  }
}

/// Look at the photo before sending, with a "View once" switch. Returns
/// null if cancelled, otherwise whether to send it as view once.
Future<bool?> showPhotoSendPreview(BuildContext context, String dataUri,
    {bool viewOnce = false, String sendLabel = 'Send'}) {
  return Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PhotoSendPreview(
          dataUri: dataUri, viewOnce: viewOnce, sendLabel: sendLabel)));
}

class _PhotoSendPreview extends StatefulWidget {
  final String dataUri;
  final bool viewOnce;
  final String sendLabel;
  const _PhotoSendPreview(
      {required this.dataUri, required this.viewOnce, required this.sendLabel});

  @override
  State<_PhotoSendPreview> createState() => _PhotoSendPreviewState();
}

class _PhotoSendPreviewState extends State<_PhotoSendPreview> {
  late bool _viewOnce = widget.viewOnce;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
            icon: const InIcon(InIcons.close, color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppImage(source: widget.dataUri, fit: BoxFit.contain),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Material(
              color: _viewOnce ? const Color(0xFF2B1640) : AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                      color: _viewOnce ? AppColors.lilac : AppColors.border,
                      width: 1.5)),
              child: SwitchListTile(
                value: _viewOnce,
                onChanged: (v) => setState(() => _viewOnce = v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _viewOnce ? AppColors.primary : AppColors.surface3),
                  child: const Center(
                      child:
                          InIcon(InIcons.eye, size: 20, color: Colors.white)),
                ),
                title: const Text('View once',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('They can see it one time, for 10 seconds',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_viewOnce),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: Text(widget.sendLabel),
            ),
          ),
        ]),
      ),
    );
  }
}
