// app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:here4help/constants/app_scaffold_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===== Auth 模組 =====
import 'package:here4help/auth/pages/login_page.dart';

// ===== System 模組 =====
import 'package:here4help/system/pages/banned_page.dart';
import 'package:here4help/system/pages/unauthorized_page.dart';

// ===== 其他 =====
import 'package:here4help/widgets/error_page.dart';
import 'package:here4help/layout/app_scaffold.dart';
import 'package:here4help/constants/shell_pages.dart';

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
      print('✅ 公開頁面，允許訪問: ${state.uri.path}');
      return null;
    }

    // 如果未登入且不在公開頁面，導向登入頁面
    if (email == null) {
      print('➡️ 未登入用戶重定向到登入頁面');
      return '/login';
    }

    // 如果已登入且訪問登入頁面，導向首頁
    if (state.uri.path == '/login') {
      print('➡️ 已登入用戶重定向到首頁');
      return '/home';
    }

    print('✅ 保持當前路由: ${state.uri.path}');
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
            .where((page) => state.uri.path.startsWith(page['path']))
            .toList()
            // 選擇路徑最長的匹配項目
            .reduce((bestMatch, current) {
              return current['path'].length > bestMatch['path'].length
                  ? current
                  : bestMatch;
            });

        return AppScaffold(
          title: pageConfig['title'] ?? AppScaffoldDefaults.defaultTitle,
          showAppBar:
              pageConfig['showAppBar'] ?? AppScaffoldDefaults.defaultShowAppBar,
          showBottomNav: pageConfig['showBottomNav'] ??
              AppScaffoldDefaults.defaultShowBottomNav,
          showBackArrow: pageConfig['showBackArrow'] ??
              AppScaffoldDefaults.defaultShowBackArrow,
          centerTitle: AppScaffoldDefaults.defaultCenterTitle,
          actions: pageConfig['actions'] ?? AppScaffoldDefaults.defaultActions,
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
    GoRoute(path: '/banned', builder: (_, __) => const BannedPage()),
    GoRoute(
        path: '/unauthorized', builder: (_, __) => const UnauthorizedPage()),
    // ... 其他 routes ...
  ],
  // ❌ 找不到路由或錯誤時顯示的備援頁面
  errorBuilder: (context, state) => ErrorPage(
    error: state.error,
    // 你可以根據 state.error 或 state.uri 判斷 statusCode
  ),
);
