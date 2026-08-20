import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../models/room_models.dart';

/// Flutter port of src/realtime/useRoomSocket.js — same event names/payload
/// shapes, so it talks to the exact same syncHandler.js on the backend.
class RoomSocketController extends ChangeNotifier {
  final io.Socket? socket;
  final String roomId;
  final String? myUserId;

  List<RosterEntry> roster = [];
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic> queue = {'items': [], 'currentIndex': 0};
  Map<String, dynamic> poll = {'active': false, 'question': null, 'options': [], 'votes': {}, 'createdBy': null};
  Map<String, dynamic>? playback;
  String? hostId;
  String? joinError;
  bool kicked = false;
  Map<String, dynamic> call = {'activeMics': [], 'pendingRequests': [], 'maxSlots': 8};
  String? micDenied;
  Map<String, dynamic>? game;
  Map<String, dynamic>? typeChange;
  Map<String, dynamic> settings = {'micEnabled': true, 'songPermission': 'anyone', 'autoPlay': true, 'pinPermission': 'host'};
  String? queueDenied;

  bool get isHost => hostId != null && myUserId != null && hostId == myUserId;
  bool get canPin => isHost || settings['pinPermission'] == 'anyone';

  RoomSocketController({required this.socket, required this.roomId, required this.myUserId}) {
    _bind();
  }

  void _bind() {
    final s = socket;
    if (s == null) return;
    s.emit('room:join', {'roomId': roomId});

    s.on('presence:roster', (data) {
      roster = (data as List).map((e) => RosterEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      notifyListeners();
    });
    s.on('chat:message', (data) {
      messages = [...messages, Map<String, dynamic>.from(data)];
      notifyListeners();
    });
    s.on('queue:state', (data) {
      queue = Map<String, dynamic>.from(data);
      notifyListeners();
    });
    s.on('poll:state', (data) {
      poll = Map<String, dynamic>.from(data);
      notifyListeners();
    });
    s.on('room:hostChanged', (data) {
      hostId = data['hostId'] as String?;
      notifyListeners();
    });
    s.on('playback:state', (data) {
      playback = data == null ? null : Map<String, dynamic>.from(data);
      notifyListeners();
    });
    s.on('playback:play', (data) {
      playback = {...?playback, ...Map<String, dynamic>.from(data), 'isPlaying': true, 'updatedAt': DateTime.now().millisecondsSinceEpoch};
      notifyListeners();
    });
    s.on('playback:seek', (data) {
      playback = {...?playback, ...Map<String, dynamic>.from(data), 'isPlaying': true, 'updatedAt': DateTime.now().millisecondsSinceEpoch};
      notifyListeners();
    });
    s.on('playback:pause', (data) {
      playback = {...?playback, ...Map<String, dynamic>.from(data), 'isPlaying': false, 'updatedAt': DateTime.now().millisecondsSinceEpoch};
      notifyListeners();
    });
    s.on('room:joinError', (data) {
      joinError = data['error'] as String?;
      notifyListeners();
    });
    s.on('room:kicked', (_) {
      kicked = true;
      notifyListeners();
    });
    s.on('call:state', (data) {
      call = Map<String, dynamic>.from(data);
      notifyListeners();
    });
    s.on('call:denied', (data) {
      micDenied = data['reason'] as String?;
      notifyListeners();
    });
    s.on('game:state', (data) {
      game = data == null ? null : Map<String, dynamic>.from(data);
      notifyListeners();
    });
    // The host changed the room's type (see PATCH /rooms/:id/type) —
    // re-join so the server's lazy game-state seeding (in room:join) runs
    // again for whatever the new gameType is, same as a fresh page load.
    s.on('room:typeChanged', (data) {
      typeChange = Map<String, dynamic>.from(data);
      notifyListeners();
      s.emit('room:join', {'roomId': roomId});
    });
    s.on('room:settingsChanged', (data) {
      settings = {...settings, ...Map<String, dynamic>.from(data)};
      notifyListeners();
    });
    s.on('queue:denied', (data) {
      queueDenied = data['reason'] as String?;
      notifyListeners();
    });
  }

  void leave() {
    socket?.emit('room:leave', {'roomId': roomId});
    socket?.off('presence:roster');
    socket?.off('chat:message');
    socket?.off('queue:state');
    socket?.off('poll:state');
    socket?.off('room:hostChanged');
    socket?.off('playback:state');
    socket?.off('playback:play');
    socket?.off('playback:seek');
    socket?.off('playback:pause');
    socket?.off('room:joinError');
    socket?.off('room:kicked');
    socket?.off('call:state');
    socket?.off('call:denied');
    socket?.off('game:state');
    socket?.off('room:typeChanged');
    socket?.off('room:settingsChanged');
    socket?.off('queue:denied');
  }

  void clearMicDenied() {
    micDenied = null;
    notifyListeners();
  }

  void clearQueueDenied() {
    queueDenied = null;
    notifyListeners();
  }

  void sendMessage(String text) => socket?.emit('chat:message', {'roomId': roomId, 'text': text});
  void play(double position) {
    if (isHost) socket?.emit('playback:play', {'roomId': roomId, 'position': position});
  }

  void pause(double position) {
    if (isHost) socket?.emit('playback:pause', {'roomId': roomId, 'position': position});
  }

  void seek(double position) {
    if (isHost) socket?.emit('playback:seek', {'roomId': roomId, 'position': position});
  }

  void requestState() => socket?.emit('playback:requestState', {'roomId': roomId});

  // position: 'bottom' (default, end of queue) or 'top' (plays right after
  // whatever's current) — see add_to_queue_dialog.dart. Meaningless on an
  // empty queue (the item just becomes item 0 either way), so callers
  // don't need to special-case that.
  void queueAdd(Map<String, dynamic> item, {String position = 'bottom'}) =>
      socket?.emit('queue:add', {'roomId': roomId, 'item': item, 'position': position});
  void queueInit(Map<String, dynamic> item) => socket?.emit('queue:init', {'roomId': roomId, 'item': item});
  void queueJump(int index) {
    if (canPin) socket?.emit('queue:jump', {'roomId': roomId, 'index': index});
  }

  void queueRemove(int index) {
    if (isHost) socket?.emit('queue:remove', {'roomId': roomId, 'index': index});
  }

  void queueNext() => socket?.emit('queue:next', {'roomId': roomId});
  void queueSkip() {
    if (isHost) socket?.emit('queue:skip', {'roomId': roomId});
  }

  void queueReorder(int fromIndex, int toIndex) {
    if (isHost) socket?.emit('queue:reorder', {'roomId': roomId, 'fromIndex': fromIndex, 'toIndex': toIndex});
  }

  void makeHost(String targetUserId) {
    if (isHost) socket?.emit('room:makeHost', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void kick(String targetUserId) {
    if (isHost) socket?.emit('room:kick', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void micOn() {
    if (isHost) socket?.emit('call:micOn', {'roomId': roomId});
  }

  void micOff() => socket?.emit('call:micOff', {'roomId': roomId});
  void requestMic() => socket?.emit('call:requestMic', {'roomId': roomId});
  void cancelMicRequest() => socket?.emit('call:cancelMicRequest', {'roomId': roomId});

  void approveMic(String targetUserId) {
    if (isHost) socket?.emit('call:approveMic', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void denyMic(String targetUserId) {
    if (isHost) socket?.emit('call:denyMic', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void inviteMic(String targetUserId) {
    if (isHost) socket?.emit('call:inviteMic', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void removeMic(String targetUserId) {
    if (isHost) socket?.emit('call:removeMic', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void forceMuteMic(String targetUserId) {
    if (isHost) socket?.emit('call:forceMute', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void forceUnmuteMic(String targetUserId) {
    if (isHost) socket?.emit('call:forceUnmute', {'roomId': roomId, 'targetUserId': targetUserId});
  }

  void createPoll(String question, List<String> options) {
    if (isHost) socket?.emit('poll:create', {'roomId': roomId, 'question': question, 'options': options});
  }

  void votePoll(int optionIndex) => socket?.emit('poll:vote', {'roomId': roomId, 'optionIndex': optionIndex});
  void resetPoll() {
    if (isHost) socket?.emit('poll:reset', {'roomId': roomId});
  }

  void gameJoin() => socket?.emit('game:join', {'roomId': roomId});
  void gameMove(Map<String, dynamic> move) => socket?.emit('game:move', {'roomId': roomId, 'move': move});
  void gameReset() {
    if (isHost) socket?.emit('game:reset', {'roomId': roomId});
  }
}
