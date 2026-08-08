import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth_provider.dart';
import 'core/socket_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FlingApp());
}

class FlingApp extends StatelessWidget {
  const FlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SocketService()),
      ],
      child: MaterialApp(
        title: 'Fling',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
