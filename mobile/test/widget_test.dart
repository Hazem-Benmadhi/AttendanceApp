import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mobile/app.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_storage.dart';
import 'package:mobile/features/auth/data/auth_service.dart';
import 'package:mobile/features/capture/data/face_capture_service.dart';
import 'package:mobile/features/home/data/session_service.dart';

void main() {
  testWidgets('Shows login screen when unauthenticated', (tester) async {
    final controller = AuthController(
      authService: AuthService(),
      storage: InMemoryAuthStorage(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FaceCaptureService>.value(value: FaceCaptureService()),
          ChangeNotifierProvider<SessionService>.value(value: SessionService()),
          ChangeNotifierProvider<AuthController>.value(value: controller),
        ],
        child: const FaceRecognitionApp(),
      ),
    );

    // Allow the async restore to complete.
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
