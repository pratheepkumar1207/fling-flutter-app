import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/active_room_holder.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/pip_service.dart';
import '../../core/room_source_types.dart';
import '../../core/socket_service.dart';
import '../../models/room_models.dart';
import '../../theme/insync_icons.dart';
import '../../widgets/in_icon_button.dart';
import '../../theme/app_colors.dart';
import '../../theme/vola_party_colors.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/game_board_view.dart';
import '../../widgets/game_seat.dart';
import '../../widgets/avatar.dart';
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
import '../../features/party/data/party_engine_impl.dart';
import 'chat_overlay.dart';
import 'drive_video_player.dart';
import 'game_room_body.dart';
import 'game_seat_prompts.dart';
import 'live_broadcast_controller.dart';
import 'queue_sheet.dart';
import 'roster_sheet.dart';
import 'room_socket_controller.dart';
import 'sync_video_player.dart';
import 'video_suggestions_panel.dart';
import 'voice_chat_controller.dart';
import 'webview_room_player.dart';
import '../../theme/room_themes.dart';

class PartyScreen extends StatefulWidget {
  final String roomId;
  const PartyScreen({super.key, required this.roomId});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> with WidgetsBindingObserver {
  final _hostKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // The player widget (WebviewRoomPlayer/DriveVideoPlayer/SyncVideoPlayer)
  // gets built from three structurally different spots in _buildRoom's
  // tree depending on PiP/landscape/normal state — see player() below.
  // A GlobalKey is what actually lets Flutter carry the same Element (and
  // therefore the same live WebView/native player, mid-playback) across
  // that move instead of tearing it down and building a fresh one each
  // time; a ValueKey only matches siblings within the same parent, which
  // these three spots never are. Confirmed live: without this, every
  // rotation and every PIP transition reloaded the player from scratch —
  // a real ~2s stall each time (YouTube embed reload, IFrame API
  // handshake, reseek), not a fleeting resize hiccup. Cached per video
  // identity (not created fresh every build, which would defeat the
  // point — a new GlobalKey() object matches nothing from the last frame)
  // and left to grow for this screen's lifetime; a single room session
  // realistically plays too few distinct videos for that to matter, and
  // the whole map goes away when this State does.
  final Map<String, GlobalKey> _playerKeys = {};
  GlobalKey _playerKeyFor(String identity) =>
      _playerKeys.putIfAbsent(identity, () => GlobalKey());
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
  // See the auto-return check next to promptPin in build().
  bool _wasNothingPlaying = false;
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
  late final PartyEngineImpl _partyEngine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchScrollController.addListener(_onWatchScroll);
    _partyEngine = PartyEngineImpl(
      socketService: context.read<SocketService>(),
      currentUserId: () => context.read<AuthProvider>().user?.id,
    );
    // Tells persistent_room_audio.dart's hidden player it can stand down —
    // this screen's own (visible, full-UI) player is about to be the one
    // actually producing audio. Cleared in dispose().
    ActiveRoomHolder.isRoomScreenVisible.value = true;
    // Reattaching to a room already kept alive by ActiveRoomHolder (the
    // user minimized it earlier, not left it) — reuse everything instead
    // of rejoining from scratch, which would otherwise show a blank
    // "joining…" state and briefly desync from whatever's already playing.
    final activeSession = ActiveRoomHolder.session;
    if (activeSession?.roomId == widget.roomId &&
        activeSession?.roomController != null) {
      _room = activeSession!.room;
      _rs = activeSession.roomController;
      _voice = activeSession.voice;
      _live = activeSession.live;
      _loading = false;
      _rs!.addListener(_onRoomStateChanged);
      _loadLiked();
      return;
    }
    _loadLiked();
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinParty());
  }

  Future<void> _joinParty() async {
    try {
      await _partyEngine.join(widget.roomId);
      if (!mounted) return;
      setState(() {
        final runtime = ActiveRoomHolder.session;
        _room = runtime?.room;
        _rs = runtime?.roomController;
        _voice = runtime?.voice;
        _live = runtime?.live;
        _loading = false;
      });
      _rs?.addListener(_onRoomStateChanged);
      _maybeInitLive();
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

  void _maybeInitLive() {
    final runtime = ActiveRoomHolder.session;
    if (runtime == null) return;
    runtime.ensureLive();
    ActiveRoomHolder.refreshSessionReferences();
    if (_live != runtime.live && mounted) {
      setState(() => _live = runtime.live);
    }
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
    if (rs.gameSeatDenied != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(rs.gameSeatDenied!)));
      rs.clearGameSeatDenied();
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

  Future<void> _shareRoom() async {
    // The room's own control-bar share action — was a plain clipboard copy,
    // now opens the same "Share to" bottom sheet (apps + Copy Link) the
    // AppBar's share icon used to, since that one's been removed in favor
    // of this being the room's single share entry point.
    final room = _room;
    await showShareBottomSheet(
      context,
      text: 'Join "${room?['title'] ?? 'my room'}" on Insync',
      url: '${ApiClient.baseUrl}/r/${widget.roomId}',
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
    await _refreshRoom();
  }

  Future<void> _refreshRoom() async {
    final runtime = ActiveRoomHolder.session;
    if (runtime == null) return;
    try {
      await runtime.refreshRoom();
      ActiveRoomHolder.refreshSessionReferences();
      if (!mounted) return;
      setState(() {
        _room = runtime.room;
        _rs = runtime.roomController;
        _voice = runtime.voice;
        _live = runtime.live;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not refresh room: $e')));
      }
    }
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
          onAddMany: (items) => rs.queueAddMany(items),
        ),
      ),
    ));
  }

  // Watch/voice/game rooms get the theme's backdrop; other room types keep
  // the app's plain background.
  Widget _maybeBackdrop(RoomTheme? theme, String? imageUrl, Widget child) =>
      theme == null
          ? child
          : RoomBackdrop(theme: theme, imageUrl: imageUrl, child: child);

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
    // ...and once the room's pick starts playing (playback goes from
    // nothing to something), go back to the full-size player.
    final nothingPlaying = rs.playback == null;
    if (_suggestionsMode && _wasNothingPlaying && !nothingPlaying) {
      _suggestionsMode = false;
    }
    _wasNothingPlaying = nothingPlaying;
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
      // element, mount a new one". A GlobalKey (see _playerKeyFor's own
      // comment above) — not a ValueKey — is what actually makes that
      // hold true across PiP/rotation, since those move the player to a
      // genuinely different parent, not just different props at the same
      // spot.
      final playerKey =
          _playerKeyFor('player-$playerSourceType-$playerVideoUrl');
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
          ottStatuses: rs.ottStatuses,
          onOttStatus: rs.sendOttStatus,
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
    // The host's lobby theme (Room settings -> Theme); Midnight by default.
    final roomTheme =
        RoomTheme.byId((rs.settings['theme'] ?? room['theme']) as String?);
    final roomTextDim = useVolaTheme ? roomTheme.textDim : AppColors.textDim;
    final roomPrimary = useVolaTheme ? roomTheme.primary : AppColors.primary;
    final roomGold = useVolaTheme ? VolaPartyColors.gold : AppColors.gold;
    final roomText = useVolaTheme ? roomTheme.text : AppColors.text;
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
    _voice?.onLocalSpeakingChanged = rs.setSpeaking;
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
                  InIcon(InIcons.star, size: 20, color: roomGold, filled: true),
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
                  InIcon(InIcons.chev, size: 18, color: roomTextDim),
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

    final rosterById = {for (final r in rs.roster) r.userId: r};

    // App bar centre: who's on mic, each lit with a green ring while their
    // voice is actually coming through.
    Widget micSpeakers() {
      final onMic = [
        for (final id in activeMics)
          if (rosterById[id] != null) rosterById[id]!
      ];
      if (onMic.isEmpty) return const SizedBox.shrink();
      const maxShown = 4;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in onMic.take(maxShown))
            Builder(builder: (context) {
              final talking = rs.speaking.contains(r.userId) &&
                  !mutedMics.contains(r.userId);
              return Semantics(
                label: '${r.name}${talking ? ' speaking' : ' on mic'}',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: talking ? AppColors.success : Colors.transparent,
                        width: 2),
                  ),
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: FittedBox(
                        child: Avatar(src: r.avatarUrl, name: r.name)),
                  ),
                ),
              );
            }),
          if (onMic.length > maxShown)
            Text(' +${onMic.length - maxShown}',
                style: TextStyle(color: roomTextDim, fontSize: 11.5)),
        ],
      );
    }

    // Game rooms — who's seated, and the request/invite prompts above
    // the board.
    final gamePlayers = ((rs.game?['players'] as List?) ?? []).cast<Map>();
    final gamePlayerIds = {
      for (final p in gamePlayers)
        if (p['userId'] is String) p['userId'] as String
    };
    void openGameInvite() => showGameInvitePicker(
          context,
          roster: rs.roster,
          playerIds: gamePlayerIds,
          invitedIds: rs.gameInvites.toSet(),
          myUserId: myId,
          onInvite: rs.gameInvite,
        );
    List<Widget> gameBanners() {
      if (rs.isHost) {
        final waiting = [
          for (final id in rs.gameRequests)
            if (!gamePlayerIds.contains(id)) id
        ];
        if (waiting.isEmpty) return const [];
        final person = rosterById[waiting.first];
        return [
          GameSeatBanner(
            person: person,
            text: '${person?.name ?? 'Someone'} wants to play',
            acceptLabel: 'Let in',
            onAccept: () => rs.gameApprove(waiting.first),
            onDecline: () => rs.gameDeny(waiting.first),
            more: waiting.length - 1,
          ),
        ];
      }
      if (myId != null &&
          rs.gameInvites.contains(myId) &&
          !gamePlayerIds.contains(myId)) {
        final host = rs.hostId == null ? null : rosterById[rs.hostId];
        return [
          GameSeatBanner(
            person: host,
            text: '${host?.name ?? 'The host'} invited you to play',
            acceptLabel: 'Join game',
            onAccept: rs.gameJoin,
            onDecline: rs.gameDeclineInvite,
          ),
        ];
      }
      return const [];
    }

    Widget gameBoard() => GameSeatScope(
          isHost: rs.isHost,
          requested: myId != null && rs.gameRequests.contains(myId),
          invited: myId != null && rs.gameInvites.contains(myId),
          onSit: rs.gameJoin,
          onRequest: () {
            rs.gameRequest();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Asked the host to let you play')));
          },
          onCancelRequest: rs.gameCancelRequest,
          onInvite: rs.isHost ? openGameInvite : null,
          avatarFor: (id) => id == null ? null : rosterById[id]?.avatarUrl,
          child: GameBoardView(
            gameType: room['gameType'] as String?,
            game: rs.game,
            myUserId: myId,
            isHost: rs.isHost,
            onJoin: rs.gameJoin,
            onMove: rs.gameMove,
            onReset: rs.gameReset,
          ),
        );

    return RoomThemeScope(
        theme: roomTheme,
        child: ValueListenableBuilder<bool>(
          valueListenable: PipService.isInPip,
          builder: (context, inPip, _) {
            if (inPip && isWatch) {
              // The real Android PIP window is tiny — no room for the app bar,
              // chat, or controls, just the video itself.
              return Scaffold(
                backgroundColor: Colors.black,
                body: player(
                    mediaMode: currentItem?['mediaMode'] as String? ?? 'video'),
              );
            }
            // Landscape (device rotated, or the player's own fullscreen button
            // for platforms that trigger it — see _requestFullscreen in each
            // player) drops the app bar/chat/queue/collapsing-header entirely
            // for just the video, full-bleed, no scrolling. Reverts the moment
            // the phone goes back to portrait.
            if (isWatch &&
                !inPip &&
                MediaQuery.orientationOf(context) == Orientation.landscape) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: player(
                      mediaMode:
                          currentItem?['mediaMode'] as String? ?? 'video'),
                ),
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
                onInvite: _openInvite,
                onInviteGame: isGame && rs.isHost ? rs.gameInvite : null,
                gamePlayerIds: gamePlayerIds,
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
                      foregroundColor:
                          useVolaTheme ? VolaPartyColors.text : null,
                      // Leave, not back — a plain pop/minimize still works via the
                      // system back gesture (ActiveRoomHolder keeps the room running
                      // either way), but this top-left slot is now the explicit,
                      // always-visible way to actually leave.
                      // Leave first, settings (host) right beside it — the
                      // two "room" controls together on the left.
                      leadingWidth:
                          rs.isHost && room['roomType'] != 'live' ? 96 : 56,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InIconButton(InIcons.logout,
                              tooltip: 'Leave room',
                              color: const Color(0xFFFF8AA0),
                              onPressed: _leaveRoom),
                          if (rs.isHost && room['roomType'] != 'live')
                            InIconButton(InIcons.gear,
                                tooltip: 'Room settings',
                                color: roomTextDim,
                                onPressed: () => showRoomSettingsSheet(context,
                                    room: room, onChanged: _refreshRoom)),
                        ],
                      ),
                      // Who's on mic, lit while talking. _hostKey stays on this
                      // slot — showGiftBottomSheet flies gift animations toward
                      // it, so it needs a real widget in the AppBar.
                      centerTitle: true,
                      title: KeyedSubtree(key: _hostKey, child: micSpeakers()),
                      actions: [
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
                                  InIconButton(InIcons.queue,
                                      tooltip: 'Search & queue',
                                      color: roomTextDim,
                                      onPressed: _openQueue),
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
                        // Pill-styled participant count, matching the redesign's .pill
                        // component (WatchPartyDark.dc.html) instead of a plain TextButton.
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InIconButton(InIcons.users,
                              tooltip: 'People in the room',
                              color: roomTextDim,
                              badge: rs.roster.length,
                              onPressed: _openRoster),
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
                    if (isWatch &&
                        !_suggestionsMode &&
                        _dragStartedOnPlayer()) {
                      setState(() => _suggestionsMode = true);
                    } else {
                      _openQueue();
                    }
                  },
                  child: _maybeBackdrop(
                    useVolaTheme ? roomTheme : null,
                    // Glass blurs what's playing, else the host's photo.
                    (currentItem?['thumbnail'] ?? room['videoThumbnail'])
                            as String? ??
                        rs.roster
                            .where((r) => r.userId == rs.hostId)
                            .map((r) => r.avatarUrl)
                            .firstOrNull,
                    Column(
                      children: [
                        // Room-type-specific content — free to change shape however it
                        // needs to, since none of it holds long-lived playback state.
                        // Wrapped in Expanded+scroll (not just Padding) now that chat no
                        // longer eats the remaining space below for these types — same
                        // exact position in the Column either way, so this doesn't touch
                        // the player-identity invariant described below.
                        if (isGame)
                          Expanded(
                            child: GameRoomBody(
                              songPlayer: currentItem != null
                                  ? player(mediaMode: 'audio', compact: true)
                                  : null,
                              onAddSong: _openQueue,
                              banners: gameBanners(),
                              board: gameBoard(),
                              messages: rs.messages,
                              chat: ChatOverlay(
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
                          )
                        else if (!isWatch)
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
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 12, 12, 12),
                                      // Voice's speaker/listener grid fills the width like the
                                      // mockup — only the square/aspect-locked content (game board,
                                      // live video, fallback icon) gets centered.
                                      child: room['roomType'] == 'live' &&
                                              _live != null
                                          ? Center(
                                              child: LiveVideoView(
                                                  controller: _live!,
                                                  isHost: rs.isHost))
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
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 12),
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
                                          toUserId:
                                              room['hostId'] as String? ?? '',
                                          roomId: widget.roomId,
                                          targetKey: _hostKey),
                                      onShare: _shareRoom,
                                      onInvite: _openInvite,
                                      onFocusChanged: _setChatFocused,
                                      likedUrls: _likedUrls,
                                      onToggleLike: _toggleLike,
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
                          // Swiped the player left (or the queue ran dry) — a
                          // two-row carousel of 16:9 tiles at its natural
                          // height, the live player as its first tile while
                          // something's playing; chat below takes the rest.
                          // mediaMode/compact mirror what the normal branch
                          // below would have used, just rendered small.
                          VideoSuggestionsPanel(
                            showNowPlaying: rs.playback != null,
                            roster: rs.roster,
                            sourceType: playerSourceType,
                            videoUrl: playerVideoUrl,
                            nowPlayingTitle: currentItem?['title'] as String? ??
                                room['title'] as String?,
                            miniPlayer: player(
                              mediaMode: currentItem?['mediaMode'] as String? ??
                                  'video',
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
                            child: LayoutBuilder(builder: (context, area) {
                              // An explicit height: a Positioned with only a
                              // bottom edge gives its child no height limit,
                              // which left a FractionallySizedBox panel at zero
                              // size (chat never appeared).
                              final panelHeight = area.maxHeight * 0.55;
                              return Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: player(
                                      mediaMode: currentItem?['mediaMode']
                                              as String? ??
                                          'video',
                                      compact: false,
                                    ),
                                  ),
                                  if (_ottChatOpen)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      height: panelHeight,
                                      child: SizedBox.expand(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(16)),
                                          child: ColoredBox(
                                            color: AppColors.bg
                                                .withValues(alpha: 0.92),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      12, 12, 12, 12),
                                              child: ChatOverlay(
                                                messages: rs.messages,
                                                onSend: (text,
                                                        mentionedUserIds) =>
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
                                                        onCreate:
                                                            rs.createPoll);
                                                  } else if (rs
                                                          .poll['active'] ==
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
                                                onGift: () =>
                                                    showGiftBottomSheet(context,
                                                        toUserId: room['hostId']
                                                                as String? ??
                                                            '',
                                                        roomId: widget.roomId,
                                                        targetKey: _hostKey),
                                                onShare: _shareRoom,
                                                onInvite: _openInvite,
                                                onFocusChanged: _setChatFocused,
                                                likedUrls: _likedUrls,
                                                onToggleLike: _toggleLike,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // After the panel, and lifted above it while
                                  // open, so it can always close the chat.
                                  Positioned(
                                    right: 12,
                                    bottom:
                                        _ottChatOpen ? panelHeight + 12 : 12,
                                    child: GlassCircleButton(
                                      onTap: () => setState(
                                          () => _ottChatOpen = !_ottChatOpen),
                                      child: InIcon(
                                        _ottChatOpen
                                            ? InIcons.down
                                            : InIcons.chat,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          )
                        else if (isWatch)
                          // Video is pinned right under the app bar; scrolling
                          // the chat below it up scrolls the header under it
                          // (boosted banner + participants + poll) away — NestedScrollView links the two
                          // scrollables so the header only moves once chat's
                          // own message list is already at its own top/bottom
                          // edge, instead of fighting it for the drag. The
                          // down-arrow (see _playerCollapsed) and a fresh video
                          // starting (see _lastSeenPlayerVideoUrl above) both
                          // snap it back open.
                          Expanded(
                            child: Column(
                              children: [
                                // Pinned above the scrolling area, NOT inside the
                                // collapsing header: opening the keyboard (or new
                                // messages arriving) scrolled the header to keep
                                // the chat field visible, which pushed the video
                                // up off-screen mid-chat. Only the banner,
                                // participants and poll below still collapse.
                                Padding(
                                  key: _playerAreaKey,
                                  padding: EdgeInsets.zero,
                                  child: player(
                                    mediaMode:
                                        currentItem?['mediaMode'] as String? ??
                                            'video',
                                    compact: false,
                                  ),
                                ),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      NestedScrollView(
                                        controller: _watchScrollController,
                                        headerSliverBuilder: (context, _) => [
                                          SliverToBoxAdapter(
                                            child: Column(
                                              children: [
                                                if (isBoosted) boostedBanner(),
                                                if (rs.poll['active'] == true)
                                                  pollBanner(),
                                              ],
                                            ),
                                          ),
                                        ],
                                        body: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 4, 12, 12),
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
                                            likedUrls: _likedUrls,
                                            onToggleLike: _toggleLike,
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
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color: Colors.white,
                                                size: 20),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (currentItem != null && !isGame)
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
                        if (isBoosted && !isWatch && !isGame) boostedBanner(),
                        // Not in voice rooms either: the voice stage already shows
                        // every speaker and its LISTENING section everyone else, so
                        // this strip just repeated the same faces under the chat.
                        if (!isWatch && !isVoice && !isGame)
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
                ),
              ),
            );
          },
        ));
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
    final rs = _rs;
    final others = rs == null || !rs.isHost
        ? const <RosterEntry>[]
        : rs.roster.where((r) => r.userId != rs.myUserId).toList();
    String? nextHost = others.isEmpty ? null : others.first.userId;
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => Dialog(
          backgroundColor: const Color(0xFF121019),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: AppColors.border)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    color: const Color(0xFF2A1018),
                    borderRadius: BorderRadius.circular(20)),
                child: const Center(
                    child: InIcon(InIcons.logout,
                        size: 28, color: Color(0xFFFF8AA0))),
              ),
              const SizedBox(height: 14),
              const Text('Leave this room?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  others.isEmpty
                      ? 'Everyone else stays. Just switching screens doesn’t need this — the room keeps going in the background.'
                      : 'You’re the host. Pick who takes over before you go.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textDim, fontSize: 14)),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in others.take(8))
                      ChoiceChip(
                        avatar: Avatar(
                            src: r.avatarUrl,
                            name: r.name,
                            size: AvatarSize.sm),
                        label: Text(r.name.split(' ').first),
                        selected: nextHost == r.userId,
                        showCheckmark: false,
                        labelStyle: Theme.of(dialog)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                                color: nextHost == r.userId
                                    ? Colors.white
                                    : AppColors.text),
                        onSelected: (_) => setDialog(() => nextHost = r.userId),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              if (others.isNotEmpty && nextHost != null)
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialog).pop('handover:$nextHost'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  child: Text(
                      'Make ${others.firstWhere((r) => r.userId == nextHost).name.split(' ').first} host and leave',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              if (others.isNotEmpty) const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(dialog).pop('leave'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor:
                        others.isEmpty ? AppColors.danger : AppColors.surface2,
                    foregroundColor: others.isEmpty
                        ? Colors.white
                        : const Color(0xFFFF8AA0)),
                child: const Text('Leave room'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(dialog).pop('stay'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Stay'),
              ),
            ]),
          ),
        ),
      ),
    );
    if (result == null || result == 'stay' || !mounted) return;
    if (result.startsWith('handover:')) {
      rs?.makeHost(result.substring('handover:'.length));
      // Give the server a moment to hand over before we disconnect.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
    }
    _didLeaveRoom = true;
    Navigator.of(context).pop();
  }
}
