import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process (and therefore the room socket connection) alive
/// while a user is active in a room and the app is backgrounded. Without
/// this, Android suspends the process's network activity shortly after
/// backgrounding, the socket silently disconnects, and syncHandler.js's
/// disconnect handler drops the user from the room's live roster — making
/// an active room vanish from everyone else's Lobby list even though the
/// host never actually left. Runs only while a room is open; started in
/// party_screen.dart's initSocket, stopped in its dispose.
class RoomPresenceService {
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'fling_room_presence',
        channelName: 'Active room',
        channelDescription: 'Keeps you connected while you\'re in a Fling room.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  // party_screen.dart calls start() from two independent async flows
  // (socket init + room load, whichever resolves first/last) — without this
  // guard both could race into FlutterForegroundTask.startService()
  // concurrently, and the loser silently fails (ServiceAlreadyStartedException,
  // swallowed by the package as a ServiceRequestResult we weren't even
  // checking), leaving no visible sign the service never actually started.
  static Future<void>? _starting;

  static Future<void> start(String roomTitle) {
    if (_starting != null) return _starting!;
    final future = _start(roomTitle);
    _starting = future;
    future.whenComplete(() => _starting = null);
    return future;
  }

  static Future<void> _start(String roomTitle) async {
    _ensureInitialized();
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.updateService(
        notificationTitle: 'In room',
        notificationText: roomTitle,
      );
      if (result is ServiceRequestFailure) {
        debugPrint('RoomPresenceService.updateService failed: ${result.error}');
      }
      return;
    }
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'In room',
      notificationText: roomTitle,
    );
    if (result is ServiceRequestFailure) {
      debugPrint('RoomPresenceService.startService failed: ${result.error}');
    }
    // A running foreground service alone isn't enough on OEM Android skins
    // (Vivo/Xiaomi/Oppo) that layer their own background-network throttling
    // on top of stock Doze — without this exemption those skins can still
    // freeze the socket's network access a short time after the screen
    // turns off, even though the service (and process) stay alive.
    if (!(await FlutterForegroundTask.isIgnoringBatteryOptimizations)) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
