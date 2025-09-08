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
      return 'Network connection error, please check your network settings';
    }

    // HTTP 狀態碼錯誤
    if (errorString.contains('404')) {
      return 'The requested resource does not exist, please try again later';
    }

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Login expired, please log in again';
    }

    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'You do not have permission to perform this action';
    }

    if (errorString.contains('500') ||
        errorString.contains('internal server')) {
      return 'The server is temporarily unable to process the request, please try again later';
    }

    if (errorString.contains('502') || errorString.contains('bad gateway')) {
      return 'Server connection error, please try again later';
    }

    if (errorString.contains('503') ||
        errorString.contains('service unavailable')) {
      return 'Service is temporarily unavailable, please try again later';
    }

    // 任務相關錯誤
    if (errorString.contains('task not found')) {
      return 'The specified task could not be found';
    }

    if (errorString.contains('already rated') ||
        errorString.contains('already been rated')) {
      return 'You have already rated this task';
    }

    if (errorString.contains('already been assigned') ||
        errorString.contains('already assigned')) {
      return 'This task has already been assigned to someone else';
    }

    if (errorString.contains('already has an assigned tasker')) {
      return 'This task already has a tasker and cannot accept more applications';
    }

    if (errorString.contains('must be in open status')) {
      return 'Only open tasks can accept applications';
    }

    if (errorString.contains('only task creator can accept') ||
        errorString.contains('only task creator can reject')) {
      return 'Only the task creator can perform this action';
    }

    if (errorString.contains('application not found')) {
      return 'The application could not be found';
    }

    if (errorString.contains('application is not in applied status')) {
      return 'This application cannot be processed in its current status';
    }

    // 數據庫約束錯誤
    if (errorString.contains('duplicate entry') &&
        errorString.contains('uk_task_one_accept')) {
      return 'This task already has an accepted applicant';
    }

    if (errorString.contains('integrity constraint violation')) {
      return 'This operation cannot be completed due to data conflicts';
    }

    // 驗證錯誤
    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return 'The data format you entered is incorrect, please check and try again';
    }

    // JSON 解析錯誤
    if (errorString.contains('json') || errorString.contains('format')) {
      return 'Data format error, please try again later';
    }

    // 權限錯誤
    if (errorString.contains('permission')) {
      return 'You do not have permission to perform this action';
    }

    // 檔案上傳錯誤
    if (errorString.contains('upload') || errorString.contains('file')) {
      return 'File upload failed, please check the file format and size';
    }

    // 資料庫錯誤
    if (errorString.contains('database') || errorString.contains('sql')) {
      return 'Data processing error, please try again later';
    }

    // 預設錯誤訊息
    return 'Operation failed, please try again later';
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
          return 'This task is no longer available for applications. It may have been assigned to another tasker.';
        } else if (error.toString().contains('Only task creator can accept')) {
          return 'Only the task creator can accept applications';
        } else if (error.toString().contains('duplicate entry') &&
            error.toString().contains('uk_task_one_accept')) {
          return 'This applicant has already been accepted for this task';
        } else if (error
            .toString()
            .contains('integrity constraint violation')) {
          return 'Cannot accept this application due to existing task assignments';
        }
        return 'Failed to accept application: $baseMessage';
      case 'reject_application':
        if (error.toString().contains('Only task creator can reject')) {
          return 'Only the task creator can reject applications';
        } else if (error.toString().contains('application not found')) {
          return 'The application could not be found';
        } else if (error.toString().contains('not in applied status')) {
          return 'This application cannot be rejected in its current status';
        }
        return 'Failed to reject application: $baseMessage';
      case 'withdraw_application':
        if (error.toString().contains('application not found')) {
          return 'The application could not be found';
        } else if (error.toString().contains('cannot withdraw')) {
          return 'This application cannot be withdrawn at this time';
        }
        return 'Failed to withdraw application: $baseMessage';
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
