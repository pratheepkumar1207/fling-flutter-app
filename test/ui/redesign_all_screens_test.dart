import 'dart:io';
import 'dart:ui' as ui;

import 'package:fling/core/auth_provider.dart';
import 'package:fling/models/user.dart';
import 'package:fling/theme/app_theme.dart';
import 'package:fling/screens/achievements/achievements_screen.dart';
import 'package:fling/screens/challenges/challenges_screen.dart';
import 'package:fling/screens/communities/communities_screen.dart';
import 'package:fling/screens/discover/discover_matches_screen.dart';
import 'package:fling/screens/discover/random_match_screen.dart';
import 'package:fling/screens/events/events_screen.dart';
import 'package:fling/screens/experience/experience_hub.dart';
import 'package:fling/screens/feed/saved_posts_screen.dart';
import 'package:fling/screens/friends/friends_screen.dart';
import 'package:fling/screens/leaderboards/leaderboards_screen.dart';
import 'package:fling/screens/notifications/notifications_screen.dart';
import 'package:fling/screens/profile/close_friends_screen.dart';
import 'package:fling/screens/profile/user_list_screen.dart';
import 'package:fling/screens/search/search_screen.dart';
import 'package:fling/screens/settings/blocked_accounts_screen.dart';
import 'package:fling/screens/settings/help_center_screen.dart';
import 'package:fling/screens/settings/language_preferences_screen.dart';
import 'package:fling/screens/settings/privacy_screen.dart';
import 'package:fling/screens/wallet/livestream_dashboard_screen.dart';
import 'package:fling/screens/wallet/referral_screen.dart';
import 'package:fling/screens/wallet/spin_wheel_screen.dart';
import 'package:fling/screens/wallet/vip_store_screen.dart';
import 'package:fling/screens/wallet/wallet_buy_screen.dart';
import 'package:fling/screens/wallet/wallet_cashout_screen.dart';
import 'package:fling/screens/wallet/wallet_kyc_screen.dart';
import 'package:fling/screens/profile/creator_profile_screen.dart';
import 'package:fling/screens/communities/community_detail_screen.dart';
import 'package:fling/screens/feed/post_detail_screen.dart';
import 'package:fling/screens/feed/hashtag_screen.dart';
import 'package:fling/screens/lobby/invite_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every secondary screen (empty states, no server) at a normal
/// phone and at a small phone with large text — layout errors fail.
class _FakeAuth extends AuthProvider {
  final User _u =
      User.fromJson({'id': 'me', 'name': 'Test User', 'isVip': false});
  @override
  User? get user => _u;
}

final _key = GlobalKey();

Future<void> _render(WidgetTester t, Widget w, Size size, double text) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: _FakeAuth(),
    child: MaterialApp(
      theme: AppTheme.darkWithoutWebFonts(),
      builder: (c, child) => RepaintBoundary(key: _key, child: child),
      home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
          child: w),
    ),
  ));
  await t
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // Plugins with no test implementation.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('razorpay_flutter'), (_) async => null);
    final loader = FontLoader('Roboto');
    loader.addFont(File('test/fixtures/roboto-regular.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
    await loader.load();
  });

  final cases = <(String, Widget)>[
    ('CreatorProfileScreen', const CreatorProfileScreen(userId: 'u1')),
    (
      'CommunityDetailScreen',
      const CommunityDetailScreen(communityId: 'c1', name: 'Tamil cinema club')
    ),
    ('PostDetailScreen', const PostDetailScreen(postId: 'p1')),
    ('HashtagScreen', const HashtagScreen(tag: 'movienight')),
    ('InviteScreen', const InviteScreen(roomId: 'r1')),
    ('NotificationsScreen', const NotificationsScreen()),
    ('SearchScreen', const SearchScreen()),
    ('FriendsScreen', const FriendsScreen()),
    ('CommunitiesScreen', const CommunitiesScreen()),
    ('EventsScreen', const EventsScreen()),
    ('LeaderboardsScreen', const LeaderboardsScreen()),
    ('AchievementsScreen', const AchievementsScreen()),
    ('ChallengesScreen', const ChallengesScreen()),
    ('FlingFeatureHubScreen', const FlingFeatureHubScreen()),
    ('VipStoreScreen', const VipStoreScreen()),
    ('SpinWheelScreen', const SpinWheelScreen()),
    ('ReferralScreen', const ReferralScreen()),
    ('WalletKycScreen', const WalletKycScreen()),
    ('WalletCashoutScreen', const WalletCashoutScreen()),
    ('WalletBuyScreen', const WalletBuyScreen()),
    ('LivestreamDashboardScreen', const LivestreamDashboardScreen()),
    ('PrivacyScreen', const PrivacyScreen()),
    ('BlockedAccountsScreen', const BlockedAccountsScreen()),
    ('LanguagePreferencesScreen', const LanguagePreferencesScreen()),
    ('HelpCenterScreen', const HelpCenterScreen()),
    ('SavedPostsScreen', const SavedPostsScreen()),
    ('DiscoverMatchesScreen', const DiscoverMatchesScreen()),
    ('RandomMatchScreen', const RandomMatchScreen()),
    ('CloseFriendsScreen', const CloseFriendsScreen()),
    ('UserListScreen', const UserListScreen()),
    ('ArchiveScreen', const ArchiveScreen()),
  ];
  for (final (name, w) in cases) {
    testWidgets('$name renders', (t) async {
      await _render(t, w, const Size(390, 844), 1);
      expect(t.takeException(), isNull);
      final b =
          _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await b.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/design-preview/all/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
    testWidgets('$name fits a small phone with large text', (t) async {
      await _render(t, w, const Size(320, 640), 1.6);
      expect(t.takeException(), isNull);
    });
  }
}
