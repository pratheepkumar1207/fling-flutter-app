import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/active_room_holder.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/pip_service.dart';
import '../../core/room_presence_service.dart';
import '../../core/room_source_types.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/vola_party_colors.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/game_board_view.dart';
import '../../widgets/glass.dart';
import '../../widgets/live_video_view.dart';
import '../../widgets/participant_avatar_row.dart';
import '../../widgets/poll_bottom_sheet.dart';
import '../../widgets/poll_creator_bottom_sheet.dart';
import '../../widgets/room_settings_sheet.dart';
import '../../widgets/share_bottom_sheet.dart';
import '../../widgets/spinner.dart';
import '../../widgets/voice_stage_view.dart';
import '../lobby/invite_screen.dart';
import 'chat_overlay.dart';
import 'drive_video_player.dart';
import 'live_broadcast_controller.dart';
import 'queue_sheet.dart';
import 'roster_sheet.dart';
import 'room_socket_controller.dart';
import 'sync_video_player.dart';
import 'video_suggestions_panel.dart';
import 'voice_chat_controller.dart';
import 'webview_room_player.dart';

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
  // True while the chat input has focus (keyboard up) — hides the AppBar
  // so the video/audio player slides up into its old spot and chat gets
  // the freed-up space below instead of fighting that chrome for room.
  // See ChatOverlay.onFocusChanged.
  bool _chatFocused = false;
  void _setChatFocused(bool v) {
    if (_chatFocused != v) setState(() => _chatFocused = v);
  }

  // OTT rooms (Netflix/Prime/etc., via WebviewRoomPlayer) get an immersive
  // full-screen player instead of the usual 16:9 box + always-visible chat
  // below — chat becomes an on-demand slide-up panel instead, toggled by
  // this. Irrelevant (and left false) for every other source type.
  bool _ottChatOpen = false;

  // Right-to-left swipe ON THE PLAYER ITSELF shrinks it into a corner and
  // shows a "pin something to play next" suggestion grid — a different
  // gesture target than the existing right-to-left-anywhere-else swipe that
  // opens the Queue sheet (see the body GestureDetector below), so a drag's
  // start position decides which one it means instead of both firing.
  bool _suggestionsMode = false;
  final _playerAreaKey = GlobalKey();
  Offset? _dragStartGlobal;
  // Last queue:promptPin token this screen has already reacted to — see
  // room_socket_controller.dart's promptPinToken. Compared (not just
  // read) so a second dry queue after the first prompt was dismissed
  // still reopens the grid.
  int _lastPromptPinToken = 0;
  // A next-track vote only runs for 10s — waiting for someone to notice and
  // tap the small "Poll Active" banner (the normal way to open it) would
  // burn a chunk of that window, so this pops the sheet open immediately
  // instead. Guards against reopening it every rebuild while the same vote
  // is still active, and resets once it isn't so the next one still opens.
  bool _nextTrackVoteShown = false;

  // Watch Party's collapsing header — scrolling the chat below up hides the
  // player/banners toward the top (see the NestedScrollView in build()); the
  // down-arrow button restores it. _playerCollapsed just drives whether that
  // button shows, based on the controller's own offset.
  final _watchScrollController = ScrollController();
  bool _playerCollapsed = false;
  // Whatever video was showing last time we checked — a change means a new
  // video started playing (queue advanced, host switched source, etc.), so
  // the header should snap back open instead of staying collapsed on
  // whatever the viewer scrolled to before.
  String? _lastSeenPlayerVideoUrl;

  void _onWatchScroll() {
    final collapsed =
        _watchScrollController.hasClients && _watchScrollController.offset > 40;
    if (collapsed != _playerCollapsed) {
      setState(() => _playerCollapsed = collapsed);
    }
  }

  void _scrollWatchHeaderToTop() {
    if (!_watchScrollController.hasClients) return;
    _watchScrollController.animateTo(0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  bool _dragStartedOnPlayer() {
    final global = _dragStartGlobal;
    if (global == null) return false;
    final box = _playerAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(global);
  }

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
    _watchScrollController.addListener(_onWatchScroll);
    // Tells persistent_room_audio.dart's hidden player it can stand down —
    // this screen's own (visible, full-UI) player is about to be the one
    // actually producing audio. Cleared in dispose().
    ActiveRoomHolder.isRoomScreenVisible.value = true;
    // Reattaching to a room already kept alive by ActiveRoomHolder (the
    // user minimized it earlier, not left it) — reuse everything instead
    // of rejoining from scratch, which would otherwise show a blank
    // "joining…" state and briefly desync from whatever's already playing.
    if (ActiveRoomHolder.roomId == widget.roomId &&
        ActiveRoomHolder.controller != null) {
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
        _likedUrls = (data as List)
            .map((s) => (s as Map)['videoUrl'] as String? ?? '')
            .toSet();
      });
    } catch (_) {}
  }

  void _initSocket() {
    final socket = context.read<SocketService>().socket;
    final myId = context.read<AuthProvider>().user?.id;
    final rs = RoomSocketController(
        socket: socket, roomId: widget.roomId, myUserId: myId);
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
    ActiveRoomHolder.set(
        roomId: widget.roomId,
        controller: rs,
        room: room,
        voice: _voice,
        live: _live);
  }

  void _maybeInitLive() {
    if (_live != null || _room == null || _rs == null) return;
    if (_room!['roomType'] != 'live') return;
    setState(() => _live =
        LiveBroadcastController(roomId: widget.roomId, isHost: _rs!.isHost));
  }

  void _onRoomStateChanged() {
    if (!mounted) return;
    final rs = _rs!;

    if (rs.kicked) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You were removed from this room')));
      _didLeaveRoom =
          true; // A real removal, not a minimize — tear the connection down too.
      Navigator.of(context).pop();
      return;
    }
    if (rs.joinError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(rs.joinError!)));
    }
    if (rs.micDenied != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(rs.micDenied!)));
      rs.clearMicDenied();
    }
    if (rs.queueDenied != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(rs.queueDenied!)));
      rs.clearQueueDenied();
    }
    // @mention pop-up/sound is handled globally now (see
    // mention_notifier.dart, mounted in AppShell) — that fires no matter
    // which screen is showing, not just while this one is mounted.

    // The host changed the room's type elsewhere (or another device) — pick
    // up the new fields so the video/voice/game UI switches over live.
    if (rs.typeChange != null &&
        !identical(rs.typeChange, _lastHandledTypeChange)) {
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
        !webviewSourceTypes.contains(roomSourceType) &&
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
        await ApiClient.post('/liked-songs', body: {
          'videoUrl': videoUrl,
          'title': item?['title'],
          'thumbnail': item?['thumbnail'],
          'sourceType': item?['sourceType']
        });
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
      await ApiClient.post('/rooms/${widget.roomId}/boost', body: {'days': 1})
          as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Boosted — more visibility to help you get more participants'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to boost')));
      }
    }
  }

  Future<void> _shareRoom() async {
    // The room's own control-bar share action — was a plain clipboard copy,
    // now opens the same "Share to" bottom sheet (apps + Copy Link) the
    // AppBar's share icon used to, since that one's been removed in favor
    // of this being the room's single share entry point.
    final room = _room;
    await showShareBottomSheet(
      context,
      text: 'Join "${room?['title'] ?? 'my room'}" on Insync',
      url: '${ApiClient.baseUrl}/rooms/${widget.roomId}',
    );
  }

  void _openInvite() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InviteScreen(roomId: widget.roomId)));
  }

  void _openRoster() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  // Lets the unified source picker's in-room "switch source" tiles (see
  // SourcePickerBody) replace what a streaming-platform room is set to
  // without everyone leaving — mirrors RoomSettingsSheet's own PATCH
  // /rooms/:id/type call. Reloads afterward rather than trusting the
  // socket round-trip alone, same as RoomSettingsSheet's onChanged does.
  Future<void> _switchRoomSource(String sourceType, String videoUrl,
      {String? videoTitle, String? videoThumbnail}) async {
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
    final roomType = _room?['roomType'];
    // Voice and Game rooms both have no video to show — see
    // SourcePickerBody.audioOnly's comment for why this restricts the
    // picker to just YouTube Music instead of the full source grid.
    final audioOnly = roomType == 'voice' || roomType == 'game';
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
          audioOnly: audioOnly,
          canPin: rs.canPin,
          canAddSongs: rs.settings['songPermission'] != 'host' || rs.isHost,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: Spinner(size: 28)));
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
                Text(
                    _rs?.joinError ??
                        "This room doesn't exist or you can't access it.",
                    style: const TextStyle(color: AppColors.textDim),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to rooms')),
              ],
            ),
          ),
        ),
      );
    }

    final rs = _rs;
    if (rs == null) {
      return const Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: Spinner(size: 28)));
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
    final currentItem = (items.isNotEmpty && currentIndex < items.length)
        ? Map<String, dynamic>.from(items[currentIndex] as Map)
        : null;
    final playerVideoUrl =
        currentItem?['videoUrl'] as String? ?? room['videoUrl'] as String?;
    final playerSourceType =
        currentItem?['sourceType'] as String? ?? room['sourceType'] as String?;
    final isWatch = room['roomType'] == 'watch';
    final isGame = room['roomType'] == 'game';
    final isVoice = room['roomType'] == 'voice';
    // OTT sources (Netflix/Prime/etc.) get the immersive full-screen
    // treatment — see _ottChatOpen and the player block below. Only makes
    // sense for a real watch party, not a compact/voice/game bar.
    final ottImmersive =
        isWatch && webviewSourceTypes.contains(playerSourceType);
    // The queue just ran dry with nothing pinned — see
    // syncHandler.js's queue:promptPin. Reacting here (not via a separate
    // listener) means it's applied before this same build renders, same
    // pattern _syncAutoPip below uses for a server-driven side effect.
    if (isWatch && rs.promptPinToken != _lastPromptPinToken) {
      _lastPromptPinToken = rs.promptPinToken;
      _suggestionsMode = true;
    }
    // Picks the player widget by the current queue item's (or the room's,
    // for a plain single-video watch party) sourceType — 'drive' streams
    // through a native VideoPlayerController (see drive_video_player.dart),
    // everything else still goes through the YouTube-embedded SyncVideoPlayer.
    // Both share the same constructor shape and the same host-emits/
    // guest-applies sync contract, so this is the only place that branches.
    Widget player({required String mediaMode, bool compact = false}) {
      final liked =
          currentItem != null && _likedUrls.contains(currentItem['videoUrl']);
      final onSkipPrevious = (rs.isHost && currentIndex > 0)
          ? () => rs.queueJump(currentIndex - 1)
          : null;
      // Keyed by the video itself (not by room type/layout), so switching
      // room types — which only changes mediaMode/compact — reads to
      // Flutter as "update this element's props", not "remove this
      // element, mount a new one", even though it's now nested under a
      // different parent than before.
      final playerKey = ValueKey('player-$playerSourceType-$playerVideoUrl');
      if (webviewSourceTypes.contains(playerSourceType)) {
        return WebviewRoomPlayer(
          key: playerKey,
          videoUrl: playerVideoUrl,
          title: currentItem?['title'] as String? ?? room['title'] as String?,
          compact: compact,
          // Always the standard 16:9 box, positioned at the top of the
          // ottImmersive Expanded slot below — not full-bleed. Full-bleed
          // stretched the video across however tall the screen is (often
          // much taller than 16:9), which just leaves visible blank
          // letterbox space around the actual video instead of the tight
          // "16:9 box, exact video fit" look wanted here.
          fillHeight: false,
          isHost: rs.isHost,
          playback: rs.playback,
          onPlay: rs.play,
          onPause: rs.pause,
          onSeek: rs.seek,
          onRequestState: rs.requestState,
          onSkip: rs.isHost ? rs.queueSkip : null,
          onVoteSkip: rs.isHost ? null : rs.voteSkip,
          skipVoteCount: (rs.skipVote['count'] as int?) ?? 0,
          skipVoteRequired: (rs.skipVote['required'] as int?) ?? 1,
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
          onSkipPrevious: onSkipPrevious,
          onVoteSkip: rs.isHost ? null : rs.voteSkip,
          skipVoteCount: (rs.skipVote['count'] as int?) ?? 0,
          skipVoteRequired: (rs.skipVote['required'] as int?) ?? 1,
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
        onSkipPrevious: onSkipPrevious,
        onVoteSkip: rs.isHost ? null : rs.voteSkip,
        skipVoteCount: (rs.skipVote['count'] as int?) ?? 0,
        skipVoteRequired: (rs.skipVote['required'] as int?) ?? 1,
        liked: liked,
        onToggleLike: () => _toggleLike(currentItem),
      );
    }

    // Auto-PIP only while there's actually a watch-party video up — pressing
    // home from Home/Feed/chat/etc. shouldn't pop a PIP window with nothing
    // worth watching in it.
    _syncAutoPip(isWatch && currentItem != null);
    // Watch/Voice/Game all share Watch Party's Vola reskin now — same
    // background gradient, same text/accent colors — instead of Voice
    // having its own separate ClubRoomColors look. Only room types outside
    // these three (e.g. 'live') keep the app's normal claymorphism theme
    // via AppColors.
    final useVolaTheme = isWatch || isVoice || isGame;
    const roomBg = AppColors.bg;
    final roomBgGradient = useVolaTheme ? VolaPartyColors.bgGradient : null;
    final roomTextDim =
        useVolaTheme ? VolaPartyColors.textDim : AppColors.textDim;
    final roomPrimary =
        useVolaTheme ? VolaPartyColors.primary : AppColors.primary;
    final roomGold = useVolaTheme ? VolaPartyColors.gold : AppColors.gold;
    final roomText = useVolaTheme ? VolaPartyColors.text : AppColors.text;
    final myId = context.read<AuthProvider>().user?.id;
    final boostedUntilRaw = room['boostedUntil'] as String?;
    final isBoosted = boostedUntilRaw != null &&
        (DateTime.tryParse(boostedUntilRaw)?.isAfter(DateTime.now()) ?? false);
    final activeMics = (rs.call['activeMics'] as List? ?? []).cast<String>();
    final pendingRequests =
        (rs.call['pendingRequests'] as List? ?? []).cast<String>();
    final mutedMics = (rs.call['mutedMics'] as List? ?? []).cast<String>();
    final maxSlots = rs.call['maxSlots'] as int? ?? 8;
    final myMicForceMuted = myId != null && mutedMics.contains(myId);
    final myMicOn =
        myId != null && activeMics.contains(myId) && !myMicForceMuted;
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The host has muted you')));
      } else if (myMicOn) {
        rs.micOff();
      } else if (rs.isHost) {
        rs.micOn();
      } else if (myMicRequested) {
        rs.cancelMicRequest();
      } else if (rs.settings['micEnabled'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The host has disabled mics for now')));
      } else {
        rs.requestMic();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request sent to the host')));
      }
    }

    // Shared by the Watch collapsing header (see the NestedScrollView below)
    // and the plain unconditional spot every other room type still uses —
    // same widget either way, just two different places it can end up in
    // the tree, so this stays a single source of truth instead of two
    // copies drifting apart.
    Widget boostedBanner() => Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: roomGold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Featured',
                            style: TextStyle(
                                color: roomGold,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text('This watch party is featured',
                            style: TextStyle(color: roomTextDim, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: roomTextDim),
                ],
              ),
            ),
          ),
        );

    Widget pollBanner() => Builder(builder: (context) {
          final isNextTrackVote = rs.poll['isNextTrackVote'] == true;
          if (isNextTrackVote && !_nextTrackVoteShown) {
            _nextTrackVoteShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              showPollBottomSheet(context,
                  poll: rs.poll,
                  myUserId: myId ?? '',
                  isHost: rs.isHost,
                  roster: rs.roster,
                  onVote: rs.votePoll,
                  onReset: rs.resetPoll);
            });
          } else if (!isNextTrackVote) {
            _nextTrackVoteShown = false;
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: GestureDetector(
              onTap: () => showPollBottomSheet(context,
                  poll: rs.poll,
                  myUserId: myId ?? '',
                  isHost: rs.isHost,
                  roster: rs.roster,
                  onVote: rs.votePoll,
                  onReset: rs.resetPoll),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: roomPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: roomPrimary.withValues(alpha: 0.3))),
                child: Row(
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('Poll Active',
                        style: TextStyle(
                            color: roomPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          );
        });

    // A new video started (queue advanced, host switched source, a fresh
    // room load) — snap the collapsing header back open instead of leaving
    // it wherever the viewer had scrolled to for the previous video.
    if (isWatch && playerVideoUrl != _lastSeenPlayerVideoUrl) {
      _lastSeenPlayerVideoUrl = playerVideoUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollWatchHeaderToTop();
      });
    }

    return ValueListenableBuilder<bool>(
      valueListenable: PipService.isInPip,
      builder: (context, inPip, _) {
        if (inPip && isWatch) {
          // The real Android PIP window is tiny — no room for the app bar,
          // chat, or controls, just the video itself.
          return Scaffold(
            backgroundColor: Colors.black,
            body: player(
                mediaMode: _viewModeOverride ??
                    (currentItem?['mediaMode'] as String? ?? 'video')),
          );
        }
        // _chatFocused alone isn't enough — dismissing the keyboard via
        // Android's swipe-down gesture (or the back button, on some
        // versions) hides the IME without actually clearing the TextField's
        // FocusNode.hasFocus, so _chatFocused can stay stuck true with no
        // keyboard on screen, leaving the AppBar/icons hidden with nothing
        // to show for it. viewInsets.bottom is the OS's own ground truth
        // for whether the keyboard is actually visible right now — combine
        // both so the chrome reliably comes back the instant the keyboard
        // does, regardless of what focus state Flutter thinks it's in.
        final hideChromeForChat =
            _chatFocused && MediaQuery.of(context).viewInsets.bottom > 0;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: useVolaTheme ? Colors.transparent : roomBg,
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
          // Hidden while composing a chat message — see hideChromeForChat —
          // so chat gets the full screen instead of sharing it with chrome
          // nobody's looking at mid-type.
          appBar: hideChromeForChat
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: const GlassAppBarBackground(),
                  foregroundColor: useVolaTheme ? VolaPartyColors.text : null,
                  // Leave, not back — a plain pop/minimize still works via the
                  // system back gesture (ActiveRoomHolder keeps the room running
                  // either way), but this top-left slot is now the explicit,
                  // always-visible way to actually leave.
                  leading: IconButton(
                    tooltip: 'Leave room',
                    onPressed: _leaveRoom,
                    icon: Icon(Icons.logout_rounded, color: roomTextDim),
                  ),
                  // Room title/"Hosted by" removed — the boost action lives here
                  // instead now. _hostKey stays attached (moved from the old
                  // title Column) since showGiftBottomSheet's targetKey still
                  // needs some real widget in the AppBar to fly gift animations
                  // toward.
                  title: rs.isHost
                      ? GestureDetector(
                          key: _hostKey,
                          onTap: _boost,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rocket_launch_rounded,
                                  color: roomGold, size: 18),
                              const SizedBox(width: 6),
                              Text('Boost',
                                  style: TextStyle(
                                      color: roomGold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )
                      : SizedBox(key: _hostKey),
                  actions: [
                    if (isWatch)
                      IconButton(
                        tooltip: _viewModeOverride == 'audio'
                            ? 'Switch to video (just for you)'
                            : 'Switch to audio-only (just for you)',
                        onPressed: () => setState(() {
                          final effective = _viewModeOverride ??
                              (currentItem?['mediaMode'] as String? ?? 'video');
                          _viewModeOverride =
                              effective == 'audio' ? 'video' : 'audio';
                        }),
                        icon: Icon(
                          (_viewModeOverride ??
                                      (currentItem?['mediaMode'] as String? ??
                                          'video')) ==
                                  'audio'
                              ? Icons.movie_outlined
                              : Icons.headphones,
                          color: roomTextDim,
                        ),
                      ),
                    // The single search+queue entry point for every room type —
                    // used to be a separate search icon here plus its own queue
                    // icon in each room type's floating rail; merged into just
                    // this one (search icon, still opens the same _openQueue
                    // screen) so there's one obvious place to add a song and see
                    // what's queued, not two icons doing overlapping things.
                    if (isWatch || isGame || isVoice)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: GestureDetector(
                          onTap: _openQueue,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                tooltip: 'Search & queue',
                                onPressed: _openQueue,
                                icon: Icon(Icons.search, color: roomTextDim),
                              ),
                              if (items.isNotEmpty)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                        color: roomPrimary,
                                        shape: BoxShape.circle),
                                    constraints: const BoxConstraints(
                                        minWidth: 16, minHeight: 16),
                                    child: Text('${items.length}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    // Settings 2nd from right, participants at the very top
                    // right — the control-bar share icon below (_shareRoom) now
                    // covers sharing, so there's no separate share action up here
                    // anymore.
                    if (rs.isHost && room['roomType'] != 'live')
                      IconButton(
                        tooltip: 'Room settings',
                        onPressed: () => showRoomSettingsSheet(context,
                            room: room, onChanged: _loadRoom),
                        icon: Icon(Icons.settings_outlined, color: roomTextDim),
                      ),
                    // Pill-styled participant count, matching the redesign's .pill
                    // component (WatchPartyDark.dc.html) instead of a plain TextButton.
                    GestureDetector(
                      onTap: _openRoster,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: GlassPanel(
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('${rs.roster.length}',
                                  style: TextStyle(
                                      color: roomTextDim,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          // Normally the AppBar itself accounts for the status bar/notch —
          // once it's hidden (see hideChromeForChat above), the video would
          // otherwise render right up under it, so this picks up that inset
          // only while typing, letting the video slide up into the AppBar's
          // old spot instead of leaving a dead gap.
          body: SafeArea(
            top: hideChromeForChat,
            bottom: false,
            child: GestureDetector(
              // Swipe right-to-left opens the Queue — same destination as tapping
              // the queue icon, just a gesture shortcut. QueueSheetScreen's own
              // swipe (left-to-right) mirrors this to close back to the room.
              // The SAME gesture, started ON the player itself, instead
              // shrinks it into a corner + shows suggestions (see
              // _suggestionsMode) — the drag's start position (captured on
              // Start, checked on End) decides which one a given swipe
              // means, since both live on this one outer detector.
              onHorizontalDragStart: (details) =>
                  _dragStartGlobal = details.globalPosition,
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) >= -250) return;
                if (isWatch && !_suggestionsMode && _dragStartedOnPlayer()) {
                  setState(() => _suggestionsMode = true);
                } else {
                  _openQueue();
                }
              },
              child: Container(
                decoration: roomBgGradient != null
                    ? BoxDecoration(gradient: roomBgGradient)
                    : null,
                child: Column(
                  children: [
                    // Room-type-specific content — free to change shape however it
                    // needs to, since none of it holds long-lived playback state.
                    // Wrapped in Expanded+scroll (not just Padding) now that chat no
                    // longer eats the remaining space below for these types — same
                    // exact position in the Column either way, so this doesn't touch
                    // the player-identity invariant described below.
                    if (!isWatch)
                      // Chat now gets its own dedicated, un-obscured space
                      // below the stage — same "chat owns the rest of the
                      // screen" treatment Watch Party's ChatOverlay already
                      // gets — instead of floating on top of (and covering
                      // part of) the game board/voice stage in a Stack.
                      Expanded(
                        child: Column(
                          children: [
                            Flexible(
                              flex: 4,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                  // Voice's speaker/listener grid fills the width like the
                                  // mockup — only the square/aspect-locked content (game board,
                                  // live video, fallback icon) gets centered.
                                  child: room['roomType'] == 'live' &&
                                          _live != null
                                      ? Center(
                                          child: LiveVideoView(
                                              controller: _live!,
                                              isHost: rs.isHost))
                                      : isGame
                                          ? Center(
                                              child: GameBoardView(
                                                gameType:
                                                    room['gameType'] as String?,
                                                game: rs.game,
                                                myUserId: myId,
                                                isHost: rs.isHost,
                                                onJoin: rs.gameJoin,
                                                onMove: rs.gameMove,
                                                onReset: rs.gameReset,
                                              ),
                                            )
                                          : isVoice
                                              ? VoiceStageView(
                                                  roster: rs.roster,
                                                  activeMics: activeMics,
                                                  pendingRequests:
                                                      pendingRequests,
                                                  maxSlots: maxSlots,
                                                  hostId: rs.hostId,
                                                  myUserId: myId,
                                                  isHost: rs.isHost,
                                                  onApprove: rs.approveMic,
                                                  onDeny: rs.denyMic,
                                                  onRemove: rs.removeMic,
                                                )
                                              : Center(
                                                  child: AspectRatio(
                                                    aspectRatio: 16 / 9,
                                                    child: GlassPanel(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      child: const Center(
                                                        child: Text('🎙️',
                                                            style: TextStyle(
                                                                fontSize: 48)),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: ChatOverlay(
                                  messages: rs.messages,
                                  onSend: (text, mentionedUserIds) =>
                                      rs.sendMessage(text,
                                          mentionedUserIds: mentionedUserIds),
                                  myUserId: myId,
                                  primaryColor: roomPrimary,
                                  textColor: roomText,
                                  roster: rs.roster,
                                  myMicOn: myMicOn,
                                  myMicRequested: myMicRequested,
                                  onMicTap: handleMicTap,
                                  onPoll: () {
                                    if (rs.isHost) {
                                      showPollCreatorBottomSheet(context,
                                          onCreate: rs.createPoll);
                                    } else if (rs.poll['active'] == true) {
                                      showPollBottomSheet(context,
                                          poll: rs.poll,
                                          myUserId: myId ?? '',
                                          isHost: rs.isHost,
                                          roster: rs.roster,
                                          onVote: rs.votePoll,
                                          onReset: rs.resetPoll);
                                    }
                                  },
                                  onGift: () => showGiftBottomSheet(context,
                                      toUserId: room['hostId'] as String? ?? '',
                                      roomId: widget.roomId,
                                      targetKey: _hostKey),
                                  onShare: _shareRoom,
                                  onInvite: _openInvite,
                                  onFocusChanged: _setChatFocused,
                                ),
                              ),
                            ),
                          ],
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
                    if (isWatch && _suggestionsMode)
                      // Swiped the player left — it shrinks into a "now
                      // playing" box instead of pausing/disappearing, and
                      // the rest of this space becomes a suggestion grid to
                      // pin from. mediaMode/compact mirror what the normal
                      // branch below would have used, just rendered small.
                      Expanded(
                        child: VideoSuggestionsPanel(
                          sourceType: playerSourceType,
                          videoUrl: playerVideoUrl,
                          nowPlayingTitle: currentItem?['title'] as String? ??
                              room['title'] as String?,
                          miniPlayer: player(
                            mediaMode: _viewModeOverride ??
                                (currentItem?['mediaMode'] as String? ??
                                    'video'),
                            compact: true,
                          ),
                          onPin: (
                                  {required videoUrl,
                                  required title,
                                  thumbnail,
                                  required sourceType}) =>
                              rs.queueAdd({
                            'videoUrl': videoUrl,
                            'title': title,
                            'thumbnail': thumbnail,
                            'sourceType': sourceType,
                            'mediaMode': 'video',
                          }, position: 'top'),
                          isHost: rs.isHost,
                          onVoteAdd: (
                                  {required videoUrl,
                                  required title,
                                  thumbnail,
                                  required sourceType}) =>
                              rs.voteAdd({
                            'videoUrl': videoUrl,
                            'title': title,
                            'thumbnail': thumbnail,
                            'sourceType': sourceType,
                            'mediaMode': 'video',
                          }),
                          onUnvoteAdd: rs.unvoteAdd,
                          myUserId: myId,
                          addVotes: rs.addVotes,
                          onRestore: () =>
                              setState(() => _suggestionsMode = false),
                        ),
                      )
                    else if (isWatch && ottImmersive)
                      // Video stays a normal 16:9 box pinned to the top of
                      // this Expanded slot (not full-bleed — see the
                      // player() closure above) instead of stretching down
                      // the whole screen. Chat still moves from "always
                      // visible below" to an on-demand slide-up panel so it
                      // doesn't eat into that space, toggled by the
                      // floating button here.
                      Expanded(
                        key: _playerAreaKey,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: player(
                                mediaMode: _viewModeOverride ??
                                    (currentItem?['mediaMode'] as String? ??
                                        'video'),
                                compact: false,
                              ),
                            ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: GlassCircleButton(
                                onTap: () => setState(
                                    () => _ottChatOpen = !_ottChatOpen),
                                child: Icon(
                                  _ottChatOpen
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            if (_ottChatOpen)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: FractionallySizedBox(
                                  heightFactor: 0.55,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                    child: ColoredBox(
                                      color:
                                          AppColors.bg.withValues(alpha: 0.92),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 12, 12, 12),
                                        child: ChatOverlay(
                                          messages: rs.messages,
                                          onSend: (text, mentionedUserIds) =>
                                              rs.sendMessage(text,
                                                  mentionedUserIds:
                                                      mentionedUserIds),
                                          myUserId: myId,
                                          primaryColor: roomPrimary,
                                          textColor: roomText,
                                          roster: rs.roster,
                                          myMicOn: myMicOn,
                                          myMicRequested: myMicRequested,
                                          onMicTap: handleMicTap,
                                          onPoll: () {
                                            if (rs.isHost) {
                                              showPollCreatorBottomSheet(
                                                  context,
                                                  onCreate: rs.createPoll);
                                            } else if (rs.poll['active'] ==
                                                true) {
                                              showPollBottomSheet(context,
                                                  poll: rs.poll,
                                                  myUserId: myId ?? '',
                                                  isHost: rs.isHost,
                                                  roster: rs.roster,
                                                  onVote: rs.votePoll,
                                                  onReset: rs.resetPoll);
                                            }
                                          },
                                          onGift: () => showGiftBottomSheet(
                                              context,
                                              toUserId:
                                                  room['hostId'] as String? ??
                                                      '',
                                              roomId: widget.roomId,
                                              targetKey: _hostKey),
                                          onShare: _shareRoom,
                                          onInvite: _openInvite,
                                          onFocusChanged: _setChatFocused,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (isWatch)
                      // Video sits right under the app bar; scrolling the
                      // chat below it up scrolls this whole header
                      // (player + boosted banner + participants + poll)
                      // away too — NestedScrollView links the two
                      // scrollables so the header only moves once chat's
                      // own message list is already at its own top/bottom
                      // edge, instead of fighting it for the drag. The
                      // down-arrow (see _playerCollapsed) and a fresh video
                      // starting (see _lastSeenPlayerVideoUrl above) both
                      // snap it back open.
                      Expanded(
                        child: Stack(
                          children: [
                            NestedScrollView(
                              controller: _watchScrollController,
                              headerSliverBuilder: (context, _) => [
                                SliverToBoxAdapter(
                                  child: Column(
                                    children: [
                                      Padding(
                                        key: _playerAreaKey,
                                        padding: EdgeInsets.zero,
                                        child: player(
                                          mediaMode: _viewModeOverride ??
                                              (currentItem?['mediaMode']
                                                      as String? ??
                                                  'video'),
                                          compact: false,
                                        ),
                                      ),
                                      if (isBoosted) boostedBanner(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 12, 12, 8),
                                        child: ParticipantAvatarRow(
                                            roster: rs.roster,
                                            onOpenRoster: _openRoster),
                                      ),
                                      if (rs.poll['active'] == true)
                                        pollBanner(),
                                    ],
                                  ),
                                ),
                              ],
                              body: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 4, 12, 12),
                                child: ChatOverlay(
                                  messages: rs.messages,
                                  onSend: (text, mentionedUserIds) =>
                                      rs.sendMessage(text,
                                          mentionedUserIds: mentionedUserIds),
                                  myUserId: myId,
                                  primaryColor: roomPrimary,
                                  textColor: roomText,
                                  roster: rs.roster,
                                  myMicOn: myMicOn,
                                  myMicRequested: myMicRequested,
                                  onMicTap: handleMicTap,
                                  onPoll: () {
                                    if (rs.isHost) {
                                      showPollCreatorBottomSheet(context,
                                          onCreate: rs.createPoll);
                                    } else if (rs.poll['active'] == true) {
                                      showPollBottomSheet(context,
                                          poll: rs.poll,
                                          myUserId: myId ?? '',
                                          isHost: rs.isHost,
                                          roster: rs.roster,
                                          onVote: rs.votePoll,
                                          onReset: rs.resetPoll);
                                    }
                                  },
                                  onGift: () => showGiftBottomSheet(context,
                                      toUserId: room['hostId'] as String? ?? '',
                                      roomId: widget.roomId,
                                      targetKey: _hostKey),
                                  onShare: _shareRoom,
                                  onInvite: _openInvite,
                                  onFocusChanged: _setChatFocused,
                                ),
                              ),
                            ),
                            if (_playerCollapsed)
                              Positioned(
                                top: 8,
                                right: 12,
                                child: GlassCircleButton(
                                  onTap: _scrollWatchHeaderToTop,
                                  child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 20),
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (currentItem != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        // Compact bar for every non-watch type (voice, game, live) —
                        // this used to only check isVoice, so a game room with a
                        // queued track rendered the full-size player stacked below
                        // the GameBoardView instead of a small audio bar.
                        child: player(mediaMode: 'audio', compact: true),
                      ),
                    // Skipped for isWatch — that case already renders these
                    // same widgets (via the shared boostedBanner/pollBanner
                    // closures above) inside the collapsing header instead.
                    if (isBoosted && !isWatch) boostedBanner(),
                    if (!isWatch)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: ParticipantAvatarRow(
                            roster: rs.roster, onOpenRoster: _openRoster),
                      ),
                    if (rs.poll['active'] == true && !isWatch) pollBanner(),
                    // Everything below this point renders strictly AFTER the player in
                    // the tree — restructuring it can't affect the player's identity
                    // across a room-type switch, since that's governed by what
                    // precedes it (see the big comment above the player block), which
                    // is untouched here.
                    // Only the suggestions-grid case still needs this —
                    // plain isWatch now has chat built into the collapsing
                    // header above instead (see the NestedScrollView), and
                    // ottImmersive keeps its own slide-up chat.
                    if (isWatch && !ottImmersive && _suggestionsMode)
                      // Chat floats over an open "stage" instead of living in
                      // its own boxed panel — matches WatchPartyDark.dc.html.
                      // No more floating icon rail alongside it (mic/boost/
                      // gift/poll/share/invite all now live inside the chat
                      // bar itself — see ChatOverlay). ottImmersive rooms get
                      // their own slide-up ChatOverlay instead (see the
                      // player block above) instead of this always-visible one.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: ChatOverlay(
                            messages: rs.messages,
                            onSend: (text, mentionedUserIds) => rs.sendMessage(
                                text,
                                mentionedUserIds: mentionedUserIds),
                            myUserId: myId,
                            primaryColor: roomPrimary,
                            textColor: roomText,
                            roster: rs.roster,
                            myMicOn: myMicOn,
                            myMicRequested: myMicRequested,
                            onMicTap: handleMicTap,
                            onPoll: () {
                              if (rs.isHost) {
                                showPollCreatorBottomSheet(context,
                                    onCreate: rs.createPoll);
                              } else if (rs.poll['active'] == true) {
                                showPollBottomSheet(context,
                                    poll: rs.poll,
                                    myUserId: myId ?? '',
                                    isHost: rs.isHost,
                                    roster: rs.roster,
                                    onVote: rs.votePoll,
                                    onReset: rs.resetPoll);
                              }
                            },
                            onGift: () => showGiftBottomSheet(context,
                                toUserId: room['hostId'] as String? ?? '',
                                roomId: widget.roomId,
                                targetKey: _hostKey),
                            onShare: _shareRoom,
                            onInvite: _openInvite,
                            onFocusChanged: _setChatFocused,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchScrollController.dispose();
    _rs?.removeListener(_onRoomStateChanged);
    // Leaving this screen either way (minimize or real leave) — clear this
    // before ActiveRoomHolder.leave() below so persistent_room_audio.dart's
    // "should I take over" check never briefly reads stale-true state.
    ActiveRoomHolder.isRoomScreenVisible.value = false;
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
        content: const Text(
            "You'll stop being part of the room — anyone else stays. Just switching screens or apps doesn't need this; the room keeps going in the background until you come back."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _didLeaveRoom = true;
    Navigator.of(context).pop();
  }
}
