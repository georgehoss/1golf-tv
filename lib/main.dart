import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'src/controllers/auth_controller.dart';
import 'src/pages/home/home_page.dart';
import 'src/pages/sign_in/qr_login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authController = Get.put(AuthController());
  await authController.restoreSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return GetMaterialApp(
      title: '1Golf',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        fontFamily: 'Inter',
        primaryColor: const Color(0xFF000354),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF000354),
          secondary: Color(0xFFFBB03B),
        ),
      ),
      getPages: [
        GetPage(name: '/', page: () => const HomePage()),
        GetPage(name: '/home', page: () => const HomePage()),
        GetPage(name: '/login', page: () => const QRLoginPage()),
      ],
      initialRoute: authController.isAuthenticated.value ? '/' : '/login',
      unknownRoute: GetPage(name: '/', page: () => const HomePage()),
    );
  }
}
