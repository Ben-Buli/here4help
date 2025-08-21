import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/router/guards/permission_guard.dart';

/// 權限感知的 Apply Now 按鈕
/// 根據用戶權限決定按鈕行為和顯示狀態
class ApplyNowButton extends StatelessWidget {
  final Map<String, dynamic> taskData;
  final VoidCallback? onPressed;
  final String? customText;
  final ButtonStyle? style;

  const ApplyNowButton({
    super.key,
    required this.taskData,
    this.onPressed,
    this.customText,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // 檢查是否可以應徵任務
        final canApply = PermissionGuard.canUseFeature(context, 'task_apply');

        if (canApply) {
          return ElevatedButton(
            onPressed: onPressed ?? () => _handleApplyTask(context),
            style: style,
            child: Text(customText ?? 'Apply Now'),
          );
        }

        // 權限不足時顯示禁用按鈕
        final shouldShowHint =
            PermissionGuard.shouldShowPermissionHint(context, 'task_apply');

        if (shouldShowHint) {
          final hintMessage =
              PermissionGuard.getPermissionHint(context, 'task_apply');

          return Tooltip(
            message: hintMessage,
            child: ElevatedButton(
              onPressed: () {
                // 顯示權限提示對話框
                PermissionGuard.checkFeaturePermission(
                  context,
                  'task_apply',
                  showDialog: true,
                );
              },
              style: style?.copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.grey[300]),
                    foregroundColor: WidgetStateProperty.all(Colors.grey[600]),
                  ) ??
                  ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[600],
                  ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 16),
                  const SizedBox(width: 4),
                  Text(customText ?? 'Apply Now'),
                ],
              ),
            ),
          );
        }

        // 帳號已刪除等情況，不顯示按鈕
        return const SizedBox.shrink();
      },
    );
  }

  void _handleApplyTask(BuildContext context) {
    // 導航到任務應徵頁面
    context.go('/task/apply', extra: taskData);
  }
}

/// 權限感知的進入聊天室按鈕
class EnterChatButton extends StatelessWidget {
  final Map<String, dynamic> chatData;
  final VoidCallback? onPressed;
  final String? customText;
  final ButtonStyle? style;
  final Widget? icon;

  const EnterChatButton({
    super.key,
    required this.chatData,
    this.onPressed,
    this.customText,
    this.style,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // 檢查是否可以訪問聊天功能
        final canChat = PermissionGuard.canUseFeature(context, 'chat');

        if (canChat) {
          return ElevatedButton.icon(
            onPressed: onPressed ?? () => _handleEnterChat(context),
            style: style,
            icon: icon ?? const Icon(Icons.chat),
            label: Text(customText ?? 'Enter Chat'),
          );
        }

        // 權限不足時顯示禁用按鈕
        final shouldShowHint =
            PermissionGuard.shouldShowPermissionHint(context, 'chat');

        if (shouldShowHint) {
          final hintMessage =
              PermissionGuard.getPermissionHint(context, 'chat');

          return Tooltip(
            message: hintMessage,
            child: ElevatedButton.icon(
              onPressed: () {
                // 顯示權限提示對話框
                PermissionGuard.checkFeaturePermission(
                  context,
                  'chat',
                  showDialog: true,
                );
              },
              style: style?.copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.grey[300]),
                    foregroundColor: WidgetStateProperty.all(Colors.grey[600]),
                  ) ??
                  ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[600],
                  ),
              icon: const Icon(Icons.lock_outline, size: 16),
              label: Text(customText ?? 'Enter Chat'),
            ),
          );
        }

        // 帳號已刪除等情況，不顯示按鈕
        return const SizedBox.shrink();
      },
    );
  }

  void _handleEnterChat(BuildContext context) {
    // 導航到聊天詳情頁面
    context.go('/chat/detail', extra: chatData);
  }
}

/// 權限感知的創建任務按鈕
class CreateTaskButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? customText;
  final ButtonStyle? style;
  final Widget? icon;

  const CreateTaskButton({
    super.key,
    this.onPressed,
    this.customText,
    this.style,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        // 檢查是否可以創建任務
        final canCreate = PermissionGuard.canUseFeature(context, 'task_create');

        if (canCreate) {
          return ElevatedButton.icon(
            onPressed: onPressed ?? () => _handleCreateTask(context),
            style: style,
            icon: icon ?? const Icon(Icons.add),
            label: Text(customText ?? 'Create Task'),
          );
        }

        // 權限不足時顯示禁用按鈕
        final shouldShowHint =
            PermissionGuard.shouldShowPermissionHint(context, 'task_create');

        if (shouldShowHint) {
          final hintMessage =
              PermissionGuard.getPermissionHint(context, 'task_create');

          return Tooltip(
            message: hintMessage,
            child: ElevatedButton.icon(
              onPressed: () {
                // 顯示權限提示對話框
                PermissionGuard.checkFeaturePermission(
                  context,
                  'task_create',
                  showDialog: true,
                );
              },
              style: style?.copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.grey[300]),
                    foregroundColor: WidgetStateProperty.all(Colors.grey[600]),
                  ) ??
                  ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.grey[600],
                  ),
              icon: const Icon(Icons.lock_outline, size: 16),
              label: Text(customText ?? 'Create Task'),
            ),
          );
        }

        // 帳號已刪除等情況，不顯示按鈕
        return const SizedBox.shrink();
      },
    );
  }

  void _handleCreateTask(BuildContext context) {
    // 導航到任務創建頁面
    context.go('/task/create');
  }
}
