import 'package:flutter/material.dart';
import 'package:here4help/services/auth_error_handler.dart';

/// Token 過期處理 Mixin
///
/// 為 StatefulWidget 提供便捷的 Token 過期處理方法
///
/// 使用方法：
/// ```dart
/// class MyPage extends StatefulWidget {
///   // ...
/// }
///
/// class _MyPageState extends State<MyPage> with TokenExpiryMixin {
///   void someApiCall() async {
///     try {
///       final result = await SomeApi.getData();
///       // 處理成功結果
///     } catch (e) {
///       if (handleIfTokenExpired(e)) return; // Token 過期已處理
///       // 處理其他錯誤
///     }
///   }
/// }
/// ```
mixin TokenExpiryMixin<T extends StatefulWidget> on State<T> {
  /// 檢查並處理 Token 過期錯誤
  ///
  /// [error] - 要檢查的錯誤對象
  /// [showDialog] - 是否顯示對話框（默認顯示 SnackBar）
  /// [customMessage] - 自定義錯誤消息
  ///
  /// 返回 true 表示錯誤已被處理（是 Token 過期錯誤）
  /// 返回 false 表示不是 Token 過期錯誤，需要調用者處理
  bool handleIfTokenExpired(
    dynamic error, {
    bool showDialog = false,
    String? customMessage,
  }) {
    if (!AuthErrorHandler.isTokenExpiredError(error)) {
      return false; // 不是 Token 過期錯誤
    }

    // 是 Token 過期錯誤，進行處理
    if (!mounted) return true;

    if (showDialog) {
      AuthErrorHandler.showTokenExpiredDialog(
        context,
        message: customMessage,
      );
    } else {
      AuthErrorHandler.showTokenExpiredNotification(
        context,
        message: customMessage,
      );
    }

    return true; // 錯誤已處理
  }

  /// 顯示 Token 過期 SnackBar
  ///
  /// 便捷方法，直接顯示 Token 過期通知
  void showTokenExpiredSnackBar([String? message]) {
    if (!mounted) return;
    AuthErrorHandler.showTokenExpiredNotification(context, message: message);
  }

  /// 顯示 Token 過期對話框
  ///
  /// 便捷方法，直接顯示 Token 過期對話框
  Future<void> showTokenExpiredDialog([String? message]) async {
    if (!mounted) return;
    return AuthErrorHandler.showTokenExpiredDialog(context, message: message);
  }

  /// 用於 API 調用的通用錯誤處理
  ///
  /// [apiCall] - 要執行的 API 調用
  /// [onSuccess] - 成功時的回調
  /// [onError] - 非 Token 過期錯誤的處理回調
  /// [showDialogOnExpiry] - Token 過期時是否顯示對話框
  /// [loadingMessage] - 加載時的提示消息
  ///
  /// 使用例子：
  /// ```dart
  /// await handleApiCall(
  ///   apiCall: () => UserApi.getProfile(),
  ///   onSuccess: (data) => setState(() => _userData = data),
  ///   onError: (error) => print('獲取用戶資料失敗: $error'),
  /// );
  /// ```
  Future<void> handleApiCall<TResult>({
    required Future<TResult> Function() apiCall,
    required void Function(TResult result) onSuccess,
    void Function(dynamic error)? onError,
    bool showDialogOnExpiry = false,
    String? loadingMessage,
  }) async {
    try {
      final result = await apiCall();
      if (mounted) {
        onSuccess(result);
      }
    } catch (error) {
      if (!mounted) return;

      // 檢查是否為 Token 過期
      if (handleIfTokenExpired(error, showDialog: showDialogOnExpiry)) {
        return; // Token 過期已處理
      }

      // 處理其他錯誤
      onError?.call(error);
    }
  }

  /// 安全的 API 調用，自動處理 Token 過期
  ///
  /// 返回 null 表示 Token 過期或其他錯誤
  /// 返回結果表示成功
  Future<TResult?> safeApiCall<TResult>(
    Future<TResult> Function() apiCall, {
    bool showDialogOnExpiry = false,
    bool logErrors = true,
  }) async {
    try {
      return await apiCall();
    } catch (error) {
      if (!mounted) return null;

      // 處理 Token 過期
      if (handleIfTokenExpired(error, showDialog: showDialogOnExpiry)) {
        return null;
      }

      // 記錄其他錯誤
      if (logErrors) {
        debugPrint('🚨 [TokenExpiryMixin] API 調用失敗: $error');
      }

      return null;
    }
  }
}
