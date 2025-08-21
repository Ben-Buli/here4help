import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/permission_service.dart';
import 'package:here4help/providers/permission_provider.dart';
import 'package:here4help/constants/shell_pages.dart';
import 'package:here4help/system/pages/permission_denied_page.dart';

/// 統一權限守衛
/// 整合現有的權限系統，提供路由級和元件級權限控制
class PermissionGuard {
  /// 檢查路由權限
  static bool canAccessRoute(BuildContext context, String path) {
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    final userPermission = permissionProvider.permission;

    // 從 shell_pages 中查找頁面權限要求
    final pageConfig = shellPages.firstWhere(
      (page) => page['path'] == path,
      orElse: () => {'permission': 1}, // 預設需要已認證用戶
    );

    final requiredPermission = pageConfig['permission'] as int? ?? 1;

    return PermissionService.canAccessPage(userPermission, requiredPermission);
  }

  /// 檢查功能權限
  static bool canUseFeature(BuildContext context, String feature) {
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    final userPermission = permissionProvider.permission;

    return PermissionService.canUseFeature(userPermission, feature);
  }

  /// 路由守衛中介層
  static Widget guardRoute(
      BuildContext context, GoRouterState state, Widget page) {
    final path = state.uri.path;

    // 檢查權限
    if (!canAccessRoute(context, path)) {
      final permissionProvider =
          Provider.of<PermissionProvider>(context, listen: false);
      final userPermission = permissionProvider.permission;

      // 根據用戶狀態返回不同的處理
      if (userPermission <= -2) {
        // 帳號已刪除，導向登入頁
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/login');
        });
        return const SizedBox.shrink();
      }

      if (userPermission == -1 || userPermission == -3) {
        // 帳號被停權，顯示權限拒絕頁面
        return PermissionDeniedPage(
          message: PermissionService.getPermissionStatus(userPermission),
          currentPath: path,
        );
      }

      if (userPermission == 0) {
        // 未認證用戶，顯示提示對話框
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showVerificationRequiredDialog(context, path);
        });
        return const SizedBox.shrink();
      }

      // 其他權限不足情況
      return PermissionDeniedPage(
        message: 'You do not have permission to access this page.',
        currentPath: path,
      );
    }

    return page;
  }

  /// 顯示需要驗證的對話框
  static void _showVerificationRequiredDialog(
      BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Account Verification Required'),
          content: const Text(
              'Please complete your account verification to access this feature.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/home'); // 返回首頁
              },
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/signup/student-id'); // 導向身份驗證頁面
              },
              child: const Text('Verify Now'),
            ),
          ],
        );
      },
    );
  }

  /// 檢查並處理功能權限（用於元件級控制）
  static bool checkFeaturePermission(
    BuildContext context,
    String feature, {
    bool showDialog = true,
    VoidCallback? onPermissionDenied,
  }) {
    if (canUseFeature(context, feature)) {
      return true;
    }

    if (showDialog) {
      final permissionProvider =
          Provider.of<PermissionProvider>(context, listen: false);
      final userPermission = permissionProvider.permission;

      _showPermissionDeniedDialog(
        context,
        feature,
        userPermission,
        onPermissionDenied,
      );
    } else if (onPermissionDenied != null) {
      onPermissionDenied();
    }

    return false;
  }

  /// 顯示權限拒絕對話框
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String feature,
    int userPermission,
    VoidCallback? onPermissionDenied,
  ) {
    String title = 'Permission Required';
    String content = PermissionService.getFeaturePermissionDescription(feature);
    String? actionText;
    VoidCallback? actionCallback;

    if (userPermission == 0) {
      title = 'Account Verification Required';
      content =
          'Please complete your account verification to use this feature.';
      actionText = 'Verify Now';
      actionCallback = () {
        Navigator.of(context).pop();
        context.go('/signup/student-id');
      };
    } else if (userPermission == -1) {
      title = 'Account Suspended';
      content =
          'Your account has been suspended by an administrator. Please contact customer service.';
      actionText = 'Contact Support';
      actionCallback = () {
        Navigator.of(context).pop();
        context.go('/account/support/contact');
      };
    } else if (userPermission == -3) {
      title = 'Account Deactivated';
      content =
          'Your account is currently deactivated. You can reactivate it in security settings.';
      actionText = 'Reactivate';
      actionCallback = () {
        Navigator.of(context).pop();
        context.go('/account/security');
      };
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (actionCallback != null)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (onPermissionDenied != null) onPermissionDenied();
                },
                child: const Text('Cancel'),
              ),
            TextButton(
              onPressed: actionCallback ??
                  () {
                    Navigator.of(dialogContext).pop();
                    if (onPermissionDenied != null) onPermissionDenied();
                  },
              child: Text(actionText ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  /// 獲取頁面權限要求
  static int getPagePermissionRequirement(String path) {
    final pageConfig = shellPages.firstWhere(
      (page) => page['path'] == path,
      orElse: () => {'permission': 1},
    );

    return pageConfig['permission'] as int? ?? 1;
  }

  /// 獲取用戶權限狀態描述
  static String getUserPermissionStatus(BuildContext context) {
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    return PermissionService.getPermissionStatus(permissionProvider.permission);
  }

  /// 檢查是否需要顯示權限提示
  static bool shouldShowPermissionHint(BuildContext context, String feature) {
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    final userPermission = permissionProvider.permission;

    // 如果用戶權限不足且不是被刪除的帳號，顯示提示
    return !PermissionService.canUseFeature(userPermission, feature) &&
        userPermission > -2;
  }

  /// 獲取權限提示訊息
  static String getPermissionHint(BuildContext context, String feature) {
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    final userPermission = permissionProvider.permission;

    if (userPermission == 0) {
      return 'Complete account verification to unlock this feature';
    } else if (userPermission == -1) {
      return 'Account suspended - contact support';
    } else if (userPermission == -3) {
      return 'Account deactivated - reactivate in settings';
    } else {
      return PermissionService.getFeaturePermissionDescription(feature);
    }
  }
}
