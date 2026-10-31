import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../widgets/app_image.dart';

/// Lobby themes the host picks in Room settings (watch, voice and game
/// rooms). A theme changes the room's backdrop, accent (buttons, progress
/// bar, your own chat bubbles), name colour in chat and the player frame;
/// the video and each person's own player settings are untouched. The id
/// is stored on the room (Room.theme on the backend) so everyone sees the
/// same one. 'midnight' is the look rooms always had.
class RoomTheme {
  final String id;
  final String label;
  final LinearGradient bgGradient;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color primary;
  final Color nameAccent;
  final Color text;
  final Color textDim;
  final Color textFaint;
  // Glass: the backdrop is a blurred, darkened copy of what's playing
  // (see RoomBackdrop) and the surfaces are see-through.
  final bool glass;

  const RoomTheme({
    required this.id,
    required this.label,
    required this.bgGradient,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.primary,
    required this.nameAccent,
    this.text = const Color(0xFFF4F5F6),
    required this.textDim,
    required this.textFaint,
    this.glass = false,
  });

  static const midnight = RoomTheme(
    id: 'midnight',
    label: 'Midnight',
    bgGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF203052), Color(0xFF0C1226)],
    ),
    surface: Color(0xFF16213D),
    surface2: Color(0xFF203052),
    border: Color(0x33FFFFFF),
    primary: Color(0xFF2455F5),
    nameAccent: Color(0xFFD4FF65),
    textDim: Color(0xFFADBBD7),
    textFaint: Color(0xFF91A1C2),
  );

  static const cinema = RoomTheme(
    id: 'cinema',
    label: 'Cinema',
    bgGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C0B0D), Color(0xFF0A0A0A)],
    ),
    surface: Color(0xFF1A1011),
    surface2: Color(0xFF26141A),
    border: Color(0x40B20710),
    primary: Color(0xFFE50914),
    nameAccent: Color(0xFFF5C518),
    textDim: Color(0xFFC9B9BB),
    textFaint: Color(0xFF9A8A8C),
  );

  static const neon = RoomTheme(
    id: 'neon',
    label: 'Neon club',
    bgGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF241A3F), Color(0xFF0B0714)],
    ),
    surface: Color(0xFF1B1330),
    surface2: Color(0xFF2E2350),
    border: Color(0x4D9B5CF6),
    primary: Color(0xFF9B5CF6),
    nameAccent: Color(0xFFFF7AD9),
    textDim: Color(0xFFB6A9D6),
    textFaint: Color(0xFF8C7FB2),
  );

  static const sunset = RoomTheme(
    id: 'sunset',
    label: 'Sunset',
    bgGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A1D16), Color(0xFF1A0F12)],
    ),
    surface: Color(0xFF2A1714),
    surface2: Color(0xFF3B231C),
    border: Color(0x4DF97316),
    primary: Color(0xFFEA580C),
    nameAccent: Color(0xFFFCD34D),
    textDim: Color(0xFFD8BCB0),
    textFaint: Color(0xFFB0958A),
  );

  static const glassy = RoomTheme(
    id: 'glass',
    label: 'Glass',
    // Shown only when there's nothing to blur behind the room.
    bgGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A1430), Color(0xFF121733)],
    ),
    surface: Color(0x1FFFFFFF),
    surface2: Color(0x2EFFFFFF),
    border: Color(0x38FFFFFF),
    primary: Color(0xFF9B3BF5),
    nameAccent: Color(0xFFFFD54D),
    textDim: Color(0xFFE4E1EC),
    textFaint: Color(0xFFC4C0D0),
    glass: true,
  );

  // True black for AMOLED screens and night viewing.
  static const dark = RoomTheme(
    id: 'dark',
    label: 'Dark',
    bgGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0B0B0F), Color(0xFF000000)],
    ),
    surface: Color(0xFF141418),
    surface2: Color(0xFF1C1C22),
    border: Color(0x26FFFFFF),
    primary: Color(0xFF52525B),
    nameAccent: Color(0xFFE4E4E7),
    textDim: Color(0xFFA1A1AA),
    textFaint: Color(0xFF71717A),
  );

  static const all = [midnight, cinema, neon, sunset, glassy, dark];

  static RoomTheme _game(
          String id, String label, Color top, Color bottom, Color primary) =>
      RoomTheme(
        id: id,
        label: label,
        bgGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        surface: bottom,
        surface2: top,
        border: const Color(0x33FFFFFF),
        primary: primary,
        nameAccent: const Color(0xFFD4FF65),
        textDim: const Color(0xFFC9C4D6),
        textFaint: const Color(0xFFA9A3B8),
      );

  /// The look around a game room; the card on Home uses the same colour.
  static RoomTheme forGame(String? type) => switch (type) {
        'chess' => _game('chess', 'Chess', const Color(0xFF1C3A32),
            const Color(0xFF0E1C18), const Color(0xFF4F9A7E)),
        'tictactoe' => _game(
            'tictactoe',
            'Tic Tac Toe',
            const Color(0xFF2A2248),
            const Color(0xFF12102A),
            const Color(0xFF7A62E0)),
        'ludo' => _game('ludo', 'Ludo', const Color(0xFF40301F),
            const Color(0xFF1E160E), const Color(0xFFC98A2E)),
        'uno' => _game('uno', 'UNO', const Color(0xFF462222),
            const Color(0xFF1E0E0E), const Color(0xFFD8344A)),
        'truth_or_dare' => _game(
            'truth_or_dare',
            'Truth or Dare',
            const Color(0xFF341A4C),
            const Color(0xFF170B22),
            const Color(0xFF9A4FD0)),
        'would_you_rather' => _game(
            'would_you_rather',
            'Would You Rather',
            const Color(0xFF16364C),
            const Color(0xFF0A1824),
            const Color(0xFF3E8FC9)),
        _ => midnight,
      };

  static RoomTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => midnight);

  /// The room theme around [context], or Midnight outside a room.
  static RoomTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoomThemeScope>()?.theme ??
      midnight;
}

/// Makes the room's theme available to everything inside the room screen.
class RoomThemeScope extends InheritedWidget {
  final RoomTheme theme;
  const RoomThemeScope({super.key, required this.theme, required super.child});

  @override
  bool updateShouldNotify(RoomThemeScope old) => old.theme.id != theme.id;
}

/// The room's background: the theme's gradient, or for Glass a blurred,
/// darkened copy of [imageUrl] (the poster or cover of what's playing, or
/// the host's photo). The blurred layer only repaints when the image
/// changes, so it stays smooth on low-end phones.
class RoomBackdrop extends StatelessWidget {
  final RoomTheme theme;
  final String? imageUrl;
  final Widget child;
  const RoomBackdrop(
      {super.key,
      required this.theme,
      required this.imageUrl,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (!theme.glass || url == null || url.isEmpty) {
      return DecoratedBox(
          decoration: BoxDecoration(gradient: theme.bgGradient), child: child);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: theme.bgGradient)),
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: AppImage(key: ValueKey(url), source: url, fit: BoxFit.cover),
          ),
        ),
        const ColoredBox(color: Color(0x80080810)),
        child,
      ],
    );
  }
}
