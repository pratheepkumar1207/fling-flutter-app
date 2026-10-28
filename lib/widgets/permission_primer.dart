import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

const _kSeenKey = 'permissionPrimerSeen';

/// Before the first call, live or mic: explain why Insync wants the camera,
/// microphone and (optionally) location, then ask. Shown once; after that
/// the system prompts (if any are still needed) appear on their own.
Future<void> ensurePermissionPrimer(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kSeenKey) == true || !context.mounted) return;
  final cam = await Permission.camera.status;
  final mic = await Permission.microphone.status;
  if (cam.isGranted && mic.isGranted) {
    await prefs.setBool(_kSeenKey, true);
    return;
  }
  if (!context.mounted) return;
  final go = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (sheet) => const _PrimerSheet(),
  );
  await prefs.setBool(_kSeenKey, true);
  if (go == true) {
    await [Permission.camera, Permission.microphone].request();
  }
}

class _PrimerSheet extends StatelessWidget {
  const _PrimerSheet();

  @override
  Widget build(BuildContext context) {
    Widget row(InIconData icon, String title, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFF2B1640),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(child: InIcon(icon, size: 20, color: AppColors.lilac)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(sub,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
              ]),
            ),
          ]),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Let Insync use your camera and mic',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'Needed for video calls, going live and talking in rooms. Location is optional and only used for Nearby and the map.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 13.5)),
              const SizedBox(height: 12),
              row(InIcons.camera, 'Camera', 'Calls, live, photo verification'),
              row(InIcons.mic, 'Microphone', 'Rooms, calls, voice notes'),
              row(InIcons.map, 'Location', 'Nearby and Explore map (asked separately)'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ]),
      ),
    );
  }
}
