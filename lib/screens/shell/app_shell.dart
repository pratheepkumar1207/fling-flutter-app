import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/active_room_holder.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../calls/call_screen.dart';
import '../discover/discover_screen.dart';
import '../feed/feed_screen.dart';
import '../home/home_screen.dart';
import '../lobby/lobby_create_screen.dart';
import '../lobby/lobby_join_screen.dart';
import '../party/party_screen.dart';
import '../../widgets/avatar.dart';
import 'liquid_glass_bottom_nav.dart';
import 'top_bar.dart';

/// Mirrors src/layout/AppShell.jsx's PRIMARY_NAV — Home/Feed/Discover/Rooms
/// as bottom tabs (mobile-first, unlike the web app's sidebar+bottom-nav
/// split), with the same persistent TopBar above.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    FeedScreen(),
    DiscoverScreen(),
    LobbyJoinScreen(),
  ];

  static const _items = [
    NavItemData(Icons.home_rounded, 'Home', iconAsset: 'assets/icons/app/home.png'),
    NavItemData(Icons.article_rounded, 'Feed', iconAsset: 'assets/icons/app/feed.png'),
    NavItemData(Icons.local_fire_department_rounded, 'Discover', iconAsset: 'assets/icons/app/discover.png'),
    // No matching asset was uploaded for "Rooms" — stays on the Material
    // icon until one is provided.
    NavItemData(Icons.theaters_rounded, 'Rooms'),
  ];

  bool _handlingIncomingCall = false;
  // Channel of the incoming-call dialog currently showing, if any — lets
  // _bindIncomingCalls tell whether a call:cancelled/call:ended event
  // matches the call the user is currently being asked about.
  String? _activeIncomingChannelName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final socket = context.read<SocketService>();
      if (auth.token != null) socket.connect(auth.token!);
      _bindIncomingCalls(socket);
    });
  }

  // Global 1:1-call listener — bound once here (AppShell stays mounted
  // under whatever screen the user navigates to, since those are pushed on
  // top of it) so an incoming call rings no matter what the user is
  // currently looking at. See calls.js's direct-invite route.
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
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Row(children: [
          Avatar(src: data['fromAvatarUrl'] as String?, name: data['fromName'] as String?, size: AvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(child: Text(data['fromName'] as String? ?? 'Someone')),
        ]),
        content: Text(data['mode'] == 'video' ? 'Incoming video call…' : 'Incoming audio call…'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Decline')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Accept')),
        ],
      ),
    );

    final channelName = data['channelName'] as String;
    if (accepted == true) {
      try {
        final response = await ApiClient.post('/calls/direct-accept', body: {'channelName': channelName}) as Map<String, dynamic>;
        if (mounted) {
          Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
            builder: (_) => CallScreen(
              channelName: channelName,
              token: response['token'] as String,
              uid: response['uid'] as int,
              video: data['mode'] == 'video',
              isCaller: false,
              peerName: data['fromName'] as String? ?? 'Someone',
              peerAvatarUrl: data['fromAvatarUrl'] as String?,
            ),
          ));
        }
      } catch (_) {
        // Couldn't connect — nothing more to do than let it drop.
      }
    } else if (accepted == false) {
      ApiClient.post('/calls/direct-decline', body: {'channelName': channelName}).catchError((_) => null);
    }
    // accepted == null: dialog was auto-dismissed by dismissIfStale above
    // because the call was already cancelled/ended — nothing more to send.
    _handlingIncomingCall = false;
    _activeIncomingChannelName = null;
  }

  void _reopenActiveRoom() {
    final roomId = ActiveRoomHolder.roomId;
    if (roomId == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartyScreen(roomId: roomId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const FlingTopBar(),
      body: IndexedStack(index: _index, children: _screens),
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
            onTap: (i) => setState(() => _index = i),
            items: _items,
            onCreateTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyCreateScreen())),
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
                const Icon(Icons.podcasts_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const Text('Tap to return', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
