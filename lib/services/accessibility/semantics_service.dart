import 'package:flutter/material.dart';

/// 語義標註服務
/// 提供統一的無障礙語義標註和鍵盤操作支援
class SemanticsService {
  static SemanticsService? _instance;
  static SemanticsService get instance => _instance ??= SemanticsService._();

  SemanticsService._();

  /// 為任務卡片提供語義標註
  Widget annotateTaskCard({
    required Widget child,
    required String taskTitle,
    required String taskDescription,
    required String status,
    required String reward,
    VoidCallback? onTap,
  }) {
    final semanticsLabel =
        '任務: $taskTitle. 描述: $taskDescription. 狀態: $status. 獎勵: $reward 點數';

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      enabled: onTap != null,
      onTap: onTap,
      child: child,
    );
  }

  /// 為聊天訊息提供語義標註
  Widget annotateChatMessage({
    required Widget child,
    required String senderName,
    required String message,
    required DateTime timestamp,
    required bool isOwn,
  }) {
    final timeString = _formatTime(timestamp);
    final semanticsLabel = isOwn
        ? '您在 $timeString 發送: $message'
        : '$senderName 在 $timeString 發送: $message';

    return Semantics(
      label: semanticsLabel,
      liveRegion: true,
      child: child,
    );
  }

  /// 為表單欄位提供語義標註
  Widget annotateFormField({
    required Widget child,
    required String label,
    String? hint,
    String? error,
    bool required = false,
  }) {
    String semanticsLabel = label;
    if (required) semanticsLabel += ', 必填';
    if (hint != null) semanticsLabel += ', 提示: $hint';
    if (error != null) semanticsLabel += ', 錯誤: $error';

    return Semantics(
      label: semanticsLabel,
      textField: true,
      child: child,
    );
  }

  /// 為導航項目提供語義標註
  Widget annotateNavigationItem({
    required Widget child,
    required String label,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final semanticsLabel = isSelected ? '$label, 已選取' : label;

    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: isSelected,
      onTap: onTap,
      child: child,
    );
  }

  /// 為狀態指示器提供語義標註
  Widget annotateStatusIndicator({
    required Widget child,
    required String status,
    String? description,
  }) {
    String semanticsLabel = '狀態: $status';
    if (description != null) semanticsLabel += ', $description';

    return Semantics(
      label: semanticsLabel,
      liveRegion: true,
      child: child,
    );
  }

  /// 為計數器提供語義標註
  Widget annotateCounter({
    required Widget child,
    required int count,
    required String itemName,
  }) {
    final semanticsLabel = count == 0
        ? '沒有$itemName'
        : count == 1
            ? '1個$itemName'
            : '$count個$itemName';

    return Semantics(
      label: semanticsLabel,
      liveRegion: true,
      child: child,
    );
  }

  /// 為評分組件提供語義標註
  Widget annotateRating({
    required Widget child,
    required double rating,
    required double maxRating,
    bool interactive = false,
  }) {
    final semanticsLabel = '評分 $rating 分，滿分 $maxRating 分';

    return Semantics(
      label: semanticsLabel,
      slider: interactive,
      value: rating.toString(),
      child: child,
    );
  }

  /// 為載入狀態提供語義標註
  Widget annotateLoadingState({
    required Widget child,
    String? loadingMessage,
  }) {
    final semanticsLabel = loadingMessage ?? '載入中';

    return Semantics(
      label: semanticsLabel,
      liveRegion: true,
      child: child,
    );
  }

  /// 為錯誤狀態提供語義標註
  Widget annotateErrorState({
    required Widget child,
    required String errorMessage,
    VoidCallback? onRetry,
  }) {
    String semanticsLabel = '錯誤: $errorMessage';
    if (onRetry != null) semanticsLabel += ', 點擊重試';

    return Semantics(
      label: semanticsLabel,
      button: onRetry != null,
      onTap: onRetry,
      child: child,
    );
  }

  /// 為空狀態提供語義標註
  Widget annotateEmptyState({
    required Widget child,
    required String emptyMessage,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    String semanticsLabel = emptyMessage;
    if (onAction != null && actionLabel != null) {
      semanticsLabel += ', $actionLabel';
    }

    return Semantics(
      label: semanticsLabel,
      button: onAction != null,
      onTap: onAction,
      child: child,
    );
  }

  /// 格式化時間
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '剛剛';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分鐘前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小時前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.month}月${dateTime.day}日';
    }
  }
}

/// 鍵盤導航輔助類
class KeyboardNavigationHelper {
  /// 為組件添加鍵盤焦點支援
  static Widget makeFocusable({
    required Widget child,
    VoidCallback? onTap,
    String? semanticsLabel,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;

          return GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: hasFocus
                  ? BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).focusColor,
                        width: 2.0,
                      ),
                    )
                  : null,
              child: Semantics(
                label: semanticsLabel,
                focusable: true,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 創建可鍵盤操作的列表項
  static Widget createKeyboardNavigableListItem({
    required Widget child,
    required VoidCallback onActivate,
    String? semanticsLabel,
  }) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event.logicalKey.keyLabel == 'Enter' ||
            event.logicalKey.keyLabel == 'Space') {
          onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: makeFocusable(
        child: child,
        onTap: onActivate,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
