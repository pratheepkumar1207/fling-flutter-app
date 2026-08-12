import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/clay_colors.dart';

/// Single share entry point — a proper share icon that opens a small sheet
/// with Copy link / WhatsApp / Instagram, instead of three ambiguous emoji
/// buttons sitting directly in the post's action row.
class ShareRow extends StatelessWidget {
  final String? text;
  final String? url;

  const ShareRow({super.key, this.text, this.url});

  String get _shareText => text != null && text!.isNotEmpty ? '$text — via Insync' : 'Check this out on Insync';
  String get _shareUrl => url ?? ApiClient.baseUrl;

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

  void _openSheet(BuildContext context) {
    final clay = ClayColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: clay.surface2, borderRadius: BorderRadius.circular(22), border: Border.all(color: clay.border)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shareOption(
                icon: Icons.link_rounded,
                iconColor: clay.textDim,
                label: 'Copy link',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copyLink(context);
                },
              ),
              _shareOption(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openWhatsapp(context);
                },
              ),
              _shareOption(
                icon: Icons.camera_alt_rounded,
                iconColor: AppColors.accent,
                label: 'Instagram',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openInstagram(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareOption({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return Builder(
      builder: (context) {
        final clay = ClayColors.of(context);
        return ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(label, style: TextStyle(color: clay.text, fontSize: 14, fontWeight: FontWeight.w500)),
          onTap: onTap,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clay = ClayColors.of(context);
    return IconButton(
      onPressed: () => _openSheet(context),
      icon: Icon(Icons.share_rounded, color: clay.textDim, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Share',
    );
  }
}
