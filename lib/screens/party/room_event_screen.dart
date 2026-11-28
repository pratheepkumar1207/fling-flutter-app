import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/insync_icons.dart';
import '../discover/map_explore_screen.dart';

/// The big lobby moments, as one full card: the lobby ended, or you were
/// removed from it. Find another lobby, or go home.
class RoomEventScreen extends StatelessWidget {
  final InIconData icon;
  final String title;
  final String message;
  const RoomEventScreen(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});

  factory RoomEventScreen.ended({required String by, String? roomTitle}) =>
      RoomEventScreen(
        icon: InIcons.logout,
        title: 'The lobby has ended',
        message: roomTitle == null || roomTitle.isEmpty
            ? '$by ended the lobby.'
            : '$by closed $roomTitle.',
      );

  factory RoomEventScreen.removed() => const RoomEventScreen(
        icon: InIcons.block,
        title: 'You were removed',
        message: 'The host removed you from this lobby.',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: InIcon(icon, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.4)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder()),
                onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) =>
                            const MapExploreScreen(startOnRooms: true))),
                child: const Text('Find another lobby',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: const StadiumBorder()),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go home',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
