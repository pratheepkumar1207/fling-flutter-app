import 'package:flutter/material.dart';
import '../screens/party/party_screen.dart';

/// Global key for navigating from code with no BuildContext of its own —
/// specifically a tapped push notification (see
/// push_notifications.dart's setupNotificationTapHandling), which must
/// work regardless of which screen is currently showing, or even during a
/// cold start before any screen has finished building. Wired into
/// MaterialApp.navigatorKey in main.dart — mirrors app_messenger.dart's
/// identical scaffoldMessengerKey pattern for the same reason.
final navigatorKey = GlobalKey<NavigatorState>();

/// Routes a tapped notification's data payload to wherever it should go.
/// The backend already sends a real `data: {type, roomId}` payload for
/// every room-related notification (room_invite — src/routes/room.js;
/// event_reminder — src/lib/eventReminders.js; friend_online —
/// src/sockets/syncHandler.js) — this was previously never read at all,
/// since nothing in the app listened for a notification tap in the first
/// place. Confirmed via direct backend code review before writing this,
/// not assumed: the payload was always there, waiting for a consumer.
void handleNotificationTap(Map<String, dynamic> data) {
  final roomId = data['roomId'] as String?;
  if (roomId == null) return;
  final state = navigatorKey.currentState;
  if (state == null) return;
  state.push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
}
