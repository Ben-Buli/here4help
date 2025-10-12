import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:here4help/router/app_router.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/config/environment_config_legacy.dart';
import 'package:here4help/services/error_reporting_service.dart';
import 'package:here4help/providers/permission_provider.dart';
import 'package:here4help/providers/rating_provider.dart';
import 'package:here4help/providers/achievement_provider.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/services/web_environment_bridge.dart';

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
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // ✅ 改用 dart-define 讀取環境
    const appEnv =
        String.fromEnvironment("ENVIRONMENT", defaultValue: "development");
    const appDebug = bool.fromEnvironment("APP_DEBUG", defaultValue: false);

    debugPrint("✅ dart-define loaded, ENVIRONMENT=$appEnv, DEBUG=$appDebug");

    // 初始化環境配置
    await EnvironmentConfig.initialize();

    // 初始化權限狀態
    await PermissionProvider.instance.initialize();

    // 初始化錯誤報告服務
    await ErrorReportingService.initialize();

    // 打印環境信息
    EnvironmentConfig.printEnvironmentInfo();

    // 初始化 Web 環境配置橋接器 (僅限 Web 平台)
    if (kIsWeb) {
      WebEnvironmentBridge.instance.initializeWebConfig();
    }

    // ✅ 主動初始化 UserService
    final userService = UserService();
    await userService.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserService>.value(value: userService),
          ChangeNotifierProvider<ThemeConfigManager>(
              create: (_) => ThemeConfigManager()),
          ChangeNotifierProvider<PermissionProvider>.value(
              value: PermissionProvider.instance),
          ChangeNotifierProvider<RatingProvider>(
              create: (_) => RatingProvider()),
          ChangeNotifierProvider<AchievementProvider>(
              create: (_) => AchievementProvider()),
          ChangeNotifierProvider<ChatListProvider>(
              create: (_) => ChatListProvider(userService: userService)),
        ],
        child: const Here4HelpApp(),
      ),
    );
  } catch (e, s) {
    debugPrint("❌ 初始化失敗: $e");
    debugPrintStack(stackTrace: s);

    // 不直接 return，給一個錯誤頁
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("初始化失敗: $e")),
      ),
    ));
  }
}
