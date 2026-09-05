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
  Map<String, dynamic> poll = {
    'active': false,
    'question': null,
    'options': [],
    'votes': {},
    'createdBy': null
  };
  Map<String, dynamic>? playback;
  // Participant "vote to skip the current song" tally — see
  // syncHandler.js's queue:voteSkip. required is a live majority of
  // whoever's actually in the room right now, not a fixed number.
  Map<String, dynamic> skipVote = {'count': 0, 'required': 1};
  // Participant "vote to add this suggestion" tallies — see
  // syncHandler.js's queue:voteAdd. Keyed by videoUrl since several
  // suggestions can be mid-vote at once, unlike skipVote's single tally.
  Map<String, Map<String, dynamic>> addVotes = {};
  String? hostId;
  String? joinError;
  bool kicked = false;
  Map<String, dynamic> call = {
    'activeMics': [],
    'pendingRequests': [],
    'maxSlots': 8
  };
  String? micDenied;
  Map<String, dynamic>? game;
  Map<String, dynamic>? typeChange;
  Map<String, dynamic> settings = {
    'micEnabled': true,
    'songPermission': 'anyone',
    'autoPlay': true,
    'pinPermission': 'host',
    'nextTrackMode': 'justPlay',
  };
  String? queueDenied;
  // Bumped (not just true/false — a screen already showing the prompt needs
  // to notice a *second* one after dismissing the first) every time the
  // server says the queue just ran dry with nothing pinned — see
  // syncHandler.js's queue:promptPin. party_screen.dart reacts by opening
  // the suggestion grid; there's nothing to clear, callers just compare
  // this value against what they last saw.
  int promptPinToken = 0;
  // One-shot signal — set when the server tells this client it was just
  // @mentioned, cleared by clearMention() once party_screen.dart has shown
  // the pop-up/played the sound for it. {fromName, text} — see
  // syncHandler.js's chat:mentioned emit.
  Map<String, dynamic>? mention;

  bool get isHost => hostId != null && myUserId != null && hostId == myUserId;
  bool get canPin => isHost || settings['pinPermission'] == 'anyone';

  // How far ahead (+) or behind (-) the server's clock is from this
  // device's own — every elapsed-time drift calculation across the three
  // video players should add this before comparing against a server
  // updatedAt timestamp, instead of trusting the device's raw clock. Two
  // phones with a few seconds of ordinary clock skew between them was
  // enough to make "current playing time" visibly disagree; correcting
  // against the server's clock instead of each device's own is what
  // actually makes it match.
  int serverTimeOffsetMs = 0;
  int get correctedNowMs =>
      DateTime.now().millisecondsSinceEpoch + serverTimeOffsetMs;

  // Classic NTP-lite round trip: assumes the network delay is roughly
  // symmetric (request and response take about the same time each way),
  // so the server's clock at the moment it replied is approximated as
  // sitting at the midpoint of our own send/receive timestamps.
  void _syncServerTime() {
    final s = socket;
    if (s == null) return;
    final sentAt = DateTime.now().millisecondsSinceEpoch;
    s.emitWithAck('time:sync', {}, ack: (dynamic response) {
      final receivedAt = DateTime.now().millisecondsSinceEpoch;
      final serverTime = (response as Map)['serverTime'] as int?;
      if (serverTime == null) return;
      final roundTripMidpoint = sentAt + ((receivedAt - sentAt) ~/ 2);
      serverTimeOffsetMs = serverTime - roundTripMidpoint;
    });
  }

  RoomSocketController(
      {required this.socket, required this.roomId, required this.myUserId}) {
    _bind();
  }

  void _bind() {
    final s = socket;
    if (s == null) return;
    s.emit('room:join', {'roomId': roomId});
    _syncServerTime();

    s.on('presence:roster', (data) {
      roster = (data as List)
          .map((e) => RosterEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
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
    s.on('queue:promptPin', (_) {
      promptPinToken++;
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
    s.on('queue:skipVoteState', (data) {
      skipVote = Map<String, dynamic>.from(data);
      notifyListeners();
    });
    s.on('queue:addVoteState', (data) {
      final map = Map<String, dynamic>.from(data);
      final videoUrl = map['videoUrl'] as String?;
      if (videoUrl == null) return;
      addVotes = {...addVotes, videoUrl: map};
      notifyListeners();
    });
    // The server now includes its own updatedAt in these payloads (see
    // syncHandler.js's playback:play/pause/seek broadcast) — using that
    // instead of this client's local clock means every receiver dedupes
    // against the same authoritative timestamp, rather than each one
    // stamping the moment IT happened to receive the event (which drifted
    // apart under network latency). The local-clock fallback only matters
    // during a rolling deploy where an old server hasn't sent one yet.
    s.on('playback:play', (data) {
      final d = Map<String, dynamic>.from(data);
      playback = {
        ...?playback,
        ...d,
        'isPlaying': true,
        'updatedAt': d['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch
      };
      notifyListeners();
    });
    s.on('playback:seek', (data) {
      final d = Map<String, dynamic>.from(data);
      playback = {
        ...?playback,
        ...d,
        'isPlaying': true,
        'updatedAt': d['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch
      };
      notifyListeners();
    });
    s.on('playback:pause', (data) {
      final d = Map<String, dynamic>.from(data);
      playback = {
        ...?playback,
        ...d,
        'isPlaying': false,
        'updatedAt': d['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch
      };
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
    s.on('chat:mentioned', (data) {
      mention = Map<String, dynamic>.from(data);
      notifyListeners();
    });
  }

  void leave() {
    socket?.emit('room:leave', {'roomId': roomId});
    socket?.off('presence:roster');
    socket?.off('chat:message');
    socket?.off('queue:state');
    socket?.off('poll:state');
    socket?.off('queue:promptPin');
    socket?.off('room:hostChanged');
    socket?.off('playback:state');
    socket?.off('queue:skipVoteState');
    socket?.off('queue:addVoteState');
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
    socket?.off('chat:mentioned');
  }

  void clearMicDenied() {
    micDenied = null;
    notifyListeners();
  }

  void clearQueueDenied() {
    queueDenied = null;
    notifyListeners();
  }

  void clearMention() {
    mention = null;
    notifyListeners();
  }

  void sendMessage(String text, {List<String> mentionedUserIds = const []}) =>
      socket?.emit('chat:message', {
        'roomId': roomId,
        'text': text,
        if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      });
  void play(double position) {
    if (isHost) {
      socket?.emit('playback:play', {'roomId': roomId, 'position': position});
    }
  }

  void pause(double position) {
    if (isHost) {
      socket?.emit('playback:pause', {'roomId': roomId, 'position': position});
    }
  }

  void seek(double position) {
    if (isHost) {
      socket?.emit('playback:seek', {'roomId': roomId, 'position': position});
    }
  }

  void requestState() =>
      socket?.emit('playback:requestState', {'roomId': roomId});

  // position: 'bottom' (default, end of queue) or 'top' (plays right after
  // whatever's current) — see add_to_queue_dialog.dart. Meaningless on an
  // empty queue (the item just becomes item 0 either way), so callers
  // don't need to special-case that.
  void queueAdd(Map<String, dynamic> item, {String position = 'bottom'}) =>
      socket?.emit(
          'queue:add', {'roomId': roomId, 'item': item, 'position': position});
  void queueInit(Map<String, dynamic> item) =>
      socket?.emit('queue:init', {'roomId': roomId, 'item': item});
  void queueJump(int index) {
    if (canPin) socket?.emit('queue:jump', {'roomId': roomId, 'index': index});
  }

  void queueRemove(int index) {
    if (isHost) {
      socket?.emit('queue:remove', {'roomId': roomId, 'index': index});
    }
  }

  void queueNext() => socket?.emit('queue:next', {'roomId': roomId});
  void queueSkip() {
    if (isHost) socket?.emit('queue:skip', {'roomId': roomId});
  }

  // Participant-side skip — the host uses queueSkip above instead (always
  // immediate, no vote needed). Safe to call repeatedly; the server dedupes
  // by userId, so tapping it twice doesn't count twice.
  void voteSkip() => socket?.emit('queue:voteSkip', {'roomId': roomId});

  // Participant "vote to add this suggestion" — see video_suggestions_panel
  // .dart. The host adds directly via queueAdd instead (always immediate,
  // no vote needed); this is the non-host path.
  void voteAdd(Map<String, dynamic> item) =>
      socket?.emit('queue:voteAdd', {'roomId': roomId, 'item': item});

  // Tapping a suggestion you've already voted for retracts it instead —
  // see video_suggestions_panel.dart's toggle behavior.
  void unvoteAdd(String videoUrl) =>
      socket?.emit('queue:unvoteAdd', {'roomId': roomId, 'videoUrl': videoUrl});

  void queueReorder(int fromIndex, int toIndex) {
    if (isHost) {
      socket?.emit('queue:reorder',
          {'roomId': roomId, 'fromIndex': fromIndex, 'toIndex': toIndex});
    }
  }

  void makeHost(String targetUserId) {
    if (isHost) {
      socket?.emit(
          'room:makeHost', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void kick(String targetUserId) {
    if (isHost) {
      socket
          ?.emit('room:kick', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void micOn() {
    if (isHost) socket?.emit('call:micOn', {'roomId': roomId});
  }

  void micOff() => socket?.emit('call:micOff', {'roomId': roomId});
  void requestMic() => socket?.emit('call:requestMic', {'roomId': roomId});
  void cancelMicRequest() =>
      socket?.emit('call:cancelMicRequest', {'roomId': roomId});

  void approveMic(String targetUserId) {
    if (isHost) {
      socket?.emit(
          'call:approveMic', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void denyMic(String targetUserId) {
    if (isHost) {
      socket?.emit(
          'call:denyMic', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void inviteMic(String targetUserId) {
    if (isHost) {
      socket?.emit(
          'call:inviteMic', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void removeMic(String targetUserId) {
    if (isHost) {
      socket?.emit(
          'call:removeMic', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void forceMuteMic(String targetUserId) {
    if (isHost) {
      socket?.emit(
          'call:forceMute', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void forceUnmuteMic(String targetUserId) {
    if (isHost) {
      socket?.emit(
          'call:forceUnmute', {'roomId': roomId, 'targetUserId': targetUserId});
    }
  }

  void createPoll(String question, List<String> options) {
    if (isHost) {
      socket?.emit('poll:create',
          {'roomId': roomId, 'question': question, 'options': options});
    }
  }

  void votePoll(int optionIndex) =>
      socket?.emit('poll:vote', {'roomId': roomId, 'optionIndex': optionIndex});
  void resetPoll() {
    if (isHost) socket?.emit('poll:reset', {'roomId': roomId});
  }

  void gameJoin() => socket?.emit('game:join', {'roomId': roomId});
  void gameMove(Map<String, dynamic> move) =>
      socket?.emit('game:move', {'roomId': roomId, 'move': move});
  void gameReset() {
    if (isHost) socket?.emit('game:reset', {'roomId': roomId});
  }
}
