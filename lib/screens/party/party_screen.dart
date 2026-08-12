import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/game_board_view.dart';
import '../../widgets/live_video_view.dart';
import '../../widgets/participant_avatar_row.dart';
import '../../widgets/poll_bottom_sheet.dart';
import '../../widgets/poll_creator_bottom_sheet.dart';
import '../../widgets/room_settings_sheet.dart';
import '../../widgets/spinner.dart';
import '../../widgets/voice_stage_view.dart';
import '../lobby/invite_screen.dart';
import 'chat_panel.dart';
import 'drive_video_player.dart';
import 'live_broadcast_controller.dart';
import 'queue_sheet.dart';
import 'roster_sheet.dart';
import 'room_socket_controller.dart';
import 'sync_video_player.dart';
import 'voice_chat_controller.dart';
import 'webview_room_player.dart';

// sourceTypes rendered via the generic embedded-browser WebviewRoomPlayer
// (see webview_browse_screen.dart in lobby/ for how these get created) —
// all "browse together, no playback sync" platforms. Add a new streaming
// platform here + to the source picker + to Room.js's sourceType ENUM to
// support another one; nothing else needs to change.
const _webviewSourceTypes = {'netflix', 'amazon', 'youtube_surf', 'hotstar', 'aha', 'sunnxt', 'sonyliv', 'airtel_xstream'};

class PartyScreen extends StatefulWidget {
  final String roomId;
  const PartyScreen({super.key, required this.roomId});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  final _hostKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _room;
  bool _loading = true;
  String? _error;
  RoomSocketController? _rs;
  VoiceChatController? _voice;
  LiveBroadcastController? _live;
  Set<String> _likedUrls = {};
  String? _loggedHistoryFor;
  bool _seededQueue = false;
  Map<String, dynamic>? _lastHandledTypeChange;
  // Purely local — lets this viewer watch a "video" queue item as audio-only
  // (or vice versa) without changing what anyone else in the room sees.
  // null means "follow the queue item's own mediaMode".
  String? _viewModeOverride;

  @override
  void initState() {
    super.initState();
    _loadRoom();
    _loadLiked();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSocket());
  }

  Future<void> _loadRoom() async {
    try {
      final data = await ApiClient.get('/rooms/${widget.roomId}');
      if (!mounted) return;
      setState(() {
        _room = data as Map<String, dynamic>;
        _loading = false;
      });
      _maybeInitLive();
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadLiked() async {
    try {
      final data = await ApiClient.get('/liked-songs');
      if (!mounted) return;
      setState(() {
        _likedUrls = (data as List).map((s) => (s as Map)['videoUrl'] as String? ?? '').toSet();
      });
    } catch (_) {}
  }

  void _initSocket() {
    final socket = context.read<SocketService>().socket;
    final myId = context.read<AuthProvider>().user?.id;
    final rs = RoomSocketController(socket: socket, roomId: widget.roomId, myUserId: myId);
    rs.addListener(_onRoomStateChanged);
    setState(() => _rs = rs);
    _voice = VoiceChatController(roomId: widget.roomId);
    _maybeInitLive();
  }

  void _maybeInitLive() {
    if (_live != null || _room == null || _rs == null) return;
    if (_room!['roomType'] != 'live') return;
    setState(() => _live = LiveBroadcastController(roomId: widget.roomId, isHost: _rs!.isHost));
  }

  void _onRoomStateChanged() {
    if (!mounted) return;
    final rs = _rs!;

    if (rs.kicked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You were removed from this room')));
      Navigator.of(context).pop();
      return;
    }
    if (rs.joinError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rs.joinError!)));
    }
    if (rs.micDenied != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rs.micDenied!)));
      rs.clearMicDenied();
    }
    if (rs.queueDenied != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rs.queueDenied!)));
      rs.clearQueueDenied();
    }

    // The host changed the room's type elsewhere (or another device) — pick
    // up the new fields so the video/voice/game UI switches over live.
    if (rs.typeChange != null && !identical(rs.typeChange, _lastHandledTypeChange)) {
      _lastHandledTypeChange = rs.typeChange;
      setState(() => _room = {...?_room, ...rs.typeChange!});
    }

    // Seed the queue with the room's own video once, host-only — mirrors
    // PartyPage.jsx's seededQueue effect.
    final room = _room;
    final items = (rs.queue['items'] as List?) ?? [];
    if (room != null && room['roomType'] == 'watch' && rs.isHost && !_seededQueue && items.isEmpty) {
      // room['title'] is the ROOM's own auto-generated name (e.g. "Alex's
      // Watch Party"), never the video's — falling back to it here used to
      // make the "now playing" display show the room's name instead of the
      // actual video until a real song got added. videoTitle/videoThumbnail
      // are the picked video's own metadata (see watch_room_creator.dart).
      rs.queueInit({
        'sourceType': room['sourceType'],
        'videoUrl': room['videoUrl'],
        'title': room['videoTitle'] ?? room['title'],
        'thumbnail': room['videoThumbnail'],
      });
      _seededQueue = true;
    }

    // Per-viewer watch history, logged whenever the current item changes.
    final currentIndex = rs.queue['currentIndex'] as int? ?? 0;
    if (items.isNotEmpty && currentIndex < items.length) {
      final current = Map<String, dynamic>.from(items[currentIndex] as Map);
      final videoUrl = current['videoUrl'] as String?;
      if (videoUrl != null && videoUrl != _loggedHistoryFor) {
        _loggedHistoryFor = videoUrl;
        ApiClient.post('/song-history', body: {
          'videoUrl': videoUrl,
          'title': current['title'],
          'thumbnail': current['thumbnail'],
          'sourceType': current['sourceType'],
        }).catchError((_) => null);
      }
    }

    setState(() {});
  }

  Future<void> _toggleLike(Map<String, dynamic>? item) async {
    final videoUrl = item?['videoUrl'] as String?;
    if (videoUrl == null) return;
    final isLiked = _likedUrls.contains(videoUrl);
    setState(() {
      if (isLiked) {
        _likedUrls.remove(videoUrl);
      } else {
        _likedUrls.add(videoUrl);
      }
    });
    try {
      if (isLiked) {
        await ApiClient.delete('/liked-songs', body: {'videoUrl': videoUrl});
      } else {
        await ApiClient.post('/liked-songs', body: {'videoUrl': videoUrl, 'title': item?['title'], 'thumbnail': item?['thumbnail'], 'sourceType': item?['sourceType']});
      }
    } catch (_) {
      setState(() {
        if (isLiked) {
          _likedUrls.add(videoUrl);
        } else {
          _likedUrls.remove(videoUrl);
        }
      });
    }
  }

  Future<void> _boost() async {
    try {
      final res = await ApiClient.post('/rooms/${widget.roomId}/boost', body: {'days': 1}) as Map<String, dynamic>;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Boosted until ${res['boostedUntil']}')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to boost')));
    }
  }

  Future<void> _shareRoom() async {
    // No deployed web-app domain exists yet — points at the backend host as
    // a placeholder; update once the web frontend has a production URL.
    final url = '${ApiClient.baseUrl}/party/${widget.roomId}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room link copied')));
  }

  void _openInvite() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteScreen(roomId: widget.roomId)));
  }

  void _openRoster() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openQueue() {
    final rs = _rs!;
    final isVoice = _room?['roomType'] == 'voice';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnimatedBuilder(
        animation: rs,
        builder: (context, _) => QueueSheetScreen(
          queue: rs.queue,
          isHost: rs.isHost,
          participantCount: rs.roster.length,
          onAdd: rs.queueAdd,
          onJump: rs.queueJump,
          onRemove: rs.queueRemove,
          onReorder: rs.queueReorder,
          onOpenRoster: _openRoster,
          audioOnly: isVoice,
          canPin: rs.canPin,
          canAddSongs: rs.settings['songPermission'] != 'host' || rs.isHost,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: Spinner(size: 28)));
    }
    if (_error != null || _room == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_rs?.joinError ?? "This room doesn't exist or you can't access it.", style: const TextStyle(color: AppColors.textDim), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to rooms')),
              ],
            ),
          ),
        ),
      );
    }

    final rs = _rs;
    if (rs == null) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: Spinner(size: 28)));
    }

    return AnimatedBuilder(
      animation: rs,
      builder: (context, _) => _buildRoom(context, rs),
    );
  }

  Widget _buildRoom(BuildContext context, RoomSocketController rs) {
    final room = _room!;
    final items = (rs.queue['items'] as List?) ?? [];
    final currentIndex = rs.queue['currentIndex'] as int? ?? 0;
    final currentItem = (items.isNotEmpty && currentIndex < items.length) ? Map<String, dynamic>.from(items[currentIndex] as Map) : null;
    final playerVideoUrl = currentItem?['videoUrl'] as String? ?? room['videoUrl'] as String?;
    final playerSourceType = currentItem?['sourceType'] as String? ?? room['sourceType'] as String?;
    // Picks the player widget by the current queue item's (or the room's,
    // for a plain single-video watch party) sourceType — 'drive' streams
    // through a native VideoPlayerController (see drive_video_player.dart),
    // everything else still goes through the YouTube-embedded SyncVideoPlayer.
    // Both share the same constructor shape and the same host-emits/
    // guest-applies sync contract, so this is the only place that branches.
    Widget player({required String mediaMode, bool compact = false}) {
      final liked = currentItem != null && _likedUrls.contains(currentItem['videoUrl']);
      // Keyed by the video itself (not by room type/layout), so switching
      // room types — which only changes mediaMode/compact — reads to
      // Flutter as "update this element's props", not "remove this
      // element, mount a new one", even though it's now nested under a
      // different parent than before.
      final playerKey = ValueKey('player-$playerSourceType-$playerVideoUrl');
      if (_webviewSourceTypes.contains(playerSourceType)) {
        return WebviewRoomPlayer(
          key: playerKey,
          videoUrl: playerVideoUrl,
          title: currentItem?['title'] as String? ?? room['title'] as String?,
          compact: compact,
        );
      }
      if (playerSourceType == 'drive') {
        return DriveVideoPlayer(
          key: playerKey,
          videoUrl: playerVideoUrl,
          roomId: widget.roomId,
          isHost: rs.isHost,
          playback: rs.playback,
          mediaMode: mediaMode,
          compact: compact,
          title: currentItem?['title'] as String? ?? room['title'] as String?,
          thumbnail: currentItem?['thumbnail'] as String?,
          onPlay: rs.play,
          onPause: rs.pause,
          onSeek: rs.seek,
          onRequestState: rs.requestState,
          onEnded: rs.queueNext,
          onSkip: rs.queueSkip,
          liked: liked,
          onToggleLike: () => _toggleLike(currentItem),
        );
      }
      return SyncVideoPlayer(
        key: playerKey,
        videoUrl: playerVideoUrl,
        isHost: rs.isHost,
        playback: rs.playback,
        mediaMode: mediaMode,
        compact: compact,
        title: currentItem?['title'] as String? ?? room['title'] as String?,
        thumbnail: currentItem?['thumbnail'] as String?,
        onPlay: rs.play,
        onPause: rs.pause,
        onSeek: rs.seek,
        onRequestState: rs.requestState,
        onEnded: rs.queueNext,
        onSkip: rs.queueSkip,
        liked: liked,
        onToggleLike: () => _toggleLike(currentItem),
      );
    }

    final isWatch = room['roomType'] == 'watch';
    final isGame = room['roomType'] == 'game';
    final isVoice = room['roomType'] == 'voice';
    final myId = context.read<AuthProvider>().user?.id;
    final activeMics = (rs.call['activeMics'] as List? ?? []).cast<String>();
    final pendingRequests = (rs.call['pendingRequests'] as List? ?? []).cast<String>();
    final maxSlots = rs.call['maxSlots'] as int? ?? 8;
    final myMicOn = myId != null && activeMics.contains(myId);
    final myMicRequested = myId != null && pendingRequests.contains(myId);

    // Agora only actually connects the instant someone's mic is really on
    // (see VoiceChatController.ensureInitialized's comment) — safe to call
    // on every build while myMicOn is true: it's memoized, and
    // setMicEnabled itself no-ops once already in the requested state.
    if (myMicOn) {
      _voice?.ensureInitialized().then((_) => _voice?.setMicEnabled(true));
    } else {
      _voice?.setMicEnabled(false);
    }

    void handleMicTap() {
      if (myMicOn) {
        rs.micOff();
      } else if (rs.isHost) {
        rs.micOn();
      } else if (myMicRequested) {
        rs.cancelMicRequest();
      } else if (rs.settings['micEnabled'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The host has disabled mics for now')));
      } else {
        rs.requestMic();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to the host')));
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      endDrawer: RosterSheet(
        roster: rs.roster,
        hostId: rs.hostId,
        isHost: rs.isHost,
        myUserId: myId,
        onKick: rs.kick,
        onMakeHost: rs.makeHost,
        roomType: room['roomType'] as String?,
        activeMics: activeMics,
        onInviteMic: rs.inviteMic,
      ),
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(room['title'] as String? ?? '', key: _hostKey, style: const TextStyle(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (isWatch)
            IconButton(
              tooltip: _viewModeOverride == 'audio' ? 'Switch to video (just for you)' : 'Switch to audio-only (just for you)',
              onPressed: () => setState(() {
                final effective = _viewModeOverride ?? (currentItem?['mediaMode'] as String? ?? 'video');
                _viewModeOverride = effective == 'audio' ? 'video' : 'audio';
              }),
              icon: Icon(
                (_viewModeOverride ?? (currentItem?['mediaMode'] as String? ?? 'video')) == 'audio' ? Icons.movie_outlined : Icons.headphones,
                color: AppColors.textDim,
              ),
            ),
          if (isWatch || isGame || isVoice)
            IconButton(
              tooltip: 'Find a song',
              onPressed: _openQueue,
              icon: const Icon(Icons.search, color: AppColors.textDim),
            ),
          TextButton(onPressed: _openRoster, child: Text('👥 ${rs.roster.length}', style: const TextStyle(color: AppColors.textDim))),
          if (rs.isHost && room['roomType'] != 'live')
            IconButton(
              tooltip: 'Room settings',
              onPressed: () => showRoomSettingsSheet(context, room: room, onChanged: _loadRoom),
              icon: const Icon(Icons.settings_outlined, color: AppColors.textDim),
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 0), child: BannerCarousel(placement: 'room')),
          // Room-type-specific content — free to change shape however it
          // needs to, since none of it holds long-lived playback state.
          if (!isWatch)
            Padding(
              padding: const EdgeInsets.all(12),
              child: room['roomType'] == 'live' && _live != null
                  ? LiveVideoView(controller: _live!, isHost: rs.isHost)
                  : isGame
                      ? GameBoardView(
                          gameType: room['gameType'] as String?,
                          game: rs.game,
                          myUserId: myId,
                          isHost: rs.isHost,
                          onJoin: rs.gameJoin,
                          onMove: rs.gameMove,
                          onReset: rs.gameReset,
                        )
                      : isVoice
                          ? VoiceStageView(
                              roster: rs.roster,
                              activeMics: activeMics,
                              pendingRequests: pendingRequests,
                              maxSlots: maxSlots,
                              hostId: rs.hostId,
                              myUserId: myId,
                              isHost: rs.isHost,
                              onApprove: rs.approveMic,
                              onDeny: rs.denyMic,
                              onRemove: rs.removeMic,
                            )
                          : AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                                alignment: Alignment.center,
                                child: const Text('🎙️', style: TextStyle(fontSize: 48)),
                              ),
                            ),
            ),
          // The player — ALWAYS at this same position in the tree whenever
          // there's something to play, regardless of room type. Switching
          // room types (watch -> voice -> game, via Room Settings) used to
          // dispose and recreate this widget every time, because it used
          // to live at a different nesting depth per room-type branch —
          // that silently killed the live YoutubePlayerController/
          // VideoPlayerController and restarted the video, which is what
          // "song desyncs on room-type switch" actually was. Keeping it in
          // one fixed spot, sized differently (big for watch, compact bar
          // otherwise) instead of being conditionally nested, lets Flutter
          // recognize it as the same widget across a type change instead
          // of tearing it down.
          if (isWatch || currentItem != null)
            Padding(
              padding: EdgeInsets.fromLTRB(12, isWatch ? 12 : 0, 12, 0),
              child: player(
                mediaMode: isWatch ? (_viewModeOverride ?? (currentItem?['mediaMode'] as String? ?? 'video')) : 'audio',
                compact: !isWatch && isVoice,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ParticipantAvatarRow(roster: rs.roster, onOpenRoster: _openRoster),
          ),
          if (rs.poll['active'] == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: GestureDetector(
                onTap: () => showPollBottomSheet(context, poll: rs.poll, myUserId: myId ?? '', isHost: rs.isHost, onVote: rs.votePoll, onReset: rs.resetPoll),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                  child: const Row(
                    children: [
                      Text('📊', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text('Poll Active', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: handleMicTap,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: myMicOn ? AppColors.danger : (myMicRequested ? AppColors.gold : Colors.black),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(myMicOn ? Icons.mic : Icons.mic_off, color: Colors.white, size: 18),
                    ),
                  ),
                  if (rs.isHost) _iconButton('🚀', _boost, color: AppColors.gold),
                  _iconButton('🎁', () => showGiftBottomSheet(context, toUserId: room['hostId'] as String? ?? '', roomId: widget.roomId, targetKey: _hostKey), color: AppColors.gold),
                  if (rs.isHost)
                    _iconButton('📊', () => showPollCreatorBottomSheet(context, onCreate: rs.createPoll))
                  else if (rs.poll['active'] == true)
                    _iconButton('📊', () => showPollBottomSheet(context, poll: rs.poll, myUserId: myId ?? '', isHost: rs.isHost, onVote: rs.votePoll, onReset: rs.resetPoll)),
                  if (isWatch || isGame || isVoice)
                    _iconButton('📑', _openQueue, badge: items.isEmpty ? null : items.length),
                  _iconButton('🔗', _shareRoom),
                  _iconButton('👥➕', _openInvite),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: ChatPanel(messages: rs.messages, onSend: rs.sendMessage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(String label, VoidCallback onTap, {Color? color, int? badge}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(color: color ?? AppColors.textDim, fontSize: 16)),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rs?.removeListener(_onRoomStateChanged);
    _rs?.leave();
    _voice?.dispose();
    _live?.dispose();
    super.dispose();
  }
}
