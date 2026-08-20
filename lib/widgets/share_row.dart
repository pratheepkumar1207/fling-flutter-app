import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api_client.dart';

/// Single share entry point — hands off straight to the OS's own native
/// share sheet (every installed app that accepts shared text: WhatsApp,
/// Telegram, SMS, Gmail, Instagram DMs, etc. — whatever's actually on the
/// device), instead of a hand-picked list of a few hardcoded platforms.
class ShareRow extends StatelessWidget {
  final String? text;
  final String? url;
  final String? iconAsset;

  const ShareRow({super.key, this.text, this.url, this.iconAsset});

  String get _shareText => text != null && text!.isNotEmpty ? '$text — via Insync' : 'Check this out on Insync';
  String get _shareUrl => url ?? ApiClient.baseUrl;

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '$_shareText $_shareUrl',
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _share(context),
      icon: iconAsset != null ? Image.asset(iconAsset!, width: 40, height: 40) : const Icon(Icons.share_rounded, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: 'Share',
    );
  }
}
