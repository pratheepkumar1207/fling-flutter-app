import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_provider.dart';
import '../../core/socket_service.dart';
import '../../theme/app_colors.dart';
import '../discover/discover_screen.dart';
import '../feed/feed_screen.dart';
import '../home/home_screen.dart';
import '../lobby/lobby_create_screen.dart';
import '../lobby/lobby_join_screen.dart';
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
    NavItemData('🏠', 'Home'),
    NavItemData('📰', 'Feed'),
    NavItemData('🔥', 'Discover'),
    NavItemData('🎬', 'Rooms'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final socket = context.read<SocketService>();
      if (auth.token != null) socket.connect(auth.token!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const FlingTopBar(),
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyCreateScreen())),
        tooltip: 'Create a room',
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: LiquidGlassBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
      ),
    );
  }
}
