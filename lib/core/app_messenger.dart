import 'package:flutter/material.dart';

/// Global key for showing SnackBars from code that doesn't have a
/// BuildContext of its own — e.g. a chat @mention notification, which must
/// work no matter which screen is currently showing (Home, Feed, chat —
/// not just while PartyScreen itself happens to be mounted). Wired into
/// MaterialApp.scaffoldMessengerKey in main.dart.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
