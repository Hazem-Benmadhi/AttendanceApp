import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/config_controller.dart';
import 'features/auth/application/auth_notifier.dart';
import 'features/auth/data/auth_service.dart';
import 'features/capture/application/capture_workflow_controller.dart';
import 'features/capture/data/face_capture_service.dart';
import 'features/home/data/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configController = ConfigController();
  await configController.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConfigController>.value(value: configController),
        ProxyProvider<ConfigController, AuthService>(
          update: (_, config, service) {
            service ??= AuthService(baseUrl: config.baseUrl);
            service.updateBaseUrl(config.baseUrl);
            return service;
          },
        ),
        ProxyProvider<ConfigController, FaceCaptureService>(
          update: (_, config, service) {
            service ??= FaceCaptureService(baseUrl: config.baseUrl);
            service.updateBaseUrl(config.baseUrl);
            return service;
          },
        ),
        ChangeNotifierProxyProvider<ConfigController, SessionService>(
          create: (_) => SessionService(baseUrl: configController.baseUrl),
          update: (_, config, service) {
            service ??= SessionService(baseUrl: config.baseUrl);
            service.updateBaseUrl(config.baseUrl);
            return service;
          },
        ),
        ChangeNotifierProvider<CaptureWorkflowController>(
          create: (_) => CaptureWorkflowController(),
        ),
        ChangeNotifierProxyProvider<AuthService, AuthController>(
          create:
              (context) =>
                  AuthController(authService: context.read<AuthService>()),
          update: (_, authService, controller) {
            controller ??= AuthController(authService: authService);
            controller.updateAuthService(authService);
            return controller;
          },
        ),
      ],
      child: const FaceRecognitionApp(),
    ),
  );
}
