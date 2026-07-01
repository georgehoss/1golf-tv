import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:one_golf_android_tv/main.dart';
import 'package:one_golf_android_tv/src/controllers/auth_controller.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets(
    'App boots to Home when a session is already authenticated',
    (WidgetTester tester) async {
      // Pre-seed an authenticated session so this stays a hermetic widget
      // test: it must not depend on the real QR login network calls that
      // the login route triggers on mount.
      final authController = Get.put(AuthController());
      authController.isAuthenticated.value = true;

      await tester.pumpWidget(const MyApp());

      expect(find.text('1Golf TV'), findsOneWidget);
    },
  );
}
