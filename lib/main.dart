// lib/main.dart (或你的路由配置檔)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/router/app_router.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/theme_service.dart';

class Here4HelpApp extends StatelessWidget {
  const Here4HelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp.router(
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          title: 'Here4Help',
          theme: themeService.themeData,
        );
      },
    );
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserService>(create: (_) => UserService()),
        ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
      ],
      child: const Here4HelpApp(),
    ),
  );
}
