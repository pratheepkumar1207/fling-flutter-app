import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Share/WhatsApp/Instagram row — Dart port of ShareRow.jsx. No public
/// per-post/reel/room-broadcast detail page exists to deep-link into, so
/// sharing always points at the app itself plus a text caption.
class ShareRow extends StatelessWidget {
  final String? text;
  final String? url;

  const ShareRow({super.key, this.text, this.url});

  static const _appUrl = 'https://fling-production.up.railway.app';

  String get _shareText => text != null && text!.isNotEmpty ? '$text — via Fling' : 'Check this out on Fling';
  String get _shareUrl => url ?? _appUrl;

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '$_shareText $_shareUrl'));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _openWhatsapp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent('$_shareText $_shareUrl')}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) _copyLink(context);
    }
  }

  Future<void> _openInstagram(BuildContext context) async {
    // Instagram has no share-intent URL scheme — best-effort is to copy the
    // caption+link and hand off to the Instagram app to paste into a story
    // or DM, same workaround most apps use for IG sharing.
    await _copyLink(context);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied — paste it into Instagram')));
    await launchUrl(Uri.parse('https://instagram.com'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _copyLink(context),
          icon: const Text('🔗', style: TextStyle(fontSize: 16)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Share',
        ),
        IconButton(
          onPressed: () => _openWhatsapp(context),
          icon: const Text('💚', style: TextStyle(fontSize: 16)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Share to WhatsApp',
        ),
        IconButton(
          onPressed: () => _openInstagram(context),
          icon: const Text('📸', style: TextStyle(fontSize: 16)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Share to Instagram',
        ),
      ],
    );
  }
}
