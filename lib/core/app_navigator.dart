import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'active_room_holder.dart';
import 'auth_provider.dart';
import '../screens/party/party_screen.dart';

/// Global key for navigating from code with no BuildContext of its own —
/// specifically a tapped push notification (see
/// push_notifications.dart's setupNotificationTapHandling), which must
/// work regardless of which screen is currently showing, or even during a
/// cold start before any screen has finished building. Wired into
/// MaterialApp.navigatorKey in main.dart — mirrors app_messenger.dart's
/// identical scaffoldMessengerKey pattern for the same reason.
final navigatorKey = GlobalKey<NavigatorState>();

// An FCM cold-start tap can arrive before AuthProvider has restored the
// persisted session. Keep the opaque room id until the authenticated shell
// exists rather than creating PartyScreen early and making its first API
// request with no JWT.
String? _pendingRoomId;

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
  if (roomId == null || roomId.trim().isEmpty) return;
  _pendingRoomId = roomId.trim();
  openPendingPartyNotification();
}

/// Opens a stored room notification only after authentication has completed.
/// SplashScreen calls this after it renders AppShell for a cold-start tap;
/// ordinary background notification taps open immediately because the user is
/// already authenticated.
void openPendingPartyNotification() {
  final state = navigatorKey.currentState;
  final context = navigatorKey.currentContext;
  final roomId = _pendingRoomId;
  if (state == null || context == null || roomId == null) return;
  if (!context.read<AuthProvider>().isAuthed) return;

  _pendingRoomId = null;
  // PartyScreen deliberately reattaches to the holder rather than creating a
  // second socket controller. This makes a notification a safe way back to
  // the already-active room as well as a way into a new invited room.
  if (ActiveRoomHolder.roomId == roomId &&
      ActiveRoomHolder.isRoomScreenVisible.value) {
    return;
  }
  state.push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
}
