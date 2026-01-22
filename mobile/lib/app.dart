import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/application/auth_notifier.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';

class FaceRecognitionApp extends StatelessWidget {
  const FaceRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Face ID',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (_, authController, __) {
        switch (authController.status) {
          case AuthStatus.initializing:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator.adaptive()),
            );
          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.error:
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}
