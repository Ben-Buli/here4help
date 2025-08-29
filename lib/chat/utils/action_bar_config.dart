import 'package:flutter/material.dart';
import 'package:here4help/chat/widgets/payment_dialog.dart';

/// Action Bar 動作定義
class ActionBarAction {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isDestructive;
  final bool requiresConfirmation;
  final String? confirmationTitle;
  final String? confirmationContent;

  const ActionBarAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.isDestructive = false,
    this.requiresConfirmation = false,
    this.confirmationTitle,
    this.confirmationContent,
  });

  /// 創建確認對話框動作
  ActionBarAction withConfirmation({
    required String title,
    required String content,
  }) {
    return ActionBarAction(
      id: id,
      label: label,
      icon: icon,
      onTap: onTap,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      isDestructive: isDestructive,
      requiresConfirmation: true,
      confirmationTitle: title,
      confirmationContent: content,
    );
  }

  /// 創建破壞性動作
  ActionBarAction asDestructive() {
    return ActionBarAction(
      id: id,
      label: label,
      icon: icon,
      onTap: onTap,
      backgroundColor: backgroundColor ?? Colors.red,
      foregroundColor: foregroundColor ?? Colors.white,
      isDestructive: true,
      requiresConfirmation: requiresConfirmation,
      confirmationTitle: confirmationTitle,
      confirmationContent: confirmationContent,
    );
  }
}

/// 用戶角色枚舉
enum UserRole {
  creator, // 任務創建者
  participant // 任務參與者
}

/// 任務狀態枚舉
enum TaskStatus {
  open,
  inProgress,
  pendingConfirmation,
  completed,
  dispute,
  cancelled,
  rejected,
}

/// Action Bar 配置管理器
class ActionBarConfigManager {
  /// 根據任務狀態和用戶角色獲取可用動作
  static List<ActionBarAction> getActionsForStatus({
    required TaskStatus status,
    required UserRole userRole,
    required Map<String, VoidCallback> actionCallbacks,
    String? applicationStatus, // 新增：應徵狀態參數
  }) {
    final actions = <ActionBarAction>[];

    switch (status) {
      case TaskStatus.open:
        if (userRole == UserRole.creator) {
          // 檢查應徵狀態，只有非 withdrawn 狀態才顯示 Accept 按鈕
          if (applicationStatus == null ||
              applicationStatus.toLowerCase() != 'withdrawn') {
            actions.add(
              ActionBarAction(
                id: 'accept',
                label: 'Accept',
                icon: Icons.check,
                onTap: actionCallbacks['accept'] ?? () {},
              ).withConfirmation(
                title: 'Accept Application',
                content:
                    'Are you sure you want to assign this applicant to this task?',
              ),
            );
          }

          actions.add(
            ActionBarAction(
              id: 'block',
              label: 'Block',
              icon: Icons.block,
              onTap: actionCallbacks['block'] ?? () {},
            ).asDestructive().withConfirmation(
                  title: 'Block User',
                  content:
                      'Block this user from applying your tasks in the future?',
                ),
          );
        } else {
          actions.add(
            ActionBarAction(
              id: 'report',
              label: 'Report',
              icon: Icons.article,
              onTap: actionCallbacks['report'] ?? () {},
            ),
          );
        }
        break;

      case TaskStatus.inProgress:
        if (userRole == UserRole.creator) {
          actions.addAll([
            ActionBarAction(
              id: 'pay',
              label: 'Pay',
              icon: Icons.payment,
              onTap: actionCallbacks['pay'] ?? () {},
            ),
            ActionBarAction(
              id: 'report',
              label: 'Report',
              icon: Icons.article,
              onTap: actionCallbacks['report'] ?? () {},
            ),
            ActionBarAction(
              id: 'block',
              label: 'Block',
              icon: Icons.block,
              onTap: actionCallbacks['block'] ?? () {},
            ).asDestructive().withConfirmation(
                  title: 'Block User',
                  content: 'Block this user?',
                ),
          ]);
        } else {
          actions.addAll([
            ActionBarAction(
              id: 'complete',
              label: 'Completed',
              icon: Icons.check_circle,
              onTap: actionCallbacks['complete'] ?? () {},
            ).withConfirmation(
              title: 'Mark as Completed',
              content: 'Are you sure you have completed this task?',
            ),
            ActionBarAction(
              id: 'report',
              label: 'Report',
              icon: Icons.article,
              onTap: actionCallbacks['report'] ?? () {},
            ),
          ]);
        }
        break;

      case TaskStatus.pendingConfirmation:
        if (userRole == UserRole.creator) {
          actions.addAll([
            ActionBarAction(
              id: 'confirm',
              label: 'Confirm',
              icon: Icons.check,
              onTap: actionCallbacks['confirm'] ?? () {},
            ).withConfirmation(
              title: 'Confirm Completion',
              content:
                  'Confirm this task and transfer reward points to the Tasker?',
            ),
            ActionBarAction(
              id: 'disagree',
              label: 'Disagree',
              icon: Icons.close,
              onTap: actionCallbacks['disagree'] ?? () {},
            ).asDestructive().withConfirmation(
                  title: 'Disagree Completion',
                  content: 'Disagree this task is completed?',
                ),
            ActionBarAction(
              id: 'dispute',
              label: 'Dispute',
              icon: Icons.report_problem,
              onTap: actionCallbacks['dispute'] ?? () {},
            ).asDestructive(),
            ActionBarAction(
              id: 'report',
              label: 'Report',
              icon: Icons.article,
              onTap: actionCallbacks['report'] ?? () {},
            ),
          ]);
        } else {
          actions.addAll([
            ActionBarAction(
              id: 'dispute',
              label: 'Dispute',
              icon: Icons.report_problem,
              onTap: actionCallbacks['dispute'] ?? () {},
            ).asDestructive(),
            ActionBarAction(
              id: 'report',
              label: 'Report',
              icon: Icons.article,
              onTap: actionCallbacks['report'] ?? () {},
            ),
          ]);
        }
        break;

      case TaskStatus.completed:
        if (userRole == UserRole.creator) {
          actions.addAll([
            ActionBarAction(
              id: 'paid_info',
              label: 'Paid',
              icon: Icons.attach_money,
              onTap: actionCallbacks['paid_info'] ?? () {},
            ),
            ActionBarAction(
              id: 'review',
              label: 'Reviews',
              icon: Icons.reviews,
              onTap: actionCallbacks['review'] ?? () {},
            ),
            ActionBarAction(
              id: 'dispute',
              label: 'Dispute',
              icon: Icons.report_problem,
              onTap: actionCallbacks['dispute'] ?? () {},
            ).asDestructive(),
            ActionBarAction(
              id: 'block',
              label: 'Block',
              icon: Icons.block,
              onTap: actionCallbacks['block'] ?? () {},
            ).asDestructive().withConfirmation(
                  title: 'Block User',
                  content: 'Block this user?',
                ),
          ]);
        } else {
          actions.addAll([
            ActionBarAction(
              id: 'dispute',
              label: 'Dispute',
              icon: Icons.report_problem,
              onTap: actionCallbacks['dispute'] ?? () {},
            ).asDestructive(),
            ActionBarAction(
              id: 'report',
              label: 'Report',
              icon: Icons.article,
              onTap: actionCallbacks['report'] ?? () {},
            ),
            ActionBarAction(
              id: 'review',
              label: 'Reviews',
              icon: Icons.reviews,
              onTap: actionCallbacks['review'] ?? () {},
            ),
            ActionBarAction(
              id: 'block',
              label: 'Block',
              icon: Icons.block,
              onTap: actionCallbacks['block'] ?? () {},
            ).asDestructive().withConfirmation(
                  title: 'Block User',
                  content: 'Block this user?',
                ),
          ]);
        }
        break;

      case TaskStatus.dispute:
        actions.add(
          ActionBarAction(
            id: 'report',
            label: 'Report',
            icon: Icons.article,
            onTap: actionCallbacks['report'] ?? () {},
          ),
        );
        break;

      case TaskStatus.cancelled:
      case TaskStatus.rejected:
      default:
        actions.addAll([
          ActionBarAction(
            id: 'report',
            label: 'Report',
            icon: Icons.article,
            onTap: actionCallbacks['report'] ?? () {},
          ),
          ActionBarAction(
            id: 'block',
            label: 'Block',
            icon: Icons.block,
            onTap: actionCallbacks['block'] ?? () {},
          ).asDestructive().withConfirmation(
                title: 'Block User',
                content: 'Block this user?',
              ),
        ]);
    }

    return actions;
  }

  /// 將字符串狀態轉換為 TaskStatus 枚舉
  static TaskStatus parseTaskStatus(String? statusCode) {
    switch (statusCode?.toLowerCase()) {
      case 'open':
        return TaskStatus.open;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'pending_confirmation':
        return TaskStatus.pendingConfirmation;
      case 'completed':
        return TaskStatus.completed;
      case 'dispute':
        return TaskStatus.dispute;
      case 'cancelled':
      case 'canceled':
        return TaskStatus.cancelled;
      case 'rejected':
        return TaskStatus.rejected;
      default:
        return TaskStatus.open;
    }
  }

  /// 將字符串角色轉換為 UserRole 枚舉
  static UserRole parseUserRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'creator':
        return UserRole.creator;
      case 'participant':
        return UserRole.participant;
      default:
        return UserRole.participant;
    }
  }

  /// 獲取狀態顯示顏色
  static Color getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return Colors.blue;
      case TaskStatus.inProgress:
        return Colors.orange;
      case TaskStatus.pendingConfirmation:
        return Colors.amber;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.dispute:
        return Colors.red;
      case TaskStatus.cancelled:
      case TaskStatus.rejected:
        return Colors.grey;
    }
  }

  /// 獲取狀態圖標
  static IconData getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return Icons.schedule;
      case TaskStatus.inProgress:
        return Icons.work;
      case TaskStatus.pendingConfirmation:
        return Icons.hourglass_empty;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.dispute:
        return Icons.warning;
      case TaskStatus.cancelled:
      case TaskStatus.rejected:
        return Icons.cancel;
    }
  }
}
