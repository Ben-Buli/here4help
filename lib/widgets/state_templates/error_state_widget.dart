import 'package:flutter/material.dart';
import '../accessibility/accessible_text.dart';
import '../../services/accessibility/semantics_service.dart';

/// 錯誤狀態組件
/// 提供統一的錯誤狀態 UI 模板
class ErrorStateWidget extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String? description;
  final String? errorCode;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Color? iconColor;
  final double? iconSize;

  const ErrorStateWidget({
    Key? key,
    this.icon,
    this.iconAsset,
    required this.title,
    this.description,
    this.errorCode,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor,
    this.iconSize = 80.0,
  }) : super(key: key);

  /// 預設的錯誤狀態樣式
  static ErrorStateWidget networkError({VoidCallback? onRetry}) {
    return ErrorStateWidget(
      icon: Icons.wifi_off,
      title: '網路連線錯誤',
      description: '請檢查網路連線狀態',
      actionLabel: '重試',
      onAction: onRetry,
    );
  }

  static ErrorStateWidget serverError({VoidCallback? onRetry}) {
    return ErrorStateWidget(
      icon: Icons.error_outline,
      title: '伺服器錯誤',
      description: '伺服器暫時無法回應，請稍後再試',
      actionLabel: '重試',
      onAction: onRetry,
    );
  }

  static ErrorStateWidget notFound({VoidCallback? onGoBack}) {
    return ErrorStateWidget(
      icon: Icons.search_off,
      title: '找不到內容',
      description: '您要查看的內容不存在或已被移除',
      actionLabel: '返回',
      onAction: onGoBack,
    );
  }

  static ErrorStateWidget unauthorized({VoidCallback? onLogin}) {
    return ErrorStateWidget(
      icon: Icons.lock_outline,
      title: '需要登入',
      description: '請登入後再試',
      actionLabel: '登入',
      onAction: onLogin,
    );
  }

  static ErrorStateWidget forbidden({VoidCallback? onGoBack}) {
    return ErrorStateWidget(
      icon: Icons.block,
      title: '權限不足',
      description: '您沒有權限訪問此內容',
      actionLabel: '返回',
      onAction: onGoBack,
    );
  }

  static ErrorStateWidget loadFailed({
    required String content,
    VoidCallback? onRetry,
  }) {
    return ErrorStateWidget(
      icon: Icons.refresh,
      title: '載入失敗',
      description: '無法載入$content，請重試',
      actionLabel: '重試',
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticsService = SemanticsService.instance;

    String errorMessage = title;
    if (description != null) errorMessage += '. $description';
    if (errorCode != null) errorMessage += '. 錯誤代碼: $errorCode';

    return semanticsService.annotateErrorState(
      errorMessage: errorMessage,
      onRetry: onAction,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 圖示
              _buildIcon(theme),
              const SizedBox(height: 24),
              
              // 標題
              AccessibleHeading(
                title,
                level: 2,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              // 描述
              if (description != null) ...[
                const SizedBox(height: 12),
                AccessibleText(
                  description!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              // 錯誤代碼
              if (errorCode != null) ...[
                const SizedBox(height: 8),
                AccessibleText(
                  '錯誤代碼: $errorCode',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              // 動作按鈕
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: AccessibleText(
                    actionLabel!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
              
              // 次要動作按鈕
              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: AccessibleText(
                    secondaryActionLabel!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    final color = iconColor ?? theme.colorScheme.error.withOpacity(0.7);
    
    if (iconAsset != null) {
      return Image.asset(
        iconAsset!,
        width: iconSize,
        height: iconSize,
        color: color,
      );
    } else if (icon != null) {
      return Icon(
        icon,
        size: iconSize,
        color: color,
      );
    } else {
      return Icon(
        Icons.error_outline,
        size: iconSize,
        color: color,
      );
    }
  }
}

/// 錯誤狀態建構器
class ErrorStateBuilder {
  /// 根據 HTTP 狀態碼建構錯誤狀態
  static Widget buildFromStatusCode(
    int statusCode, {
    String? message,
    VoidCallback? onRetry,
    VoidCallback? onGoBack,
  }) {
    switch (statusCode) {
      case 400:
        return ErrorStateWidget(
          icon: Icons.warning,
          title: '請求錯誤',
          description: message ?? '請求格式不正確',
          errorCode: '400',
          actionLabel: '返回',
          onAction: onGoBack,
        );
      case 401:
        return ErrorStateWidget.unauthorized(onLogin: onRetry);
      case 403:
        return ErrorStateWidget.forbidden(onGoBack: onGoBack);
      case 404:
        return ErrorStateWidget.notFound(onGoBack: onGoBack);
      case 500:
        return ErrorStateWidget.serverError(onRetry: onRetry);
      default:
        return ErrorStateWidget(
          icon: Icons.error,
          title: '發生錯誤',
          description: message ?? '未知錯誤',
          errorCode: statusCode.toString(),
          actionLabel: '重試',
          onAction: onRetry,
          secondaryActionLabel: '返回',
          onSecondaryAction: onGoBack,
        );
    }
  }

  /// 根據異常類型建構錯誤狀態
  static Widget buildFromException(
    Exception exception, {
    VoidCallback? onRetry,
  }) {
    if (exception.toString().contains('SocketException')) {
      return ErrorStateWidget.networkError(onRetry: onRetry);
    } else if (exception.toString().contains('TimeoutException')) {
      return ErrorStateWidget(
        icon: Icons.access_time,
        title: '請求超時',
        description: '網路回應時間過長，請重試',
        actionLabel: '重試',
        onAction: onRetry,
      );
    } else {
      return ErrorStateWidget(
        icon: Icons.bug_report,
        title: '應用程式錯誤',
        description: exception.toString(),
        actionLabel: '重試',
        onAction: onRetry,
      );
    }
  }
}
