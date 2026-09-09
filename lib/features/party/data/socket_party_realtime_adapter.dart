import 'dart:async';

import '../../../core/socket_service.dart';
import 'party_realtime_adapter.dart';

/// Real implementation of PartyRealtimeAdapter over the existing shared
/// Socket.IO connection (core/socket_service.dart) — spec Step 4:
/// "the current Socket.IO implementation should sit behind this
/// interface... do not rewrite Socket.IO merely for naming."
///
/// There is one persistent connection for the whole app (established once
/// at login, see SocketService.connect), not one connection per room —
/// `connect`/`disconnect` here map to that connection's existing room:join/
/// room:leave events, not to opening/closing a socket.
///
/// `events()`: socket_io_client 2.0.3+1 has no catch-all listener (no
/// `onAny`) — this subscribes to the fixed, real event set the backend
/// actually emits per room (documented in FLING_AUDIT.md §3's
/// RoomSocketController inventory) rather than claiming to forward
/// everything. Genuine per-event typed consumers should keep using
/// RoomSocketController directly; this is for generic/cross-cutting
/// consumption only (see party_realtime_adapter.dart's own doc comment).
class SocketPartyRealtimeAdapter implements PartyRealtimeAdapter {
  final SocketService socketService;

  SocketPartyRealtimeAdapter(this.socketService);

  static const _roomEvents = [
    'presence:roster',
    'chat:message',
    'queue:state',
    'playback:play',
    'playback:pause',
    'playback:seek',
    'room:hostChanged',
    'room:kicked',
    'poll:state',
    'game:state',
    'call:state',
  ];

  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  @override
  Future<void> connect(String roomId) async {
    socketService.socket?.emit('room:join', {'roomId': roomId});
  }

  @override
  Future<void> reconnect(String roomId) async {
    // A fresh room:join, not a replay of missed events — matches
    // RoomSocketController's own _bind(), which does the same on
    // (re)construction (spec Step 28: "use a fresh state snapshot").
    socketService.socket?.emit('room:join', {'roomId': roomId});
  }

  @override
  Future<void> disconnect(String roomId) async {
    socketService.socket?.emit('room:leave', {'roomId': roomId});
    await _controllers.remove(roomId)?.close();
  }

  @override
  Stream<Map<String, dynamic>> events(String roomId) {
    final existing = _controllers[roomId];
    if (existing != null) return existing.stream;

    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _controllers[roomId] = controller;
    final socket = socketService.socket;
    if (socket != null) {
      for (final eventName in _roomEvents) {
        socket.on(eventName, (data) {
          if (controller.isClosed) return;
          controller.add({'type': eventName, 'data': data});
        });
      }
    }
    return controller.stream;
  }

  @override
  void emit(String event, Map<String, dynamic> payload) {
    socketService.socket?.emit(event, payload);
  }
}
