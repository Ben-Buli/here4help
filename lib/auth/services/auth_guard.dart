// auth_guard.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/system/pages/banned_page.dart';
import 'package:here4help/system/pages/unknown_page.dart';
import 'package:here4help/constants/route_permissions.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:here4help/widgets/custom_popup.dart'; // Import CustomPopup widget

/// ✅ 定義公開路由清單（不需登入即可進入的頁面）
/// ※ 若有使用 GoRouter routes 定義，也可從 app_router.dart 匯入統一來源
final Map<String, dynamic> publicRoutes = {};

/// ✅ 定義受保護路由清單（需登入與特定權限）
final Map<String, dynamic> protectedRoutes = {};

/// ✅ 檢查目前使用者是否具備進入某路由的權限
bool isAuthorized(BuildContext context, String? routeName) {
  if (routeName == null) return false;

  final userService = Provider.of<UserService>(context, listen: false);
  final currentUser = userService.currentUser;

  if (currentUser == null) return false; // 如果沒有登入使用者，返回 false

  final int requiredLevel = routePermissions[routeName] ?? 1;
  return (currentUser.permission_level ?? 0) >= requiredLevel;
}

/// ✅ 路由守衛，用於 GoRouter 中的 `builder` 呼叫
/// 根據目前使用者權限等級判斷要進入原本頁面、登入頁面、或封鎖頁面
Widget guardRoute(BuildContext context, GoRouterState state, Widget page) {
  final routeName = state.uri.path;
  final userService = Provider.of<UserService>(context, listen: false);
  final currentUser = userService.currentUser;

  // 公開頁面 → 直接進入
  if (publicRoutes.containsKey(routeName)) {
    return page;
  }

  // 受保護頁面
  if (protectedRoutes.containsKey(routeName)) {
    final int requiredLevel = routePermissions[routeName] ?? 1;

    // 權限足夠 → 進入目標頁
    if (currentUser != null && currentUser.permission_level >= requiredLevel) {
      return page;
    }

    // 被封鎖 → 顯示封鎖頁面
    if (currentUser != null && currentUser.permission_level == -2) {
      return const BannedPage();
    }

    // 權限不足或未登入 → 顯示彈出視窗並導向登入頁面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return CustomPopup(
            title: '未登入',
            content: '您尚未登入，請先登入以繼續使用。',
            onConfirm: () {
              Navigator.of(context).pop(); // 關閉彈窗
              context.go('/login'); // 導向登入頁面
            },
          );
        },
      );
    });

    return const SizedBox.shrink(); // 返回空白頁面，避免顯示不必要的內容
  }

  // 找不到的頁面 → Unknown page
  return const UnknownPage();
}
