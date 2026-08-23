import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'share_bottom_sheet.dart';

/// Single share entry point — opens the app's own "Share to" bottom sheet
/// (quick WhatsApp/Telegram/SMS/Email targets + Copy Link), with a "More"
/// tile falling back to the OS's native share sheet for anything else
/// installed on the device.
class ShareRow extends StatelessWidget {
  final String? text;
  final String? url;
  final String? iconAsset;

  const ShareRow({super.key, this.text, this.url, this.iconAsset});

  String get _shareUrl => url ?? ApiClient.baseUrl;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () =>
          showShareBottomSheet(context, text: text, url: _shareUrl),
      icon: iconAsset != null
          ? Image.asset(iconAsset!, width: 40, height: 40)
          : const Icon(Icons.share_rounded, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: 'Share',
    );
  }
}
