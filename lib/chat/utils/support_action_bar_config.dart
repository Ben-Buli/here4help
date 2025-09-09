import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

/// 用戶角色枚舉（客服聊天室專用）
enum UserRole {
  customer, // 客戶（提交支援請求的用戶，對應 support_chat_rooms.user_id）
  admin // 管理員（處理支援請求的客服人員，對應 support_chat_rooms.admin_id）
}

/// 客服事件狀態枚舉
enum SupportStatus {
  submitted, // 已提交
  inProgress, // 進行中
  resolved, // 已解決
}

/// Support Action Bar 配置管理器
class SupportActionBarConfigManager {
  /// 根據客服狀態和用戶角色獲取可用動作
  static List<ActionBarAction> getActionsForSupportStatus({
    required UserRole userRole,
    required Map<String, VoidCallback> actionCallbacks,
    SupportStatus? supportStatus,
  }) {
    if (kDebugMode) {
      debugPrint('🔍 [SupportActionBar] $userRole/$supportStatus');
    }

    final actions = <ActionBarAction>[];

    // 只有客戶（customer）可以操作客服聊天室
    if (userRole == UserRole.customer) {
      // 根據客服事件狀態顯示不同的動作
      switch (supportStatus) {
        case SupportStatus.submitted:
          // 已提交，等待管理員回應
          // 提供查看支援事件詳情的動作
          if (actionCallbacks.containsKey('issue')) {
            actions.add(
              ActionBarAction(
                id: 'issue',
                label: 'View Issue',
                icon: Icons.info_outline,
                onTap: actionCallbacks['issue']!,
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.white,
              ),
            );
          }
          break;
        case SupportStatus.inProgress:
          // 進行中，可以結案並評分
          if (actionCallbacks.containsKey('close')) {
            actions.add(
              ActionBarAction(
                id: 'close',
                label: 'Close',
                icon: Icons.close,
                onTap: actionCallbacks['close']!,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ).withConfirmation(
                title: 'Close Support Case',
                content:
                    'Are you sure you want to close this support case? You can rate the service after closing.',
              ),
            );
          }
          break;
        case SupportStatus.resolved:
          // 已結案，只能查看
          // 不提供任何動作
          break;
        case null:
          // 未知狀態，不提供動作
          break;
      }
    }
    // 管理員（admin）在客服聊天室中不需要特殊動作
    // 他們只能發送訊息，不能操作客服事件狀態

    if (kDebugMode && actions.isNotEmpty) {
      debugPrint(
          '✅ [SupportActionBar] ${actions.length} actions: ${actions.map((a) => a.id).join(', ')}');
    }

    return actions;
  }

  /// 將字符串狀態轉換為 SupportStatus 枚舉
  static SupportStatus? parseSupportStatus(String? statusString) {
    switch (statusString?.toLowerCase()) {
      case 'submitted':
        return SupportStatus.submitted;
      case 'in_progress':
        return SupportStatus.inProgress;
      case 'resolved':
        return SupportStatus.resolved;
      default:
        return null;
    }
  }

  /// 將字符串角色轉換為 UserRole 枚舉
  static UserRole parseUserRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'customer':
      case 'creator': // 向後兼容
        return UserRole.customer;
      case 'admin':
      case 'participant': // 向後兼容
        return UserRole.admin;
      default:
        return UserRole.customer; // 預設為客戶
    }
  }

  /// 獲取客服狀態顯示顏色
  static Color getSupportStatusColor(SupportStatus? status) {
    switch (status) {
      case SupportStatus.submitted:
        return Colors.blue;
      case SupportStatus.inProgress:
        return Colors.orange;
      case SupportStatus.resolved:
        return Colors.green;
      case null:
        return Colors.grey;
    }
  }

  /// 獲取客服狀態圖標
  static IconData getSupportStatusIcon(SupportStatus? status) {
    switch (status) {
      case SupportStatus.submitted:
        return Icons.support_agent;
      case SupportStatus.inProgress:
        return Icons.support;
      case SupportStatus.resolved:
        return Icons.check_circle;
      case null:
        return Icons.help_outline;
    }
  }

  /// 獲取客服狀態顯示名稱
  static String getSupportStatusName(SupportStatus? status) {
    switch (status) {
      case SupportStatus.submitted:
        return 'Support Request Submitted';
      case SupportStatus.inProgress:
        return 'Support In Progress';
      case SupportStatus.resolved:
        return 'Support Resolved';
      case null:
        return 'Support Chat';
    }
  }
}
