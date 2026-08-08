import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

/// One persistent connection for the whole app, established once the user
/// is authed — mirrors src/realtime/SocketContext.jsx, same `auth: { token }`
/// handshake the backend's syncHandler.js expects.
class SocketService extends ChangeNotifier {
  io.Socket? _socket;

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    disconnect();
    _socket = io.io(
      ApiClient.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) => notifyListeners());
    _socket!.onDisconnect((_) => notifyListeners());
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
