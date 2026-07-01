import 'package:flutter/material.dart';
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

      // First frame: Home is loading (before GolfProvider().getHome() settles).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // flutter_test blocks real HTTP (returns 400), so getData() reliably
      // resolves to the "load failed" state — a deterministic outcome we can
      // assert on without depending on network access in CI.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No se pudo cargar el contenido'), findsOneWidget);
    },
  );
}
