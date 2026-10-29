import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/push_notifications.dart';
import '../theme/app_colors.dart';
import '../theme/insync_icons.dart';

const _kSeenKey = 'startupPermissionsSeen';

const _all = [
  Permission.camera,
  Permission.microphone,
  Permission.locationWhenInUse,
  Permission.notification,
];

/// What each permission is for, shown on the sheet.
final _info = {
  Permission.camera: (
    InIcons.camera,
    'Camera',
    'Video calls, going live, photo verification'
  ),
  Permission.microphone: (
    InIcons.mic,
    'Microphone',
    'Rooms, calls, voice notes'
  ),
  Permission.locationWhenInUse: (
    InIcons.map,
    'Location',
    'Nearby and the Explore map — only shared if you turn it on'
  ),
  Permission.notification: (
    InIcons.bell,
    'Notifications',
    'Messages, matches, calls and rooms starting'
  ),
};

/// Of [perms], the ones not allowed yet, or null without a permission
/// plugin (tests, unsupported platforms).
Future<Map<Permission, PermissionStatus>?> _missing(
    List<Permission> perms) async {
  try {
    final statuses = await Future.wait(perms.map((p) => p.status));
    return {
      for (var i = 0; i < perms.length; i++)
        if (!statuses[i].isGranted) perms[i]: statuses[i],
    };
  } catch (_) {
    return null;
  }
}

/// Every app open: the first time, one sheet explains every permission and
/// "Allow all" asks for them together (Android shows its dialogs back to
/// back). After that, if anything is still not allowed, the sheet comes
/// back listing just those. Once Android stops showing its popup ("don't
/// ask again"), the button opens the phone's settings instead.
Future<void> ensureStartupPermissions(BuildContext context,
    {bool registerPush = true}) async {
  final missing = await _missing(_all);
  if (missing == null || missing.isEmpty || !context.mounted) return;
  final prefs = await SharedPreferences.getInstance();
  final firstTime = prefs.getBool(_kSeenKey) != true;
  final settingsOnly = missing.values.every((s) => s.isPermanentlyDenied);
  if (!context.mounted) return;
  final go = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    backgroundColor: AppColors.surface,
    builder: (sheet) => _PrimerSheet(
        missing: missing.keys.toList(),
        firstTime: firstTime,
        settingsOnly: settingsOnly),
  );
  await prefs.setBool(_kSeenKey, true);
  if (go != true) return;
  if (settingsOnly) {
    await openAppSettings();
    return;
  }
  final result = await missing.keys.toList().request();
  if (registerPush && result[Permission.notification]?.isGranted == true) {
    // Registers this device for pushes now that it's allowed.
    requestPushPermissionAndRegister();
  }
}

/// Before a call, going live or taking the mic: asks again for whatever is
/// still missing. If Android won't show its popup any more, says so with a
/// button to the phone's settings. Returns whether everything is allowed.
Future<bool> checkPermissionsOrExplain(BuildContext context,
    {bool camera = false, bool mic = true}) async {
  final needed = [
    if (camera) Permission.camera,
    if (mic) Permission.microphone,
  ];
  final missing = await _missing(needed);
  if (missing == null || missing.isEmpty) return true;
  final asked = await missing.keys.toList().request();
  if (asked.values.every((s) => s.isGranted)) return true;
  if (!context.mounted) return false;
  final what = camera && mic
      ? 'camera and microphone'
      : camera
          ? 'camera'
          : 'microphone';
  final blocked = asked.values.any((s) => s.isPermanentlyDenied);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(blocked
        ? 'Allow $what for Insync in your phone settings.'
        : 'Insync needs your $what for this.'),
    action: blocked
        ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
        : null,
  ));
  return false;
}

class _PrimerSheet extends StatelessWidget {
  final List<Permission> missing;
  final bool firstTime;
  final bool settingsOnly;
  const _PrimerSheet(
      {required this.missing,
      required this.firstTime,
      required this.settingsOnly});

  @override
  Widget build(BuildContext context) {
    Widget row(Permission p) {
      final (icon, title, sub) = _info[p]!;
      return Padding(
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub,
                  style: const TextStyle(
                      color: AppColors.textDim, fontSize: 12.5)),
            ]),
          ),
        ]),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  firstTime
                      ? 'Allow Insync to work fully'
                      : 'Insync still needs these',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  settingsOnly
                      ? 'Your phone has blocked these for Insync. Open Settings → Permissions and turn them on.'
                      : firstTime
                          ? 'Tap Allow all and pick Allow on each one.'
                          : 'Without them some features won’t work. Tap Allow and pick Allow on each one.',
                  style: const TextStyle(
                      color: AppColors.textDim, fontSize: 13.5)),
              const SizedBox(height: 10),
              for (final p in _all)
                if (missing.contains(p)) row(p),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: Text(settingsOnly
                    ? 'Open settings'
                    : firstTime
                        ? 'Allow all'
                        : 'Allow'),
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
