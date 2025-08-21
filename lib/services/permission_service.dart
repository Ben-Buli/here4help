import 'package:flutter/material.dart';

/// 權限檢查服務
/// 提供統一的權限驗證邏輯和權限狀態查詢功能
class PermissionService {
  // 權限值定義
  static const int NEW_USER = 0;
  static const int VERIFIED_USER = 1;
  static const int ADMIN = 99;
  static const int SUSPENDED_BY_ADMIN = -1;
  static const int SOFT_DELETED_BY_ADMIN = -2;
  static const int SELF_SUSPENDED = -3;
  static const int SELF_SOFT_DELETED = -4;

  /// 檢查是否可以訪問聊天功能
  static bool canAccessChat(int permission) {
    return permission >= VERIFIED_USER;
  }

  /// 檢查是否可以創建任務
  static bool canCreateTask(int permission) {
    return permission >= VERIFIED_USER;
  }

  /// 檢查是否可以應徵任務
  static bool canApplyTask(int permission) {
    return permission >= VERIFIED_USER;
  }

  /// 檢查是否可以訪問任務詳情
  static bool canViewTaskDetail(int permission) {
    return permission >= VERIFIED_USER;
  }

  /// 檢查是否可以編輯個人資料
  static bool canEditProfile(int permission) {
    return permission >= NEW_USER;
  }

  /// 檢查是否可以訪問錢包功能
  static bool canAccessWallet(int permission) {
    return permission >= VERIFIED_USER;
  }

  /// 檢查是否可以進行支付
  static bool canMakePayment(int permission) {
    return permission >= VERIFIED_USER;
  }

  /// 檢查是否可以訪問管理功能
  static bool canAccessAdmin(int permission) {
    return permission == ADMIN;
  }

  /// 檢查帳號是否有效（可以登入）
  static bool isAccountValid(int permission) {
    return permission >= SELF_SOFT_DELETED;
  }

  /// 檢查帳號是否被停權
  static bool isAccountSuspended(int permission) {
    return permission == SUSPENDED_BY_ADMIN || permission == SELF_SUSPENDED;
  }

  /// 檢查帳號是否被刪除
  static bool isAccountDeleted(int permission) {
    return permission == SOFT_DELETED_BY_ADMIN ||
        permission == SELF_SOFT_DELETED;
  }

  /// 檢查是否需要驗證
  static bool needsVerification(int permission) {
    return permission == NEW_USER;
  }

  /// 獲取權限狀態描述
  static String getPermissionStatus(int permission) {
    switch (permission) {
      case NEW_USER:
        return 'Account verification required';
      case VERIFIED_USER:
        return 'Account verified';
      case ADMIN:
        return 'Administrator';
      case SUSPENDED_BY_ADMIN:
        return 'Account suspended by administrator';
      case SOFT_DELETED_BY_ADMIN:
        return 'Account removed by administrator';
      case SELF_SUSPENDED:
        return 'Account self-suspended';
      case SELF_SOFT_DELETED:
        return 'Account self-removed';
      default:
        return 'Unknown permission status';
    }
  }

  /// 獲取權限限制說明
  static String getPermissionRestrictions(int permission) {
    if (permission < VERIFIED_USER) {
      return 'You need to verify your account to access all features';
    }
    return 'No restrictions';
  }

  /// 檢查頁面訪問權限
  static bool canAccessPage(int permission, int requiredPermission) {
    return permission >= requiredPermission;
  }

  /// 獲取頁面權限要求描述
  static String getPagePermissionDescription(int requiredPermission) {
    switch (requiredPermission) {
      case NEW_USER:
        return 'Available to all users';
      case VERIFIED_USER:
        return 'Requires account verification';
      case ADMIN:
        return 'Administrator only';
      default:
        return 'Permission level: $requiredPermission';
    }
  }

  /// 檢查功能權限
  static bool canUseFeature(int permission, String feature) {
    switch (feature) {
      case 'chat':
        return canAccessChat(permission);
      case 'task_create':
        return canCreateTask(permission);
      case 'task_apply':
        return canApplyTask(permission);
      case 'wallet':
        return canAccessWallet(permission);
      case 'payment':
        return canMakePayment(permission);
      case 'admin':
        return canAccessAdmin(permission);
      default:
        return true; // 預設允許訪問
    }
  }

  /// 獲取功能權限說明
  static String getFeaturePermissionDescription(String feature) {
    switch (feature) {
      case 'chat':
        return 'Chat features require account verification';
      case 'task_create':
        return 'Creating tasks requires account verification';
      case 'task_apply':
        return 'Applying to tasks requires account verification';
      case 'wallet':
        return 'Wallet features require account verification';
      case 'payment':
        return 'Payment features require account verification';
      case 'admin':
        return 'Administrator access required';
      default:
        return 'No special permissions required';
    }
  }
}
