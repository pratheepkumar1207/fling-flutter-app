import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

/// "Share to" bottom sheet: a row of direct app targets (deep-linked via
/// url_launcher, so no need for the OS picker for the common ones) plus a
/// "More" tile that falls back to the native OS share sheet for anything
/// not listed, and a Copy Link row underneath — matches the mockup's
/// list-of-apps + copy-link layout instead of jumping straight to the OS
/// sheet like ShareRow used to.
Future<void> showShareBottomSheet(BuildContext context,
    {String? text, required String url}) async {
  final shareText = text != null && text.isNotEmpty
      ? '$text — via Insync'
      : 'Check this out on Insync';
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ShareBottomSheet(text: shareText, url: url),
  );
}

class _ShareBottomSheet extends StatelessWidget {
  final String text;
  final String url;

  const _ShareBottomSheet({required this.text, required this.url});

  Future<void> _open(BuildContext context, Uri uri) async {
    Navigator.of(context).pop();
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // App isn't installed / no handler — fall back to the native share
      // sheet rather than silently doing nothing.
      await Share.share('$text $url');
    }
  }

  Future<void> _more(BuildContext context) async {
    Navigator.of(context).pop();
    await Share.share('$text $url');
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  @override
  Widget build(BuildContext context) {
    final encodedText = Uri.encodeComponent(text);
    final encodedUrl = Uri.encodeComponent(url);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share to',
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _AppTile(
                    icon: FaIcon(FontAwesomeIcons.whatsapp,
                        color: const Color(0xFF25D366), size: 24),
                    bgColor: const Color(0xFF25D366),
                    label: 'WhatsApp',
                    onTap: () => _open(
                        context,
                        Uri.parse(
                            'https://wa.me/?text=$encodedText%20$encodedUrl')),
                  ),
                  _AppTile(
                    icon: FaIcon(FontAwesomeIcons.telegram,
                        color: const Color(0xFF29A9EA), size: 24),
                    bgColor: const Color(0xFF29A9EA),
                    label: 'Telegram',
                    onTap: () => _open(
                        context,
                        Uri.parse(
                            'https://t.me/share/url?url=$encodedUrl&text=$encodedText')),
                  ),
                  _AppTile(
                    icon: const Icon(Icons.sms_rounded,
                        color: AppColors.success, size: 24),
                    bgColor: AppColors.success,
                    label: 'Messages',
                    onTap: () => _open(
                        context,
                        Uri.parse(
                            '${Platform.isIOS ? 'sms:&body=' : 'sms:?body='}$encodedText%20$encodedUrl')),
                  ),
                  _AppTile(
                    icon: const Icon(Icons.email_rounded,
                        color: AppColors.accent2, size: 24),
                    bgColor: AppColors.accent2,
                    label: 'Email',
                    onTap: () => _open(
                        context,
                        Uri(scheme: 'mailto', queryParameters: {
                          'subject': 'Check this out on Insync',
                          'body': '$text $url'
                        })),
                  ),
                  _AppTile(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: AppColors.textDim, size: 24),
                    bgColor: AppColors.textDim,
                    label: 'More',
                    onTap: () => _more(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border, height: 24),
            InkWell(
              onTap: () => _copyLink(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: AppColors.surface3, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.link_rounded,
                          color: AppColors.text, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Copy link',
                          style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final Widget icon;
  final Color bgColor;
  final String label;
  final VoidCallback onTap;

  const _AppTile(
      {required this.icon,
      required this.bgColor,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
