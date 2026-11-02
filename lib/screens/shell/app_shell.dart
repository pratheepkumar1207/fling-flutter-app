import '../messages/message_thread_screen.dart';
import '../../core/app_messenger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/active_room_holder.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../calls/call_screen.dart';
import '../calls/incoming_call_view.dart';
import '../discover/discover_screen.dart';
import '../feed/feed_screen.dart';
import '../home/home_screen.dart';
import '../live/live_feed_screen.dart';
import '../party/mention_notifier.dart';
import '../party/party_screen.dart';
import '../party/persistent_room_audio.dart';
import '../../theme/insync_icons.dart';
import 'create_sheet.dart';
import 'liquid_glass_bottom_nav.dart';
import 'top_bar.dart';
import '../settings/account_removal_screen.dart';
import '../../core/push_notifications.dart';
import '../../core/call_ring.dart';
import '../../widgets/permission_primer.dart';

/// Bottom tabs Home, Feed, Live and Discover with the "+" Create sheet in
/// the middle; Messages lives in the top bar (see InsyncTopBar).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Set to a tab index (3 = Discover) from a pushed screen to switch the
  /// bottom tab once you're back on the shell.
  static final tabRequest = ValueNotifier<int?>(null);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    FeedScreen(),
    LiveFeedScreen(),
    DiscoverScreen(),
  ];

  static const _items = [
    NavItemData(InIcons.home, 'Home'),
    NavItemData(InIcons.feed, 'Feed'),
    NavItemData(InIcons.live, 'Live', tag: 'LIVE'),
    NavItemData(InIcons.flame, 'Discover'),
  ];

  void _onNavTap(int i) => setState(() => _index = i);

  bool _handlingIncomingCall = false;
  // Channel of the incoming-call dialog currently showing, if any — lets
  // _bindIncomingCalls tell whether a call:cancelled/call:ended event
  // matches the call the user is currently being asked about.
  String? _activeIncomingChannelName;

  void _onTabRequest() {
    final i = AppShell.tabRequest.value;
    if (i == null || !mounted) return;
    AppShell.tabRequest.value = null;
    setState(() => _index = i);
  }

  @override
  void dispose() {
    AppShell.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppShell.tabRequest.addListener(_onTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final socket = context.read<SocketService>();
      if (auth.token != null) socket.connect(auth.token!);
      _bindIncomingCalls(socket);
      _checkDeletionPending();
      CallRing.listen(_openPendingCall);
      _openPendingCall();
      // Tokens change, and calls to a closed app depend on this one.
      if (auth.user?.pushNotificationsEnabled != false) {
        requestPushPermissionAndRegister();
      }
      // Camera, mic, location and notifications in one go, first open only.
      ensureStartupPermissions(context,
          registerPush: auth.user?.pushNotificationsEnabled != false);
    });
  }

  // Global 1:1-call listener — bound once here (AppShell stays mounted
  // under whatever screen the user navigates to, since those are pushed on
  // top of it) so an incoming call rings no matter what the user is
  // currently looking at. See calls.js's direct-invite route.
  /// Logged back in during the 30 days: keep the account, or go on leaving.
  Future<void> _checkDeletionPending() async {
    final Map status;
    try {
      status = await ApiClient.get('/account/status') as Map;
    } catch (_) {
      return;
    }
    final on = DateTime.tryParse('${status['deleteScheduledAt']}');
    if (on == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final socket = context.read<SocketService>();
    final navigator = Navigator.of(context);
    final keep = await showDeletionPendingDialog(
        context, on, (status['daysLeft'] as num?)?.toInt() ?? 0);
    if (!keep) {
      await auth.clearSession();
      return;
    }
    await ApiClient.post('/account/restore');
    await auth.refreshUser();
    if (auth.token != null) socket.connect(auth.token!);
    // Everything that loaded behind the question was refused; start fresh.
    navigator
        .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
  }

  /// Opened from a ringing notification: the same screen as a live call.
  Future<void> _openPendingCall() async {
    final call = await CallRing.pendingCall();
    if (call == null || !mounted || _handlingIncomingCall) return;
    final sent = int.tryParse('${call['sentAt']}') ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - sent;
    if (age > _ringFor.inMilliseconds) {
      CallRing.callFinished();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('You missed a call from ${call['fromName'] ?? 'someone'}')));
      return;
    }
    if ((call['fromAvatarUrl'] as String?)?.isEmpty ?? false) {
      call['fromAvatarUrl'] = null;
    }
    _showIncomingCall(call);
  }

  static const _ringFor = Duration(seconds: 45);

  void _bindIncomingCalls(SocketService socketService) {
    socketService.socket?.on('call:incoming', (data) {
      if (!mounted || data is! Map || _handlingIncomingCall) return;
      _showIncomingCall(Map<String, dynamic>.from(data));
    });
    // Caller gave up (or the call otherwise ended) before this user acted
    // on the incoming-call dialog — dismiss it instead of leaving it up
    // for a call that no longer exists (see call_screen.dart's _hangUp).
    void dismissIfStale(dynamic data) {
      if (!mounted || data is! Map || !_handlingIncomingCall) return;
      if (data['channelName'] != _activeIncomingChannelName) return;
      // Distinct from the Decline button's `false` — this dialog is being
      // dismissed because the call is already gone, not because the user
      // chose to decline it, so no /calls/direct-decline should follow.
      Navigator.of(context, rootNavigator: true).pop(null);
    }

    socketService.socket?.on('call:cancelled', dismissIfStale);
    socketService.socket?.on('call:ended', dismissIfStale);
  }

  Future<void> _showIncomingCall(Map<String, dynamic> data) async {
    _handlingIncomingCall = true;
    _activeIncomingChannelName = data['channelName'] as String?;
    // showDialog defaults to useRootNavigator: true, so this shows above
    // whatever screen is currently pushed on top of AppShell, not just
    // AppShell's own body.
    CallRing.incoming();
    // Nobody rings for ever, including if the "cancelled" message was missed.
    final channel = _activeIncomingChannelName;
    final giveUp = Timer(_ringFor, () {
      if (mounted &&
          _handlingIncomingCall &&
          _activeIncomingChannelName == channel) {
        Navigator.of(context, rootNavigator: true).pop(null);
      }
    });
    final answer = await showIncomingCall(context,
        name: data['fromName'] as String? ?? 'Someone',
        avatarUrl: data['fromAvatarUrl'] as String?,
        video: data['mode'] == 'video');
    giveUp.cancel();
    CallRing.stop();
    // Answering stays over the lock screen until the call ends.
    if (answer != CallAnswer.accept) CallRing.callFinished();
    if (!mounted) return;
    final channelName = data['channelName'] as String;
    final fromId = data['fromUserId'] as String?;
    final fromName = data['fromName'] as String? ?? 'Someone';
    if (answer == CallAnswer.accept) {
      try {
        final response = await ApiClient.post('/calls/direct-accept',
            body: {'channelName': channelName}) as Map<String, dynamic>;
        if (mounted) {
          Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
            builder: (_) => CallScreen(
              channelName: channelName,
              token: response['token'] as String,
              uid: response['uid'] as int,
              video: data['mode'] == 'video',
              isCaller: false,
              peerId: data['fromUserId'] as String,
              peerName: data['fromName'] as String? ?? 'Someone',
              peerAvatarUrl: data['fromAvatarUrl'] as String?,
            ),
          ));
        }
      } catch (_) {
        // Couldn't connect — nothing more to do than let it drop.
      }
    } else if (answer != null) {
      ApiClient.post('/calls/direct-decline',
          body: {'channelName': channelName}).catchError((_) => null);
      if (answer == CallAnswer.message && fromId != null) {
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
            builder: (_) => MessageThreadScreen(
                userId: fromId,
                name: fromName,
                avatarUrl: data['fromAvatarUrl'] as String?)));
      } else if (answer == CallAnswer.remind && fromId != null) {
        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
            content: Text('We’ll remind you to call $fromName in 10 minutes')));
        Timer(const Duration(minutes: 10), () {
          if (!mounted) return;
          scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
            duration: const Duration(seconds: 12),
            content: Text('Call $fromName back?'),
            action: SnackBarAction(
              label: 'Open chat',
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                      builder: (_) => MessageThreadScreen(
                          userId: fromId,
                          name: fromName,
                          avatarUrl: data['fromAvatarUrl'] as String?))),
            ),
          ));
        });
      }
    }
    // answer == null: dialog was auto-dismissed by dismissIfStale above
    // because the call was already cancelled/ended — nothing more to send.
    _handlingIncomingCall = false;
    _activeIncomingChannelName = null;
  }

  void _reopenActiveRoom() {
    final roomId = ActiveRoomHolder.roomId;
    if (roomId == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Behind the Scaffold below — whether AppShell itself is the
        // visible screen (this Scaffold covers it) or some other route is
        // pushed on top (that route's own opaque background covers both),
        // this never needs to be explicitly hidden/positioned offscreen.
        // AppShell staying mounted underneath every pushed route (see the
        // class doc above) is exactly what lets this survive navigating
        // away from PartyScreen — see persistent_room_audio.dart.
        const PersistentRoomAudio(),
        const MentionNotifier(),
        _buildScaffold(),
      ],
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const InsyncTopBar(),
      // Lets Home's own scroll content show (blurred) through the glass
      // bottom nav instead of the bar sitting over a dead solid-color gap —
      // see LiquidGlassBottomNav.
      extendBody: false,
      // IndexedStack keeps hidden tabs' tickers running (maintainAnimation),
      // so wrap each tab in TickerMode — hidden tabs stop animating, and
      // screens like Home use TickerMode to pause their background polling.
      body: IndexedStack(index: _index, children: [
        for (var i = 0; i < _screens.length; i++)
          TickerMode(enabled: i == _index, child: _screens[i]),
      ]),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shows whenever a room's socket is still connected in the
          // background (see ActiveRoomHolder) — i.e. the user minimized
          // instead of hitting "Leave room". Lets them jump back in from
          // any tab without re-joining from scratch.
          ValueListenableBuilder<String?>(
            valueListenable: ActiveRoomHolder.activeLabel,
            builder: (context, label, _) {
              if (label == null) return const SizedBox.shrink();
              return _ActiveRoomBar(label: label, onTap: _reopenActiveRoom);
            },
          ),
          LiquidGlassBottomNav(
            currentIndex: _index,
            onTap: _onNavTap,
            items: _items,
            onCreateTap: () => showCreateSheet(context),
          ),
        ],
      ),
    );
  }
}

class _ActiveRoomBar extends StatelessWidget {
  const _ActiveRoomBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Material(
        color: AppColors.surface2,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const InIcon(InIcons.live, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                const Text('Tap to return',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 6),
                const InIcon(InIcons.chev, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
