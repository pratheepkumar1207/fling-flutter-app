import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/push_notifications.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

// New key so people who saw the old camera-and-mic sheet get this once too.
const _kSeenKey = 'startupPermissionsSeen';

const _all = [
  Permission.camera,
  Permission.microphone,
  Permission.locationWhenInUse,
  Permission.notification,
];

/// First open after signing in: one sheet that explains every permission
/// Insync uses, and "Allow all" asks for them in a single request (Android
/// shows its dialogs back to back). Shown once; anything still missing is
/// asked again only when a feature actually needs it.
Future<void> ensureStartupPermissions(BuildContext context,
    {bool registerPush = true}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kSeenKey) == true || !context.mounted) return;
  final List<PermissionStatus> statuses;
  try {
    statuses = await Future.wait(_all.map((p) => p.status));
  } catch (_) {
    return; // No permission plugin (tests, unsupported platform).
  }
  if (statuses.every((s) => s.isGranted)) {
    await prefs.setBool(_kSeenKey, true);
    return;
  }
  if (!context.mounted) return;
  final go = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    backgroundColor: AppColors.surface,
    builder: (sheet) => const _PrimerSheet(),
  );
  await prefs.setBool(_kSeenKey, true);
  if (go != true) return;
  final result = await _all.request();
  if (registerPush && result[Permission.notification]?.isGranted == true) {
    // Registers this device for pushes now that it's allowed.
    requestPushPermissionAndRegister();
  }
}

/// Before a call, live or mic: if the startup sheet never ran, explain and
/// ask then. A no-op once it has been shown.
Future<void> ensurePermissionPrimer(BuildContext context) =>
    ensureStartupPermissions(context, registerPush: false);

class _PrimerSheet extends StatelessWidget {
  const _PrimerSheet();

  @override
  Widget build(BuildContext context) {
    Widget row(InIconData icon, String title, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFF2B1640),
                  borderRadius: BorderRadius.circular(14)),
              child:
                  Center(child: InIcon(icon, size: 20, color: AppColors.lilac)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12.5)),
                  ]),
            ),
          ]),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Allow Insync to work fully',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'Tap Allow all once and you won’t be asked again. You can change any of these later in your phone settings.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 13.5)),
              const SizedBox(height: 10),
              row(InIcons.camera, 'Camera',
                  'Video calls, going live, photo verification'),
              row(InIcons.mic, 'Microphone', 'Rooms, calls, voice notes'),
              row(InIcons.map, 'Location',
                  'Nearby and the Explore map — only shared if you turn it on'),
              row(InIcons.bell, 'Notifications',
                  'Messages, matches, calls and rooms starting'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Allow all'),
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
