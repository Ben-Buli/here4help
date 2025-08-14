import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 錯誤處理服務
class ErrorHandlerService {
  static const String _errorLogKey = 'error_log';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// 顯示用戶友好的錯誤信息
  static void showError(BuildContext context, String message, {String? title}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '關閉',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 顯示成功信息
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 顯示警告信息
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 顯示加載中信息
  static void showLoading(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 10),
      ),
    );
  }

  /// 隱藏當前的 SnackBar
  static void hideCurrent(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// 記錄錯誤到本地存儲
  static Future<void> logError(String error, {String? context}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      final errorLog = prefs.getStringList(_errorLogKey) ?? [];

      errorLog.add('[$now] ${context ?? 'Unknown'}: $error');

      // 只保留最近 100 條錯誤記錄
      if (errorLog.length > 100) {
        errorLog.removeRange(0, errorLog.length - 100);
      }

      await prefs.setStringList(_errorLogKey, errorLog);
    } catch (e) {
      // 忽略記錄錯誤時的錯誤
    }
  }

  /// 獲取錯誤日誌
  static Future<List<String>> getErrorLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_errorLogKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 清除錯誤日誌
  static Future<void> clearErrorLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_errorLogKey);
    } catch (e) {
      // 忽略清除錯誤時的錯誤
    }
  }

  /// 帶重試機制的函數執行器
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = _maxRetries,
    Duration retryDelay = _retryDelay,
    String? operationName,
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        lastException = e is Exception ? e : Exception(e.toString());

        // 檢查是否應該重試
        if (shouldRetry != null && !shouldRetry(lastException)) {
          break;
        }

        // 記錄錯誤
        await logError(
          'Attempt $attempts failed: ${lastException.toString()}',
          context: operationName ?? 'RetryOperation',
        );

        // 如果還有重試機會，等待後重試
        if (attempts < maxRetries) {
          await Future.delayed(retryDelay * attempts); // 指數退避
        }
      }
    }

    // 所有重試都失敗了
    throw Exception(
      'Operation failed after $maxRetries attempts. Last error: ${lastException?.toString()}',
    );
  }

  /// 檢查網絡錯誤
  static bool isNetworkError(Exception error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('socket');
  }

  /// 檢查服務器錯誤
  static bool isServerError(Exception error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504');
  }

  /// 檢查認證錯誤
  static bool isAuthError(Exception error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden');
  }

  /// 獲取用戶友好的錯誤信息
  static String getUserFriendlyMessage(Exception error) {
    if (isNetworkError(error)) {
      return '網絡連接失敗，請檢查網絡設置後重試';
    } else if (isServerError(error)) {
      return '服務器暫時無法響應，請稍後重試';
    } else if (isAuthError(error)) {
      return '登錄已過期，請重新登錄';
    } else {
      return '操作失敗，請重試';
    }
  }
}
