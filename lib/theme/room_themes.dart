import 'package:flutter/material.dart';

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

  static const all = [midnight, cinema, neon, sunset];

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
