// lib/main.dart (或你的路由配置檔)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/router/app_router.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/services/task_status_service.dart';
import 'package:here4help/task/services/task_favorites_service.dart';

class Here4HelpApp extends StatelessWidget {
  const Here4HelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return MaterialApp.router(
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          title: 'Here4Help',
          theme: themeManager.themeData,
        );
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化任務狀態服務
  final taskStatusService = TaskStatusService();
  await taskStatusService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserService>(create: (_) => UserService()),
        ChangeNotifierProvider<ThemeConfigManager>(
            create: (_) => ThemeConfigManager()),
        ChangeNotifierProvider<TaskStatusService>.value(
            value: taskStatusService),
        ChangeNotifierProvider<TaskFavoritesService>(
            create: (_) => TaskFavoritesService()),
      ],
      child: const Here4HelpApp(),
    ),
  );
}
