import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'tournament_cards.dart';
import 'tournament_create_screen.dart';

/// Every open tournament in one place (Popcorn's top bar → Tournament),
/// with a button to host one.
class TournamentsListScreen extends StatelessWidget {
  const TournamentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Tournaments')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: const [TournamentPopcornSection(vertical: true)],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const TournamentCreateScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Host a tournament'),
      ),
    );
  }
}
