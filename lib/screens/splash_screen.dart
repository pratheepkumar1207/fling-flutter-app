import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/spinner.dart';
import 'auth/login_screen.dart';
import 'shell/app_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.loading:
            return const Scaffold(
              backgroundColor: AppColors.bg,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Fling',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 24),
                    Spinner(),
                  ],
                ),
              ),
            );
          case AuthStatus.anon:
            return const LoginScreen();
          case AuthStatus.authed:
            return const AppShell();
        }
      },
    );
  }
}
