// lib/main.dart (或你的路由配置檔)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/router/app_router.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/config/environment_config.dart';
import 'package:here4help/services/error_reporting_service.dart';

class Here4HelpApp extends StatelessWidget {
  const Here4HelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return MaterialApp.router(
          routerConfig: appRouter,
          debugShowCheckedModeBanner: EnvironmentConfig.debugMode,
          title: 'Here4Help',
          theme: themeManager.themeData,
        );
      },
    );
  }
}

void main() async {
  // 確保 Flutter 綁定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化環境配置
  await EnvironmentConfig.initialize();

  // 初始化錯誤報告服務
  ErrorReportingService.initialize();

  // 打印環境信息
  EnvironmentConfig.printEnvironmentInfo();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserService>(create: (_) => UserService()),
        ChangeNotifierProvider<ThemeConfigManager>(
            create: (_) => ThemeConfigManager()),
      ],
      child: const Here4HelpApp(),
    ),
  );
}
