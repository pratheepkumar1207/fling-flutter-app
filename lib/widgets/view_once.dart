import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';
import 'app_image.dart';

/// Opens a view-once photo: asks the server for it (which only works once)
/// and shows it full screen for [seconds], then closes. Returns false if it
/// couldn't be opened (already opened, expired, not yours).
Future<bool> openViewOncePhoto(BuildContext context, String openPath) async {
  try {
    final r = await ApiClient.post(openPath) as Map;
    final url = r['mediaUrl'] as String?;
    if (url == null || !context.mounted) return false;
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => ViewOnceViewer(
          mediaUrl: url, seconds: (r['seconds'] as num?)?.toInt() ?? 10),
    ));
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return false;
  }
}

/// Full-screen photo with a countdown bar; closes itself when time is up.
class ViewOnceViewer extends StatefulWidget {
  final String mediaUrl;
  final int seconds;
  const ViewOnceViewer({super.key, required this.mediaUrl, this.seconds = 10});

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer = AnimationController(
      vsync: this, duration: Duration(seconds: widget.seconds))
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            child: Center(
                child: AppImage(source: widget.mediaUrl, fit: BoxFit.contain)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(children: [
              AnimatedBuilder(
                animation: _timer,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 1 - _timer.value,
                    minHeight: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const InIcon(InIcons.hourglass,
                    size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                AnimatedBuilder(
                  animation: _timer,
                  builder: (_, __) => Text(
                      'View once · ${(widget.seconds * (1 - _timer.value)).ceil()}s',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const InIcon(InIcons.close, color: Colors.white),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// The bubble for a view-once photo in a chat.
class ViewOnceChip extends StatelessWidget {
  final bool mine;
  final bool opened;
  final VoidCallback? onOpen;
  const ViewOnceChip(
      {super.key, required this.mine, required this.opened, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final label = mine
        ? (opened ? 'Opened' : 'View once photo')
        : (opened ? 'Opened' : 'Tap to view · 10s');
    final color = mine ? Colors.white : AppColors.text;
    return Semantics(
      button: onOpen != null,
      label: 'View once photo, $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: opened ? color.withValues(alpha: 0.4) : color,
                    width: 1.6),
              ),
              child: Center(
                  child: Text('1',
                      style: TextStyle(
                          color: opened ? color.withValues(alpha: 0.4) : color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: opened ? color.withValues(alpha: 0.6) : color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
