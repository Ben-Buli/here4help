import 'package:flutter/material.dart';

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
      backgroundColor:
          backgroundColor ?? const Color.fromARGB(255, 140, 91, 88),
      foregroundColor:
          foregroundColor ?? const Color.fromARGB(255, 255, 255, 255),
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

/// 任務狀態枚舉（對應 tasks.status_id）
enum TaskStatus {
  open,
  inProgress,
  pendingConfirmation,
  dispute,
  completed,
  cancelled,
  rejected,
}

/// 應徵狀態枚舉（對應 task_applications.status）
enum TaskApplicationStatus {
  applied, // 已投遞
  accepted, // 已被指派
  pending, // 待處理/待確認
  dispute, // 爭議中
  completed, // 已完成
  rejected, // 已被拒絕
  cancelled, // 已取消
  withdrawn, // 使用者已撤銷
}

/// Action Bar 配置管理器
class ActionBarConfigManager {
  /// 根據任務狀態和用戶角色獲取可用動作
  static List<ActionBarAction> getActionsForStatus({
    required UserRole userRole,
    required Map<String, VoidCallback> actionCallbacks,
    TaskStatus? taskStatus, // Creator 使用的任務狀態（tasks.status_id）
    TaskApplicationStatus?
        applicationStatus, // Participant 使用的應徵狀態（task_applications.status）
    bool isBlocked = false, // 封鎖狀態參數
    bool isBlockedByMe = false, // 我是否封鎖了對方
    bool isBlockedByTarget = false, // 對方是否封鎖了我
    bool hasExistingReview = false, // 是否已有評分
  }) {
    // 添加詳細的調試信息
    debugPrint('🔍 [ActionBarConfigManager] getActionsForStatus called:');
    debugPrint('  - userRole: $userRole');
    debugPrint('  - taskStatus: $taskStatus');
    debugPrint('  - applicationStatus: $applicationStatus');
    debugPrint('  - isBlocked: $isBlocked');
    debugPrint('  - isBlockedByMe: $isBlockedByMe');
    debugPrint('  - isBlockedByTarget: $isBlockedByTarget');
    debugPrint('  - hasExistingReview: $hasExistingReview');
    debugPrint('  - actionCallbacks keys: ${actionCallbacks.keys.toList()}');

    final actions = <ActionBarAction>[];

    // Creator 和 Participant 分別處理不同的狀態
    if (userRole == UserRole.creator) {
      if (taskStatus == null) {
        debugPrint('❌ [ActionBarConfigManager] taskStatus is null for creator');
        return actions;
      }
      return _getCreatorActions(
        taskStatus: taskStatus,
        actionCallbacks: actionCallbacks,
        isBlocked: isBlocked,
        isBlockedByMe: isBlockedByMe,
        isBlockedByTarget: isBlockedByTarget,
        hasExistingReview: hasExistingReview,
        applicationStatus: applicationStatus,
      );
    } else {
      if (applicationStatus == null) {
        debugPrint(
            '❌ [ActionBarConfigManager] applicationStatus is null for participant');
        return actions;
      }
      return _getParticipantActions(
        applicationStatus: applicationStatus,
        actionCallbacks: actionCallbacks,
        isBlocked: isBlocked,
        isBlockedByMe: isBlockedByMe,
        isBlockedByTarget: isBlockedByTarget,
      );
    }
  }

  /// Creator 的動作邏輯（基於任務狀態）
  static List<ActionBarAction> _getCreatorActions({
    required TaskStatus taskStatus,
    required Map<String, VoidCallback> actionCallbacks,
    required bool isBlocked,
    required bool isBlockedByMe,
    required bool isBlockedByTarget,
    required bool hasExistingReview,
    TaskApplicationStatus? applicationStatus,
  }) {
    final actions = <ActionBarAction>[];

    switch (taskStatus) {
      case TaskStatus.open:
        // 檢查應徵狀態，只有非 withdrawn 狀態才顯示 Accept 按鈕
        if (applicationStatus != TaskApplicationStatus.withdrawn) {
          actions.add(
            ActionBarAction(
              id: 'accept',
              label: 'Accept',
              icon: Icons.check,
              backgroundColor: const Color.fromARGB(255, 88, 140, 127),
              foregroundColor: const Color.fromARGB(255, 255, 255, 255),
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
            id: 'reject',
            label: 'Reject',
            icon: Icons.close,
            backgroundColor: const Color.fromARGB(255, 145, 93, 90),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            onTap: actionCallbacks['reject'] ?? () {},
          ).asDestructive().withConfirmation(
                title: 'Reject Application',
                content:
                    'Are you sure you want to reject this applicant for this task?',
              ),
        );
        // Block 按鈕邏輯：只要有任何一方封鎖，另一方就失去 Block 功能
        _addBlockActions(
          actions: actions,
          actionCallbacks: actionCallbacks,
          isBlocked: isBlocked,
          isBlockedByMe: isBlockedByMe,
          isBlockedByTarget: isBlockedByTarget,
        );
        break;

      case TaskStatus.inProgress:
        actions.addAll([
          ActionBarAction(
            id: 'pay',
            label: 'Pay',
            icon: Icons.payment,
            onTap: actionCallbacks['pay'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 187, 150, 49),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
          ActionBarAction(
            id: 'dispute',
            label: 'Dispute',
            icon: Icons.report_problem,
            onTap: actionCallbacks['dispute'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 119, 96, 72),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          )
        ]);
        break;

      case TaskStatus.pendingConfirmation:
        actions.addAll([
          ActionBarAction(
            id: 'confirm',
            label: 'Confirm',
            icon: Icons.check,
            onTap: actionCallbacks['confirm'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 88, 140, 127),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
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
            backgroundColor: const Color.fromARGB(255, 120, 72, 70),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ).asDestructive().withConfirmation(
                title: 'Disagree Completion',
                content: 'Disagree this task is completed?',
              ),
          ActionBarAction(
            id: 'dispute',
            label: 'Dispute',
            icon: Icons.report_problem,
            onTap: actionCallbacks['dispute'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 119, 96, 72),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ).asDestructive(),
        ]);
        break;

      case TaskStatus.completed:
        // Reviews 按鈕邏輯：根據是否有現有評分顯示不同按鈕
        if (hasExistingReview) {
          actions.add(
            ActionBarAction(
              id: 'view_review',
              label: 'Reviewed',
              icon: Icons.visibility,
              onTap: actionCallbacks['view_review'] ?? () {},
              backgroundColor: const Color.fromARGB(255, 72, 107, 119),
              foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
          );
        } else {
          actions.add(
            ActionBarAction(
              id: 'review',
              label: 'Reviews',
              icon: Icons.reviews,
              onTap: actionCallbacks['review'] ?? () {},
              backgroundColor: const Color.fromARGB(255, 72, 107, 119),
              foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
          );
        }

        // Block 按鈕邏輯：只要有任何一方封鎖，另一方就失去 Block 功能
        _addBlockActions(
          actions: actions,
          actionCallbacks: actionCallbacks,
          isBlocked: isBlocked,
          isBlockedByMe: isBlockedByMe,
          isBlockedByTarget: isBlockedByTarget,
        );
        break;

      case TaskStatus.dispute:
        actions.add(
          ActionBarAction(
            id: 'dispute',
            label: 'Dispute',
            icon: Icons.report_problem,
            onTap: actionCallbacks['dispute'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 119, 96, 72),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
        );
        break;

      case TaskStatus.cancelled:
      case TaskStatus.rejected:
        actions.addAll([
          ActionBarAction(
            id: 'report',
            label: 'Report',
            icon: Icons.article,
            onTap: actionCallbacks['report'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 97, 97, 97),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
          ActionBarAction(
            id: 'block',
            label: 'Block',
            icon: Icons.block,
            onTap: actionCallbacks['block'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 109, 105, 105),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ).asDestructive().withConfirmation(
                title: 'Block User',
                content: 'Block this user?',
              ),
        ]);
    }

    // 添加結果調試信息
    debugPrint('🔍 [ActionBarConfigManager] _getCreatorActions result:');
    debugPrint('  - actions count: ${actions.length}');
    debugPrint('  - action IDs: ${actions.map((a) => a.id).toList()}');

    return actions;
  }

  /// Participant 的動作邏輯（基於應徵狀態）
  static List<ActionBarAction> _getParticipantActions({
    required TaskApplicationStatus applicationStatus,
    required Map<String, VoidCallback> actionCallbacks,
    required bool isBlocked,
    required bool isBlockedByMe,
    required bool isBlockedByTarget,
  }) {
    final actions = <ActionBarAction>[];

    switch (applicationStatus) {
      case TaskApplicationStatus.applied:
        actions.addAll([
          ActionBarAction(
            id: 'report',
            label: 'Report',
            icon: Icons.article,
            onTap: actionCallbacks['report'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 97, 97, 97),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
          ActionBarAction(
            id: 'withdraw',
            label: 'Withdraw',
            icon: Icons.close,
            onTap: actionCallbacks['withdraw'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 109, 105, 105),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
        ]);
        break;

      case TaskApplicationStatus.accepted:
        actions.addAll([
          ActionBarAction(
            id: 'complete',
            label: 'Completed',
            icon: Icons.check_circle,
            onTap: actionCallbacks['complete'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 93, 72, 105),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ).withConfirmation(
            title: 'Mark as Completed',
            content: 'Are you sure you have completed this task?',
          ),
          ActionBarAction(
            id: 'dispute',
            label: 'Dispute',
            icon: Icons.report_problem,
            onTap: actionCallbacks['dispute'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 119, 96, 72),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
        ]);
        break;

      case TaskApplicationStatus.pending:
        actions.add(
          ActionBarAction(
            id: 'dispute',
            label: 'Dispute',
            icon: Icons.report_problem,
            onTap: actionCallbacks['dispute'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 119, 96, 72),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ).asDestructive(),
        );
        break;

      case TaskApplicationStatus.completed:
        // 任務完成後，可以封鎖用戶
        _addBlockActions(
          actions: actions,
          actionCallbacks: actionCallbacks,
          isBlocked: isBlocked,
          isBlockedByMe: isBlockedByMe,
          isBlockedByTarget: isBlockedByTarget,
        );
        break;

      case TaskApplicationStatus.dispute:
        actions.add(
          ActionBarAction(
            id: 'dispute',
            label: 'Dispute',
            icon: Icons.report_problem,
            onTap: actionCallbacks['dispute'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 119, 96, 72),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
        );
        break;

      case TaskApplicationStatus.rejected:
      case TaskApplicationStatus.cancelled:
        actions.addAll([
          ActionBarAction(
            id: 'report',
            label: 'Report',
            icon: Icons.article,
            onTap: actionCallbacks['report'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 97, 97, 97),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ),
          ActionBarAction(
            id: 'block',
            label: 'Block',
            icon: Icons.block,
            onTap: actionCallbacks['block'] ?? () {},
            backgroundColor: const Color.fromARGB(255, 109, 105, 105),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
          ).asDestructive().withConfirmation(
                title: 'Block User',
                content: 'Block this user?',
              ),
        ]);
        break;

      case TaskApplicationStatus.withdrawn:
        // 已撤回的應徵沒有可執行的動作
        break;
    }

    // 添加結果調試信息
    debugPrint('🔍 [ActionBarConfigManager] _getParticipantActions result:');
    debugPrint('  - actions count: ${actions.length}');
    debugPrint('  - action IDs: ${actions.map((a) => a.id).toList()}');

    return actions;
  }

  /// 添加封鎖相關按鈕的共用方法
  static void _addBlockActions({
    required List<ActionBarAction> actions,
    required Map<String, VoidCallback> actionCallbacks,
    required bool isBlocked,
    required bool isBlockedByMe,
    required bool isBlockedByTarget,
  }) {
    if (!isBlocked) {
      // 沒有任何封鎖關係，顯示 "Block" 按鈕
      actions.add(
        ActionBarAction(
          id: 'block',
          label: 'Block',
          icon: Icons.block,
          onTap: actionCallbacks['block'] ?? () {},
          backgroundColor: const Color.fromARGB(255, 109, 105, 105),
          foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        ).asDestructive().withConfirmation(
              title: 'Block User',
              content:
                  'Block this user? This will disable all communication in this chat room.',
            ),
      );
    } else if (isBlockedByMe) {
      // 我封鎖了對方，顯示 "Blocked" 按鈕，可解除封鎖
      actions.add(
        ActionBarAction(
          id: 'unblock',
          label: 'Blocked',
          icon: Icons.block,
          onTap: actionCallbacks['unblock'] ?? () {},
          backgroundColor: const Color.fromARGB(255, 255, 152, 0), // 橙色
          foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        ).withConfirmation(
          title: 'Unblock User',
          content: 'Are you sure you want to unblock this user?',
        ),
      );
    }
    // 如果被對方封鎖（isBlockedByTarget），不顯示任何 Block 相關按鈕
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

  /// 將字符串狀態轉換為 TaskApplicationStatus 枚舉
  static TaskApplicationStatus parseApplicationStatus(String? statusString) {
    switch (statusString?.toLowerCase()) {
      case 'applied':
        return TaskApplicationStatus.applied;
      case 'accepted':
        return TaskApplicationStatus.accepted;
      case 'pending':
        return TaskApplicationStatus.pending;
      case 'dispute':
        return TaskApplicationStatus.dispute;
      case 'completed':
        return TaskApplicationStatus.completed;
      case 'rejected':
        return TaskApplicationStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return TaskApplicationStatus.cancelled;
      case 'withdrawn':
        return TaskApplicationStatus.withdrawn;
      default:
        return TaskApplicationStatus.applied;
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

  /// 獲取應徵狀態顯示顏色
  static Color getApplicationStatusColor(TaskApplicationStatus status) {
    switch (status) {
      case TaskApplicationStatus.applied:
        return Colors.blue;
      case TaskApplicationStatus.accepted:
        return Colors.orange;
      case TaskApplicationStatus.pending:
        return Colors.amber;
      case TaskApplicationStatus.completed:
        return Colors.green;
      case TaskApplicationStatus.dispute:
        return Colors.red;
      case TaskApplicationStatus.rejected:
      case TaskApplicationStatus.cancelled:
        return Colors.grey;
      case TaskApplicationStatus.withdrawn:
        return Colors.grey.shade400;
    }
  }

  /// 獲取應徵狀態圖標
  static IconData getApplicationStatusIcon(TaskApplicationStatus status) {
    switch (status) {
      case TaskApplicationStatus.applied:
        return Icons.send;
      case TaskApplicationStatus.accepted:
        return Icons.work;
      case TaskApplicationStatus.pending:
        return Icons.hourglass_empty;
      case TaskApplicationStatus.completed:
        return Icons.check_circle;
      case TaskApplicationStatus.dispute:
        return Icons.warning;
      case TaskApplicationStatus.rejected:
        return Icons.cancel;
      case TaskApplicationStatus.cancelled:
        return Icons.cancel;
      case TaskApplicationStatus.withdrawn:
        return Icons.undo;
    }
  }
}
