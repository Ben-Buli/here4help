import 'package:flutter/material.dart';
import 'package:here4help/services/error_handler_service.dart';

/// 統一的錯誤顯示 Widget
/// 提供一致的錯誤 UI 體驗
class ErrorDisplayWidget extends StatelessWidget {
  final dynamic error;
  final String? context;
  final VoidCallback? onRetry;
  final bool showRetryButton;
  final IconData? icon;
  final Color? backgroundColor;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.context,
    this.onRetry,
    this.showRetryButton = true,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorMessage = ErrorHandlerService.getUserFriendlyMessage(error);
    final isNetworkError = ErrorHandlerService.isNetworkError(error);
    final isAuthError = ErrorHandlerService.isAuthError(error);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ??
            theme.colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 錯誤圖示
          Icon(
            icon ?? _getErrorIcon(isNetworkError, isAuthError),
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),

          // 錯誤訊息
          Text(
            errorMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),

          // 重試按鈕
          if (showRetryButton && onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(_getRetryButtonText(isNetworkError, isAuthError)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getErrorIcon(bool isNetworkError, bool isAuthError) {
    if (isNetworkError) {
      return Icons.wifi_off;
    } else if (isAuthError) {
      return Icons.lock_outline;
    } else {
      return Icons.error_outline;
    }
  }

  String _getRetryButtonText(bool isNetworkError, bool isAuthError) {
    if (isNetworkError) {
      return '重新連線';
    } else if (isAuthError) {
      return '重新登入';
    } else {
      return '重試';
    }
  }
}

/// 錯誤 SnackBar 輔助方法
class ErrorSnackBar {
  /// 顯示使用者友善的錯誤 SnackBar
  static void show(
    BuildContext context,
    dynamic error, {
    String? operation,
    Duration duration = const Duration(seconds: 4),
  }) {
    final errorMessage = operation != null
        ? ErrorHandlerService.getOperationErrorMessage(operation, error)
        : ErrorHandlerService.getUserFriendlyMessage(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 顯示成功 SnackBar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 顯示警告 SnackBar
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
