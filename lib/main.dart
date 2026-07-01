import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'src/pages/home/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '1Golf',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        fontFamily: 'Inter',
        primaryColor: const Color(0xFF0B3B24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0B3B24),
          secondary: Color(0xFF6CBE45),
        ),
      ),
      getPages: [
        GetPage(name: '/', page: () => const HomePage()),
        GetPage(name: '/home', page: () => const HomePage()),
      ],
      initialRoute: '/',
      unknownRoute: GetPage(name: '/', page: () => const HomePage()),
    );
  }
}
