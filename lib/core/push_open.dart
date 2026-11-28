import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../screens/notifications/notifications_screen.dart';
import '../widgets/insync_snack.dart';
import 'api_client.dart';
import 'app_messenger.dart';
import 'app_navigator.dart';
import 'auth_provider.dart';

/// A tapped phone notification, or one of its buttons, drawn by
/// InsyncPush.kt. "Join" and a tap on an invite open the lobby; "Let in"
/// invites the person who asked; anything else opens Notifications.
class PushOpen {
  PushOpen._();
  static const _channel = MethodChannel('com.fling.app/push_open');

  /// Call once at startup.
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') await _collect();
    });
    unawaited(_collect());
  }

  static Future<void> _collect() async {
    try {
      final p = await _channel.invokeMethod<Map>('pending');
      if (p == null) return;
      final data = Map<String, dynamic>.from(
          jsonDecode('${p['data'] ?? '{}'}') as Map? ?? const {});
      await _handle('${p['action'] ?? 'open'}', data);
    } catch (_) {
      // Not on Android, or nothing pending.
    }
  }

  /// Waits for sign-in to finish on a cold start (up to 20 seconds).
  static Future<BuildContext?> _signedIn() async {
    for (var i = 0; i < 67; i++) {
      final c = navigatorKey.currentContext;
      if (c != null && c.mounted && c.read<AuthProvider>().isAuthed) return c;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }

  static Future<void> _handle(String action, Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    if (action == 'let_in' && type == 'room_join_ask') {
      if (await _signedIn() == null) return;
      final roomId = data['roomId'] as String?;
      final userId = data['userId'] as String?;
      final name = (data['name'] as String?)?.trim();
      if (roomId == null || userId == null) return;
      try {
        await ApiClient.post('/rooms/$roomId/invite', body: {
          'userIds': [userId]
        });
        scaffoldMessengerKey.currentState?.showSnackBar(insyncSnackBar(
            content: Text(
                'Invite sent to ${name == null || name.isEmpty ? 'them' : name}')));
      } catch (_) {
        scaffoldMessengerKey.currentState?.showSnackBar(insyncSnackBar(
            content: const Text(
                'Couldn’t send the invite. The lobby may have ended.')));
      }
      return;
    }
    final roomId = data['roomId'] as String?;
    if ((roomId != null && roomId.isNotEmpty && type != 'gift') ||
        data['tournamentId'] != null) {
      handleNotificationTap(data);
      return;
    }
    final c = await _signedIn();
    if (c == null || !c.mounted) return;
    navigatorKey.currentState
        ?.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }
}
