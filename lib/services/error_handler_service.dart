import 'package:flutter/foundation.dart';

/// 統一的錯誤處理服務
/// 將技術性錯誤訊息轉換為使用者友善的訊息
class ErrorHandlerService {
  /// 將 API 錯誤轉換為使用者友善的訊息
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // 網路相關錯誤
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return '網路連線異常，請檢查您的網路設定';
    }

    // HTTP 狀態碼錯誤
    if (errorString.contains('404')) {
      return '請求的資源不存在，請稍後再試';
    }

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return '登入已過期，請重新登入';
    }

    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return '您沒有權限執行此操作';
    }

    if (errorString.contains('500') ||
        errorString.contains('internal server')) {
      return '伺服器暫時無法處理請求，請稍後再試';
    }

    if (errorString.contains('502') || errorString.contains('bad gateway')) {
      return '伺服器連線異常，請稍後再試';
    }

    if (errorString.contains('503') ||
        errorString.contains('service unavailable')) {
      return '服務暫時無法使用，請稍後再試';
    }

    // 任務相關錯誤
    if (errorString.contains('task not found')) {
      return '找不到指定的任務';
    }

    if (errorString.contains('already rated') ||
        errorString.contains('already been rated')) {
      return '您已經對此任務進行過評分';
    }

    if (errorString.contains('already been assigned') ||
        errorString.contains('already assigned')) {
      return '此任務已經指派給其他人';
    }

    if (errorString.contains('already has an assigned tasker')) {
      return '此任務已經有執行者，無法再接受其他申請';
    }

    if (errorString.contains('must be in open status')) {
      return '只有開放中的任務才能接受申請';
    }

    if (errorString.contains('only task creator can accept')) {
      return '只有任務發布者才能接受申請';
    }

    // 驗證錯誤
    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return '輸入的資料格式不正確，請檢查後重試';
    }

    // JSON 解析錯誤
    if (errorString.contains('json') || errorString.contains('format')) {
      return '資料格式錯誤，請稍後再試';
    }

    // 權限錯誤
    if (errorString.contains('permission')) {
      return '您沒有執行此操作的權限';
    }

    // 檔案上傳錯誤
    if (errorString.contains('upload') || errorString.contains('file')) {
      return '檔案上傳失敗，請檢查檔案格式和大小';
    }

    // 資料庫錯誤
    if (errorString.contains('database') || errorString.contains('sql')) {
      return '資料處理異常，請稍後再試';
    }

    // 預設錯誤訊息
    return '操作失敗，請稍後再試';
  }

  /// 記錄錯誤到控制台（僅在 debug 模式）
  static void logError(String context, dynamic error,
      [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [$context] Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// 獲取特定操作的錯誤訊息
  static String getOperationErrorMessage(String operation, dynamic error) {
    final baseMessage = getUserFriendlyMessage(error);

    switch (operation.toLowerCase()) {
      case 'login':
        return 'Login failed: $baseMessage';
      case 'register':
        return 'Registration failed: $baseMessage';
      case 'load_tasks':
        return 'Failed to load tasks: $baseMessage';
      case 'create_task':
        return 'Failed to create task: $baseMessage';
      case 'update_task':
        return 'Failed to update task: $baseMessage';
      case 'delete_task':
        return 'Failed to delete task: $baseMessage';
      case 'accept_application':
        // Specific error handling for accepting application
        if (error.toString().contains('already been assigned')) {
          return 'This user has already been assigned as the tasker for this task';
        } else if (error
            .toString()
            .contains('already has an assigned tasker')) {
          return 'This task already has a tasker and cannot accept more applications';
        } else if (error.toString().contains('must be in open status')) {
          return 'Only tasks that are open can accept applications';
        } else if (error.toString().contains('Only task creator can accept')) {
          return 'Only the task creator can accept applications';
        }
        return 'Failed to accept application: $baseMessage';
      case 'submit_rating':
        return 'Failed to submit rating: $baseMessage';
      case 'upload_file':
        return 'File upload failed: $baseMessage';
      case 'send_message':
        return 'Failed to send message: $baseMessage';
      case 'block_user':
        return 'Failed to block user: $baseMessage';
      default:
        return baseMessage;
    }
  }

  /// 檢查是否為需要重新登入的錯誤
  static bool isAuthError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('401') ||
        errorString.contains('unauthorized') ||
        errorString.contains('token') ||
        errorString.contains('expired');
  }

  /// 檢查是否為網路錯誤
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket');
  }
}
