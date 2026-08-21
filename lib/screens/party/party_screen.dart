import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/active_room_holder.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/pip_service.dart';
import '../../core/profile_nav.dart';
import '../../core/room_presence_service.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/club_room_colors.dart';
import '../../theme/vola_party_colors.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/game_board_view.dart';
import '../../widgets/live_video_view.dart';
import '../../widgets/participant_avatar_row.dart';
import '../../widgets/poll_bottom_sheet.dart';
import '../../widgets/poll_creator_bottom_sheet.dart';
import '../../widgets/room_host_card.dart';
import '../../widgets/room_settings_sheet.dart';
import '../../widgets/share_row.dart';
import '../../widgets/spinner.dart';
import '../../widgets/voice_stage_view.dart';
import '../lobby/invite_screen.dart';
import 'chat_overlay.dart';
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

class _PartyScreenState extends State<PartyScreen> with WidgetsBindingObserver {
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

  // Tracks what we last told the native PIP channel, so we only call it on
  // an actual change instead of every rebuild.
  bool? _lastAutoPipEnabled;
  void _syncAutoPip(bool enabled) {
    if (_lastAutoPipEnabled == enabled) return;
    _lastAutoPipEnabled = enabled;
    PipService.setAutoPipEnabled(enabled);
  }

  // Native auto-PIP (MainActivity.kt's onUserLeaveHint) hasn't been firing
  // reliably on every device (confirmed live: zero "FlingPip" logs on a
  // Home-button press) — this is a separate, more reliable trigger that
  // doesn't depend on that native callback at all. Flutter's own lifecycle
  // observer already has to work correctly for the video players' own
  // backgrounded/resumed handling, so driving PIP entry from here instead
  // sidesteps whatever's wrong with onUserLeaveHint on some devices.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` (not `paused`) — the Activity is still resumed/visible at
    // that point, which entering PIP requires; by `paused` it's too late.
    if (state == AppLifecycleState.inactive && (_lastAutoPipEnabled ?? false)) {
      PipService.enterPip();
    }
  }

  // True once minimizing was rejected in favor of an explicit "Leave Room"
  // — see _leaveRoom(). Guards dispose() from tearing down a connection
  // that a plain back-navigation/tab-switch should leave alone.
  bool _didLeaveRoom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reattaching to a room already kept alive by ActiveRoomHolder (the
    // user minimized it earlier, not left it) — reuse everything instead
    // of rejoining from scratch, which would otherwise show a blank
    // "joining…" state and briefly desync from whatever's already playing.
    if (ActiveRoomHolder.roomId == widget.roomId && ActiveRoomHolder.controller != null) {
      _room = ActiveRoomHolder.room;
      _rs = ActiveRoomHolder.controller;
      _voice = ActiveRoomHolder.voice;
      _live = ActiveRoomHolder.live;
      _loading = false;
      _rs!.addListener(_onRoomStateChanged);
      _loadLiked();
      return;
    }
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
      RoomPresenceService.start((_room?['title'] as String?) ?? 'Watch Party');
      _maybeInitLive();
      _maybeRegisterActiveRoom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
    RoomPresenceService.start((_room?['title'] as String?) ?? 'Watch Party');
    _voice = VoiceChatController(roomId: widget.roomId);
    _maybeInitLive();
    _maybeRegisterActiveRoom();
  }

  // _room (REST) and _rs (socket) load independently and finish in
  // whichever order the network happens to resolve them — this fires from
  // both paths and only actually registers once both are in.
  void _maybeRegisterActiveRoom() {
    final room = _room;
    final rs = _rs;
    if (room == null || rs == null) return;
    ActiveRoomHolder.set(roomId: widget.roomId, controller: rs, room: room, voice: _voice, live: _live);
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
      _didLeaveRoom = true; // A real removal, not a minimize — tear the connection down too.
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
    // PartyPage.jsx's seededQueue effect. Skipped entirely for WebView-only
    // platforms (Netflix/Hotstar/etc.): those never have a real fetched
    // video title, and falling back to room['title'] (the room's own
    // auto-generated name, e.g. "Alex's Watch Party") made "now playing"
    // show the room name instead of an actual song — which then got
    // permanently logged into the viewer's song-history below. There's no
    // synced "song" for these platforms at all, so showing nothing is
    // correct, not a gap.
    final room = _room;
    final items = (rs.queue['items'] as List?) ?? [];
    final roomSourceType = room?['sourceType'] as String?;
    if (room != null &&
        room['roomType'] == 'watch' &&
        rs.isHost &&
        !_seededQueue &&
        items.isEmpty &&
        !_webviewSourceTypes.contains(roomSourceType) &&
        room['videoTitle'] != null) {
      rs.queueInit({
        'sourceType': roomSourceType,
        'videoUrl': room['videoUrl'],
        'title': room['videoTitle'],
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
      if (!mounted) return;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Boosted until ${res['boostedUntil']}')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to boost')));
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

  // Voice/Game/Live rooms don't keep chat inline (see the mockups — the
  // speaker grid / board needs the vertical space instead), so it opens as
  // a sheet from the chat icon in the action row. Watch Party is the
  // exception — see ChatOverlay, which floats it over the stage instead.
  void _openChatSheet() {
    final rs = _rs!;
    final myId = context.read<AuthProvider>().user?.id;
    final isVoice = _room?['roomType'] == 'voice';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isVoice ? ClubRoomColors.surface : AppColors.surface,
      builder: (_) => AnimatedBuilder(
        animation: rs,
        builder: (context, _) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: SafeArea(
            top: false,
            child: ChatPanel(messages: rs.messages, onSend: rs.sendMessage, myUserId: myId, clubRoomTheme: isVoice),
          ),
        ),
      ),
    );
  }

  // Lets the unified source picker's in-room "switch source" tiles (see
  // SourcePickerBody) replace what a streaming-platform room is set to
  // without everyone leaving — mirrors RoomSettingsSheet's own PATCH
  // /rooms/:id/type call. Reloads afterward rather than trusting the
  // socket round-trip alone, same as RoomSettingsSheet's onChanged does.
  Future<void> _switchRoomSource(String sourceType, String videoUrl, {String? videoTitle, String? videoThumbnail}) async {
    await ApiClient.patch('/rooms/${widget.roomId}/type', body: {
      'roomType': 'watch',
      'sourceType': sourceType,
      'videoUrl': videoUrl,
      // Explicit null, not omitted, when the caller has no real title
      // (streaming platforms) — omitting would leave whatever title the
      // room had *before* the switch attached to a now-unrelated video
      // (the backend only preserves a field when it's genuinely absent
      // from the request, not when it's null). The YouTube Surf upgrade
      // path (webview_browse_screen.dart) supplies a real title/thumbnail
      // here instead of null.
      'videoTitle': videoTitle,
      'videoThumbnail': videoThumbnail,
    });
    await _loadRoom();
  }

  void _openQueue() {
    final rs = _rs!;
    final isVoice = _room?['roomType'] == 'voice';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnimatedBuilder(
        animation: rs,
        builder: (context, _) => QueueSheetScreen(
          roomId: widget.roomId,
          queue: rs.queue,
          isHost: rs.isHost,
          participantCount: rs.roster.length,
          onAdd: rs.queueAdd,
          onJump: rs.queueJump,
          onRemove: rs.queueRemove,
          onReorder: rs.queueReorder,
          onOpenRoster: _openRoster,
          onSwitchSource: _switchRoomSource,
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
    // Auto-PIP only while there's actually a watch-party video up — pressing
    // home from Home/Feed/chat/etc. shouldn't pop a PIP window with nothing
    // worth watching in it.
    _syncAutoPip(isWatch && currentItem != null);
    // Voice Room and Watch Party each get their own dedicated reskin (see
    // club_room_colors.dart / vola_party_colors.dart) — every other room
    // type keeps the app's normal claymorphism theme via AppColors,
    // unchanged below. Watch Party's background is an actual gradient
    // (see roomBgGradient), not a flat color, so roomBg only matters for
    // Voice/default.
    final roomBg = isVoice ? ClubRoomColors.bg : AppColors.bg;
    final roomBgGradient = isWatch ? VolaPartyColors.bgGradient : null;
    final roomSurface = isVoice ? ClubRoomColors.surface : (isWatch ? VolaPartyColors.surface : AppColors.surface);
    final roomBorder = isVoice ? ClubRoomColors.border : (isWatch ? VolaPartyColors.border : AppColors.border);
    final roomTextDim = isVoice ? ClubRoomColors.textDim : (isWatch ? VolaPartyColors.textDim : AppColors.textDim);
    final roomPrimary = isVoice ? ClubRoomColors.primary : (isWatch ? VolaPartyColors.primary : AppColors.primary);
    final roomGold = isVoice ? ClubRoomColors.gold : (isWatch ? VolaPartyColors.gold : AppColors.gold);
    final roomDanger = isVoice ? ClubRoomColors.danger : (isWatch ? VolaPartyColors.danger : AppColors.danger);
    final roomText = isVoice ? ClubRoomColors.text : (isWatch ? VolaPartyColors.text : AppColors.text);
    final myId = context.read<AuthProvider>().user?.id;
    final hostRoster = rs.roster.where((r) => r.userId == rs.hostId);
    final hostName = hostRoster.isNotEmpty ? hostRoster.first.name : (room['hostName'] as String? ?? 'Host');
    final hostAvatarUrl = hostRoster.isNotEmpty ? hostRoster.first.avatarUrl : null;
    final boostedUntilRaw = room['boostedUntil'] as String?;
    final isBoosted = boostedUntilRaw != null && (DateTime.tryParse(boostedUntilRaw)?.isAfter(DateTime.now()) ?? false);
    final activeMics = (rs.call['activeMics'] as List? ?? []).cast<String>();
    final pendingRequests = (rs.call['pendingRequests'] as List? ?? []).cast<String>();
    final mutedMics = (rs.call['mutedMics'] as List? ?? []).cast<String>();
    final maxSlots = rs.call['maxSlots'] as int? ?? 8;
    final myMicForceMuted = myId != null && mutedMics.contains(myId);
    final myMicOn = myId != null && activeMics.contains(myId) && !myMicForceMuted;
    final myMicRequested = myId != null && pendingRequests.contains(myId);

    // Agora only actually connects the instant someone's mic is really on
    // (see VoiceChatController.ensureInitialized's comment) — safe to call
    // on every build while myMicOn is true: it's memoized, and
    // setMicEnabled itself no-ops once already in the requested state.
    // myMicOn already folds in myMicForceMuted, so a host force-mute is
    // enforced here the same way losing a stage slot already is — the
    // client can't just re-enable its own mic against server state.
    if (myMicOn) {
      _voice?.ensureInitialized().then((_) => _voice?.setMicEnabled(true));
    } else {
      _voice?.setMicEnabled(false);
    }

    void handleMicTap() {
      if (myMicForceMuted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The host has muted you')));
      } else if (myMicOn) {
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

    return ValueListenableBuilder<bool>(
      valueListenable: PipService.isInPip,
      builder: (context, inPip, _) {
        if (inPip && isWatch) {
          // The real Android PIP window is tiny — no room for the app bar,
          // chat, or controls, just the video itself.
          return Scaffold(
            backgroundColor: Colors.black,
            body: player(mediaMode: _viewModeOverride ?? (currentItem?['mediaMode'] as String? ?? 'video')),
          );
        }
        return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isWatch ? Colors.transparent : roomBg,
      endDrawer: RosterSheet(
        roster: rs.roster,
        hostId: rs.hostId,
        isHost: rs.isHost,
        myUserId: myId,
        onKick: rs.kick,
        onMakeHost: rs.makeHost,
        roomType: room['roomType'] as String?,
        activeMics: activeMics,
        mutedMics: mutedMics,
        onInviteMic: rs.inviteMic,
        onForceMute: rs.forceMuteMic,
        onForceUnmute: rs.forceUnmuteMic,
      ),
      appBar: AppBar(
        backgroundColor: isVoice ? ClubRoomColors.surface.withValues(alpha: 0.85) : (isWatch ? VolaPartyColors.surface.withValues(alpha: 0.7) : null),
        foregroundColor: isVoice ? ClubRoomColors.text : (isWatch ? VolaPartyColors.text : null),
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
                color: roomTextDim,
              ),
            ),
          if (isWatch || isGame || isVoice)
            IconButton(
              tooltip: 'Find a song',
              onPressed: _openQueue,
              icon: Icon(Icons.search, color: roomTextDim),
            ),
          ShareRow(
            text: 'Join "${room['title'] ?? 'my room'}" on Insync',
            url: '${ApiClient.baseUrl}/rooms/${widget.roomId}',
            iconAsset: 'assets/icons/app/share_lobby.png',
          ),
          // Pill-styled participant count, matching the redesign's .pill
          // component (WatchPartyDark.dc.html) instead of a plain TextButton.
          GestureDetector(
            onTap: _openRoster,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: roomSurface, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_alt_rounded, size: 13, color: roomTextDim),
                const SizedBox(width: 5),
                Text('${rs.roster.length}', style: TextStyle(color: roomTextDim, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          if (rs.isHost && room['roomType'] != 'live')
            IconButton(
              tooltip: 'Room settings',
              onPressed: () => showRoomSettingsSheet(context, room: room, onChanged: _loadRoom),
              icon: Icon(Icons.settings_outlined, color: roomTextDim),
            ),
          // Distinct from the back button on purpose — back just minimizes
          // (the room keeps running, see ActiveRoomHolder), this is the
          // only thing that actually leaves.
          IconButton(
            tooltip: 'Leave room',
            onPressed: _leaveRoom,
            icon: Icon(Icons.logout_rounded, color: roomTextDim),
          ),
        ],
      ),
      body: GestureDetector(
        // Swipe right-to-left opens the Queue — same destination as tapping
        // the queue icon, just a gesture shortcut. QueueSheetScreen's own
        // swipe (left-to-right) mirrors this to close back to the room.
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -250) _openQueue();
        },
        child: Container(
        decoration: roomBgGradient != null ? BoxDecoration(gradient: roomBgGradient) : null,
        child: Column(
        children: [
          // Room-type-specific content — free to change shape however it
          // needs to, since none of it holds long-lived playback state.
          // Wrapped in Expanded+scroll (not just Padding) now that chat no
          // longer eats the remaining space below for these types — same
          // exact position in the Column either way, so this doesn't touch
          // the player-identity invariant described below.
          if (!isWatch)
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
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
              padding: isWatch ? EdgeInsets.zero : const EdgeInsets.fromLTRB(12, 12, 12, 0),
              // Full screen width, real 16:9 (no cropping), flush under the
              // header — the player widgets already wrap themselves in
              // AspectRatio(16/9) internally, so this just needs to not
              // fight that. Same widget, same position in this Column
              // either way, whatever platform the video is from.
              child: isWatch
                  ? player(
                      mediaMode: _viewModeOverride ?? (currentItem?['mediaMode'] as String? ?? 'video'),
                      compact: false,
                    )
                  : player(
                      mediaMode: 'audio',
                      // Compact bar for every non-watch type (voice, game, live) —
                      // this used to only check isVoice, so a game room with a
                      // queued track rendered the full-size player stacked below
                      // the GameBoardView instead of a small audio bar.
                      compact: true,
                    ),
            ),
          if (isBoosted)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: roomSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: roomBorder)),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: roomGold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Featured', style: TextStyle(color: roomGold, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('This watch party is featured', style: TextStyle(color: roomTextDim, fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: roomTextDim),
                  ],
                ),
              ),
            ),
          if (isWatch)
            RoomHostCard(
              avatarUrl: hostAvatarUrl,
              name: hostName,
              textColor: roomText,
              goldColor: roomGold,
              onTap: () => openProfile(context, rs.hostId),
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
                  decoration: BoxDecoration(color: roomPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: roomPrimary.withValues(alpha: 0.3))),
                  child: Row(
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('Poll Active', style: TextStyle(color: roomPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          // Everything below this point renders strictly AFTER the player in
          // the tree — restructuring it can't affect the player's identity
          // across a room-type switch, since that's governed by what
          // precedes it (see the big comment above the player block), which
          // is untouched here.
          if (isWatch)
            // Chat floats over an open "stage" instead of living in its own
            // boxed panel — matches WatchPartyDark.dc.html. The action
            // buttons (mic/boost/gift/poll/queue/share/invite) become a
            // floating vertical rail instead of a horizontal scroll row, but
            // are otherwise the exact same buttons/handlers as every other
            // room type gets below.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 54),
                      child: ChatOverlay(
                        messages: rs.messages,
                        onSend: rs.sendMessage,
                        myUserId: myId,
                        primaryColor: roomPrimary,
                        textColor: roomText,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 46,
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _floatingIconButton(
                            myMicOn ? Icons.mic : Icons.mic_off,
                            handleMicTap,
                            color: myMicOn ? roomDanger : (myMicRequested ? roomGold : null),
                          ),
                          if (rs.isHost) _floatingIconButtonEmoji('🚀', _boost, color: roomGold),
                          _floatingIconButtonEmoji('🎁', () => showGiftBottomSheet(context, toUserId: room['hostId'] as String? ?? '', roomId: widget.roomId, targetKey: _hostKey), color: roomGold),
                          if (rs.isHost)
                            _floatingIconButtonEmoji('📊', () => showPollCreatorBottomSheet(context, onCreate: rs.createPoll))
                          else if (rs.poll['active'] == true)
                            _floatingIconButtonEmoji('📊', () => showPollBottomSheet(context, poll: rs.poll, myUserId: myId ?? '', isHost: rs.isHost, onVote: rs.votePoll, onReset: rs.resetPoll)),
                          _floatingIconButton(Icons.queue_music_rounded, _openQueue, badge: items.isEmpty ? null : items.length, badgeColor: roomPrimary),
                          _floatingIconButton(Icons.share_rounded, _shareRoom),
                          _floatingIconButton(Icons.person_add_alt_1_rounded, _openInvite),
                        ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
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
                          color: myMicOn ? roomDanger : (myMicRequested ? roomGold : Colors.black),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(myMicOn ? Icons.mic : Icons.mic_off, color: Colors.white, size: 18),
                      ),
                    ),
                    _iconButton('💬', _openChatSheet, borderColor: roomBorder, badgeColor: roomPrimary),
                    if (rs.isHost) _iconButton('🚀', _boost, color: roomGold, borderColor: roomBorder, badgeColor: roomPrimary),
                    _iconButton(
                      '🎁',
                      () => showGiftBottomSheet(context, toUserId: room['hostId'] as String? ?? '', roomId: widget.roomId, targetKey: _hostKey),
                      color: roomGold,
                      borderColor: roomBorder,
                      badgeColor: roomPrimary,
                    ),
                    if (rs.isHost)
                      _iconButton('📊', () => showPollCreatorBottomSheet(context, onCreate: rs.createPoll), borderColor: roomBorder, badgeColor: roomPrimary)
                    else if (rs.poll['active'] == true)
                      _iconButton('📊', () => showPollBottomSheet(context, poll: rs.poll, myUserId: myId ?? '', isHost: rs.isHost, onVote: rs.votePoll, onReset: rs.resetPoll), borderColor: roomBorder, badgeColor: roomPrimary),
                    if (isGame || isVoice)
                      _iconButton('📑', _openQueue, badge: items.isEmpty ? null : items.length, borderColor: roomBorder, badgeColor: roomPrimary),
                    _iconButton('🔗', _shareRoom, borderColor: roomBorder, badgeColor: roomPrimary),
                    _iconButton('👥➕', _openInvite, borderColor: roomBorder, badgeColor: roomPrimary, iconAsset: 'assets/icons/app/invite_in_room.png'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        ),
      ),
      ),
    );
      },
    );
  }

  Widget _iconButton(String label, VoidCallback onTap, {Color? color, int? badge, Color? borderColor, Color? badgeColor, String? iconAsset}) {
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
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor ?? AppColors.border)),
              alignment: Alignment.center,
              child: iconAsset != null ? Image.asset(iconAsset, width: 22, height: 22) : Text(label, style: TextStyle(color: color ?? AppColors.textDim, fontSize: 16)),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: badgeColor ?? AppColors.primary, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Circular, translucent action buttons for Watch Party's floating rail —
  // same tap targets as _iconButton's square/bordered ones, just styled to
  // sit on top of the video/chat stage instead of a bordered chrome strip.
  Widget _floatingIconButton(IconData icon, VoidCallback onTap, {Color? color, int? badge, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.45)),
              alignment: Alignment.center,
              child: Icon(icon, color: color ?? Colors.white, size: 19),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: badgeColor ?? AppColors.primary, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _floatingIconButtonEmoji(String label, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.45)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: color, fontSize: 17)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rs?.removeListener(_onRoomStateChanged);
    // A plain pop (back button, gesture, switching tabs) is a minimize —
    // ActiveRoomHolder keeps the connection/controllers alive so the room
    // is still there (still playing, still in chat) if the user comes
    // back, same as any other music/video app. Only _leaveRoom() actually
    // tears this down; see its call to ActiveRoomHolder.leave().
    if (_didLeaveRoom) {
      ActiveRoomHolder.leave();
    }
    PipService.setAutoPipEnabled(false);
    super.dispose();
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave this room?'),
        content: const Text("You'll stop being part of the room — anyone else stays. Just switching screens or apps doesn't need this; the room keeps going in the background until you come back."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _didLeaveRoom = true;
    Navigator.of(context).pop();
  }
}
