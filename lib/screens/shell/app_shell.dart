import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    NavItemData(Icons.home_rounded, 'Home'),
    NavItemData(Icons.article_rounded, 'Feed'),
    NavItemData(Icons.local_fire_department_rounded, 'Discover'),
    NavItemData(Icons.theaters_rounded, 'Rooms'),
  ];

  bool _handlingIncomingCall = false;

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
  }

  Future<void> _showIncomingCall(Map<String, dynamic> data) async {
    _handlingIncomingCall = true;
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
    } else {
      ApiClient.post('/calls/direct-decline', body: {'channelName': channelName}).catchError((_) => null);
    }
    _handlingIncomingCall = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const FlingTopBar(),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: LiquidGlassBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
        onCreateTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyCreateScreen())),
      ),
    );
  }
}
