import 'package:flutter/material.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/router/app_router.dart';
import 'package:here4help/services/notification_service.dart';

/// 全局 Auth 錯誤處理服務
///
/// 負責統一處理身份認證相關的錯誤，包括：
/// - Token 過期處理
/// - 自動登出流程
/// - 用戶友好的錯誤提示
/// - 清理用戶數據和狀態
class AuthErrorHandler {
  static bool _isHandlingExpiry = false;
  static DateTime? _lastExpiryTime;

  /// Token 過期處理的冷卻時間（避免重複處理）
  static const Duration _expiryCooldown = Duration(seconds: 5);

  /// 處理 Token 過期情況
  ///
  /// 執行完整的登出流程：
  /// 1. 清理本地用戶數據
  /// 2. 斷開相關服務連接
  /// 3. 跳轉到登入頁面
  /// 4. 顯示用戶友好的提示
  static Future<void> handleTokenExpiry({String? reason}) async {
    // 防重複處理機制
    final now = DateTime.now();
    if (_isHandlingExpiry) {
      debugPrint('🔄 [AuthErrorHandler] Token 過期處理進行中，跳過重複調用');
      return;
    }

    if (_lastExpiryTime != null &&
        now.difference(_lastExpiryTime!) < _expiryCooldown) {
      debugPrint('🔄 [AuthErrorHandler] 冷卻期內，跳過 Token 過期處理');
      return;
    }

    _isHandlingExpiry = true;
    _lastExpiryTime = now;

    try {
      debugPrint('🚨 [AuthErrorHandler] Token 過期，開始完整登出流程');
      if (reason != null) {
        debugPrint('🔍 [AuthErrorHandler] 過期原因: $reason');
      }

      // 1. 清理 Socket 和通知服務
      try {
        final notificationCenter = NotificationCenter();
        await notificationCenter.dispose();
        debugPrint('✅ [AuthErrorHandler] 通知服務已清理');
      } catch (e) {
        debugPrint('⚠️ [AuthErrorHandler] 清理通知服務失敗: $e');
      }

      // 2. 執行標準登出流程
      await AuthService.logout();
      debugPrint('✅ [AuthErrorHandler] 用戶數據已清理');

      // 3. 延遲一點時間確保狀態清理完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 4. 跳轉到登入頁面
      try {
        appRouter.go('/login');
        debugPrint('✅ [AuthErrorHandler] 已跳轉到登入頁面');

        // 5. 延遲顯示用戶友好提示（確保頁面已載入）
        Future.delayed(const Duration(milliseconds: 500), () {
          _showTokenExpiredToast();
        });
      } catch (routerError) {
        debugPrint('❌ [AuthErrorHandler] 路由跳轉失敗: $routerError');
        // 嘗試備用跳轉方法
        try {
          appRouter.pushReplacement('/login');
          debugPrint('✅ [AuthErrorHandler] 使用備用方法跳轉成功');

          // 備用方法也要顯示提示
          Future.delayed(const Duration(milliseconds: 500), () {
            _showTokenExpiredToast();
          });
        } catch (e) {
          debugPrint('❌ [AuthErrorHandler] 備用跳轉也失敗: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ [AuthErrorHandler] Token 過期處理失敗: $e');
    } finally {
      // 延遲重置標記，避免立即重複觸發
      Future.delayed(const Duration(seconds: 1), () {
        _isHandlingExpiry = false;
      });
    }
  }

  /// 顯示 Token 過期通知
  ///
  /// 在有可用 BuildContext 時顯示用戶友好的提示
  static void showTokenExpiredNotification(BuildContext context,
      {String? message}) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Session expired, please log in again'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Go to Login',
            textColor: Colors.white,
            onPressed: () {
              appRouter.go('/login');
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [AuthErrorHandler] 顯示通知失敗: $e');
    }
  }

  /// 顯示 Token 過期對話框
  ///
  /// 更明顯的過期提示，適用於重要操作被中斷的場景
  static Future<void> showTokenExpiredDialog(BuildContext context,
      {String? message}) async {
    if (!context.mounted) return;

    try {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('登入過期'),
            content: Text(message ??
                'Your session has expired. Please log in again to continue.'),
            actions: <Widget>[
              TextButton(
                child: const Text('重新登入'),
                onPressed: () {
                  Navigator.of(context).pop();
                  appRouter.go('/login');
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('⚠️ [AuthErrorHandler] 顯示對話框失敗: $e');
    }
  }

  /// 檢查錯誤是否為 Token 過期相關
  ///
  /// 用於統一判斷各種 Token 過期的錯誤格式
  static bool isTokenExpiredError(dynamic error) {
    if (error == null) return false;

    final errorString = error.toString().toLowerCase();

    // 檢查常見的 Token 過期錯誤消息
    final expiredKeywords = [
      'expired',
      'invalid',
      'unauthorized',
      'token',
      'authentication',
      'login',
      '401',
    ];

    for (final keyword in expiredKeywords) {
      if (errorString.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// 顯示 Token 過期的全局提示（不依賴 BuildContext）
  static void _showTokenExpiredToast() {
    try {
      // 使用全局的 ScaffoldMessenger 顯示提示
      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Session expired, please log in again',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Go to Login',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        debugPrint('✅ [AuthErrorHandler] Token 過期提示已顯示');
      } else {
        debugPrint('⚠️ [AuthErrorHandler] 無法獲取 Context，跳過提示顯示');
      }
    } catch (e) {
      debugPrint('⚠️ [AuthErrorHandler] 顯示 Token 過期提示失敗: $e');
    }
  }

  /// 重置處理狀態（用於測試或特殊情況）
  static void resetState() {
    _isHandlingExpiry = false;
    _lastExpiryTime = null;
    debugPrint('🔄 [AuthErrorHandler] 狀態已重置');
  }
}
