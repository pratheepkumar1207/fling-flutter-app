import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../screens/profile/creator_profile_screen.dart';
import '../screens/profile/profile_screen.dart';

/// Single entry point for "tap someone's avatar/name, see their profile" —
/// used everywhere a person (not a room/community) is shown as an avatar.
/// Routes to the tappable-own-profile screen for the signed-in user and
/// CreatorProfileScreen for anyone else, so call sites don't need to know
/// which case they're in.
void openProfile(BuildContext context, String? userId) {
  if (userId == null || userId.isEmpty) return;
  final myId = context.read<AuthProvider>().user?.id;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => userId == myId ? const ProfileScreen() : CreatorProfileScreen(userId: userId),
  ));
}
