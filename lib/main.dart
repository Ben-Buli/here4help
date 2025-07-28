// lib/main.dart (或你的路由配置檔)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/router/app_router.dart';
import 'package:here4help/auth/services/user_service.dart';

class Here4HelpApp extends StatelessWidget {
  const Here4HelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      title: 'Here4Help',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFFFFF), // White
        splashColor: const Color(0xFFA6D2E6), // Light Blue
        highlightColor: const Color(0xFFA6D2E6), // Light Blue
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF51A4C8), // Primary Blue
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF51A4C8), // Primary Blue
        ).copyWith(
          primary: const Color(0xFF51A4C8), // Primary Blue
          background: const Color(0xFFBFE5F1), // Sky Blue
          surface: const Color(0xFFF9FAFB),
          secondary: const Color(0xFFA6D2E6), // Light Blue
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        useMaterial3: true,
      ),
    );
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserService>(create: (_) => UserService()),
      ],
      child: const Here4HelpApp(),
    ),
  );
}
