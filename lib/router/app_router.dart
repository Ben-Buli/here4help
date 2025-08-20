// app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:here4help/constants/app_scaffold_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===== Auth 模組 =====
import 'package:here4help/auth/pages/login_page.dart';
import 'package:here4help/auth/pages/auth_callback_page.dart';

// ===== System 模組 =====
import 'package:here4help/system/pages/banned_page.dart';
import 'package:here4help/system/pages/unauthorized_page.dart';

// ===== 其他 =====
import 'package:here4help/widgets/error_page.dart';
import 'package:here4help/layout/app_scaffold.dart';
import 'package:here4help/constants/shell_pages.dart';

// ===== Debug 模組 =====
import 'package:here4help/debug/unread_api_test_page.dart';
import 'package:here4help/debug/unread_timing_test_page.dart';

// 定義 Account 模組的路由與對應頁面
class AccountRouteItem {
  final String route;
  final Widget page;
  const AccountRouteItem({required this.route, required this.page});
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  // 🔁 全域導向邏輯（登入狀態與權限控管）：
  // - 未登入者會被導向 /login
  // - 已登入者若訪問 /login，則導向 /home
  // - 被封鎖者導向 /banned
  // - 權限不足者導向 /unauthorized
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');

    print('🔄 路由重定向檢查: ${state.uri.path}');
    print('👤 用戶狀態: ${email != null ? "已登入 ($email)" : "未登入"}');

    // 定義公開頁面（不需要登入驗證）
    final publicPages = ['/login', '/signup', '/signup/student-id'];

    // 如果是公開頁面，允許訪問
    if (publicPages.contains(state.uri.path)) {
      return null;
    }

    // 如果未登入且不在公開頁面，導向登入頁面
    if (email == null) {
      return '/login';
    }

    // 如果已登入且訪問登入頁面，導向首頁
    if (state.uri.path == '/login') {
      return '/home';
    }

    return null; // 保持當前路由
  },
  // 📍 應用中的所有路由定義（使用 GoRoute）
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        // 動態解析當前路徑的屬性
        final pageConfig = shellPages
            .expand((page) {
              final List<Map<String, dynamic>>? subRoutes = page['routes'];
              return subRoutes != null
                  ? [
                      page,
                      ...subRoutes.map((subRoute) {
                        return {
                          ...subRoute,
                          'path':
                              '${page['path']}/${subRoute['path']}', // 拼接完整路徑
                        };
                      })
                    ]
                  : [page];
            })
            // 過濾出與當前路徑匹配的頁面
            .where((page) {
              final pagePath = page['path'] as String;
              final currentPath = state.uri.path;

              // 精確匹配或前綴匹配
              if (currentPath == pagePath) return true;
              if (currentPath.startsWith('$pagePath/')) return true;

              return false;
            })
            .toList()
            // 選擇路徑最長的匹配項目
            .reduce((bestMatch, current) {
              return current['path'].length > bestMatch['path'].length
                  ? current
                  : bestMatch;
            });

        // 處理 actions
        List<Widget>? actions;
        if (pageConfig.containsKey('actionsBuilder')) {
          final actionsBuilder = pageConfig['actionsBuilder'] as List<Widget>
              Function(BuildContext);
          actions = actionsBuilder(context);
        } else {
          actions = pageConfig['actions'] ?? AppScaffoldDefaults.defaultActions;
        }

        // 若頁面提供自訂 titleWidgetBuilder，使用它來創建 titleWidget
        Widget? titleWidget;
        if (pageConfig['titleWidgetBuilder'] != null) {
          debugPrint('🔍 [app_router] 找到 titleWidgetBuilder，準備調用');
          debugPrint('🔍 [app_router] state.extra: ${state.extra}');
          final builderFn = pageConfig['titleWidgetBuilder'] as Widget Function(
              BuildContext, dynamic);
          titleWidget = builderFn(context, state.extra);
          debugPrint(
              '🔍 [app_router] titleWidget 創建完成: ${titleWidget.runtimeType}');
        } else if (pageConfig['appBarBuilder'] != null) {
          // 保持對舊式 appBarBuilder 的支援
          final builderFn = pageConfig['appBarBuilder'] as PreferredSizeWidget
              Function(BuildContext, dynamic);
          final customAppBar = builderFn(context, state.extra);
          if (customAppBar is AppBar) {
            titleWidget = (customAppBar).title;
          }
        }

        debugPrint('🔍 [app_router] 準備創建 AppScaffold');
        debugPrint('🔍 [app_router] title: ${pageConfig['title']}');
        debugPrint('🔍 [app_router] titleWidget: ${titleWidget.runtimeType}');

        return AppScaffold(
          title: pageConfig['title'] ?? AppScaffoldDefaults.defaultTitle,
          titleWidget: titleWidget, // 只傳遞 title 組件
          showAppBar:
              pageConfig['showAppBar'] ?? AppScaffoldDefaults.defaultShowAppBar,
          showBottomNav: pageConfig['showBottomNav'] ??
              AppScaffoldDefaults.defaultShowBottomNav,
          showBackArrow: pageConfig['showBackArrow'] ??
              AppScaffoldDefaults.defaultShowBackArrow,
          centerTitle: AppScaffoldDefaults.defaultCenterTitle,
          actions: actions,
          child: child,
        );
      },
      routes: [
        // 優化 routes: [] 的邏輯，展開子路徑
        ...shellPages.expand((page) {
          final List<Map<String, dynamic>>? subRoutes = page['routes'];
          return subRoutes != null
              ? [
                  GoRoute(
                    path: page['path'],
                    pageBuilder: (context, state) {
                      if (page.containsKey('builder')) {
                        final builderFunction = page['builder'] as Widget
                            Function(BuildContext, dynamic);
                        return NoTransitionPage(
                          child: builderFunction(context, state.extra),
                        );
                      } else {
                        return NoTransitionPage(
                          child: page['child'] as Widget,
                        );
                      }
                    },
                    routes: subRoutes.map((subRoute) {
                      return GoRoute(
                        path: subRoute['path'],
                        pageBuilder: (context, state) {
                          if (subRoute.containsKey('builder')) {
                            return NoTransitionPage(
                              child: subRoute['builder'](context, state.extra),
                            );
                          } else {
                            return NoTransitionPage(
                              child: subRoute['child'],
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                ]
              : [
                  GoRoute(
                    path: page['path'],
                    pageBuilder: (context, state) {
                      if (page.containsKey('builder')) {
                        final builderFunction = page['builder'] as Widget
                            Function(BuildContext, dynamic);
                        return NoTransitionPage(
                          child: builderFunction(context, state.extra),
                        );
                      } else {
                        return NoTransitionPage(
                          child: page['child'] as Widget,
                        );
                      }
                    },
                  ),
                ];
        }).toList(),
      ],
    ),
    // 其他非底部導航頁面
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(
        path: '/auth/callback', builder: (_, __) => const AuthCallbackPage()),
    GoRoute(path: '/banned', builder: (_, __) => const BannedPage()),
    GoRoute(
        path: '/unauthorized', builder: (_, __) => const UnauthorizedPage()),
    // Debug 頁面
    GoRoute(
        path: '/debug/unread-api',
        builder: (_, __) => const UnreadApiTestPage()),
    GoRoute(
        path: '/debug/unread-timing',
        builder: (_, __) => const UnreadTimingTestPage()),
    // ... 其他 routes ...
  ],
  // ❌ 找不到路由或錯誤時顯示的備援頁面
  errorBuilder: (context, state) => ErrorPage(
    error: state.error,
    // 你可以根據 state.error 或 state.uri 判斷 statusCode
  ),
);
