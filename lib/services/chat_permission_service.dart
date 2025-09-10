/**
 * 統一聊天室權限管理服務 (Flutter)
 * 提供一致的聊天室權限控制邏輯
 */

// 聊天室類型定義
enum ChatRoomType {
  dispute,
  support,
  application,
}

// 用戶角色定義
enum UserRole {
  admin,
  user,
  creator,
  participant,
}

// 聊天室狀態定義
enum ChatRoomStatus {
  open,
  inProgress,
  resolved,
  closed,
}

// 權限動作定義
enum PermissionAction {
  view,
  sendMessage,
  claim,
  transfer,
  resolve,
  close,
}

/// 聊天室權限配置
class ChatRoomPermissionConfig {
  final ChatRoomType roomType;
  final UserRole userRole;
  final ChatRoomStatus roomStatus;
  final bool isAssignedAdmin;
  final bool isRoomCreator;

  const ChatRoomPermissionConfig({
    required this.roomType,
    required this.userRole,
    required this.roomStatus,
    this.isAssignedAdmin = false,
    this.isRoomCreator = false,
  });
}

/// 權限檢查結果
class PermissionResult {
  final bool allowed;
  final String? reason;
  final String? requiresAction;

  const PermissionResult({
    required this.allowed,
    this.reason,
    this.requiresAction,
  });
}

/// 統一聊天室權限管理服務
class ChatRoomPermissionService {
  /// 檢查用戶是否具有指定動作的權限
  static PermissionResult checkPermission(
    ChatRoomPermissionConfig config,
    PermissionAction action,
  ) {
    switch (action) {
      case PermissionAction.view:
        return _checkViewPermission(config);
      case PermissionAction.sendMessage:
        return _checkSendMessagePermission(config);
      case PermissionAction.claim:
        return _checkClaimPermission(config);
      case PermissionAction.transfer:
        return _checkTransferPermission(config);
      case PermissionAction.resolve:
        return _checkResolvePermission(config);
      case PermissionAction.close:
        return _checkClosePermission(config);
    }
  }

  /// 檢查查看權限
  static PermissionResult _checkViewPermission(
      ChatRoomPermissionConfig config) {
    // 所有用戶都可以查看聊天室
    if (config.userRole == UserRole.admin || config.userRole == UserRole.user) {
      return const PermissionResult(allowed: true);
    }

    // 創建者和參與者可以查看自己的聊天室
    if (config.userRole == UserRole.creator ||
        config.userRole == UserRole.participant) {
      return const PermissionResult(allowed: true);
    }

    return const PermissionResult(
      allowed: false,
      reason: 'Insufficient permissions to view chat room',
    );
  }

  /// 檢查發送訊息權限
  static PermissionResult _checkSendMessagePermission(
      ChatRoomPermissionConfig config) {
    // 已關閉的聊天室不允許發送訊息
    if (config.roomStatus == ChatRoomStatus.closed ||
        config.roomStatus == ChatRoomStatus.resolved) {
      return const PermissionResult(
        allowed: false,
        reason: 'Cannot send messages to closed chat room',
      );
    }

    switch (config.roomType) {
      case ChatRoomType.dispute:
        // 爭議聊天室：只有用戶可以發送訊息，管理員只能查看
        if (config.userRole == UserRole.creator ||
            config.userRole == UserRole.participant) {
          return const PermissionResult(allowed: true);
        }
        return const PermissionResult(
          allowed: false,
          reason: 'Admins can only view dispute chat rooms',
        );

      case ChatRoomType.support:
        // 客服聊天室：用戶和管理員都可以發送訊息
        if (config.userRole == UserRole.user ||
            config.userRole == UserRole.admin) {
          return const PermissionResult(allowed: true);
        }
        return const PermissionResult(
          allowed: false,
          reason: 'Only users and admins can send messages in support chat',
        );

      case ChatRoomType.application:
        // 任務聊天室：創建者和參與者都可以發送訊息
        if (config.userRole == UserRole.creator ||
            config.userRole == UserRole.participant) {
          return const PermissionResult(allowed: true);
        }
        return const PermissionResult(
          allowed: false,
          reason: 'Only task creator and participant can send messages',
        );
    }
  }

  /// 檢查接手權限
  static PermissionResult _checkClaimPermission(
      ChatRoomPermissionConfig config) {
    // 只有管理員可以接手
    if (config.userRole != UserRole.admin) {
      return const PermissionResult(
        allowed: false,
        reason: 'Only admins can claim chat rooms',
      );
    }

    // 已經被接手的聊天室不能再次接手
    if (config.isAssignedAdmin) {
      return const PermissionResult(
        allowed: false,
        reason: 'Chat room is already claimed by another admin',
      );
    }

    // 已關閉的聊天室不能接手
    if (config.roomStatus == ChatRoomStatus.closed ||
        config.roomStatus == ChatRoomStatus.resolved) {
      return const PermissionResult(
        allowed: false,
        reason: 'Cannot claim closed chat room',
      );
    }

    // 只有客服聊天室可以被接手
    if (config.roomType != ChatRoomType.support) {
      return const PermissionResult(
        allowed: false,
        reason: 'Only support chat rooms can be claimed',
      );
    }

    return const PermissionResult(allowed: true);
  }

  /// 檢查轉派權限
  static PermissionResult _checkTransferPermission(
      ChatRoomPermissionConfig config) {
    // 只有管理員可以轉派
    if (config.userRole != UserRole.admin) {
      return const PermissionResult(
        allowed: false,
        reason: 'Only admins can transfer chat rooms',
      );
    }

    // 只有被指派的管理員可以轉派
    if (!config.isAssignedAdmin) {
      return const PermissionResult(
        allowed: false,
        reason: 'Only assigned admin can transfer chat room',
      );
    }

    return const PermissionResult(allowed: true);
  }

  /// 檢查解決權限
  static PermissionResult _checkResolvePermission(
      ChatRoomPermissionConfig config) {
    // 只有管理員可以解決
    if (config.userRole != UserRole.admin) {
      return const PermissionResult(
        allowed: false,
        reason: 'Only admins can resolve chat rooms',
      );
    }

    // 只有被指派的管理員可以解決
    if (!config.isAssignedAdmin) {
      return const PermissionResult(
        allowed: false,
        reason: 'Only assigned admin can resolve chat room',
      );
    }

    return const PermissionResult(allowed: true);
  }

  /// 檢查關閉權限
  static PermissionResult _checkClosePermission(
      ChatRoomPermissionConfig config) {
    // 已關閉的聊天室不能再次關閉
    if (config.roomStatus == ChatRoomStatus.closed ||
        config.roomStatus == ChatRoomStatus.resolved) {
      return const PermissionResult(
        allowed: false,
        reason: 'Chat room is already closed',
      );
    }

    // 用戶可以關閉自己的客服聊天室
    if (config.roomType == ChatRoomType.support &&
        config.userRole == UserRole.user) {
      return const PermissionResult(allowed: true);
    }

    // 管理員可以關閉任何聊天室
    if (config.userRole == UserRole.admin) {
      return const PermissionResult(allowed: true);
    }

    return const PermissionResult(
      allowed: false,
      reason: 'Insufficient permissions to close chat room',
    );
  }

  /// 獲取聊天室可用的動作列表
  static List<PermissionAction> getAvailableActions(
      ChatRoomPermissionConfig config) {
    final List<PermissionAction> actions = [PermissionAction.view];

    // 檢查每個動作的權限
    const allActions = [
      PermissionAction.sendMessage,
      PermissionAction.claim,
      PermissionAction.transfer,
      PermissionAction.resolve,
      PermissionAction.close,
    ];

    for (final action in allActions) {
      final result = checkPermission(config, action);
      if (result.allowed) {
        actions.add(action);
      }
    }

    return actions;
  }

  /// 檢查聊天室是否為唯讀模式
  static bool isReadOnly(ChatRoomPermissionConfig config) {
    final sendMessageResult =
        checkPermission(config, PermissionAction.sendMessage);
    return !sendMessageResult.allowed;
  }

  /// 獲取聊天室狀態顯示文字
  static String getStatusDisplayText(ChatRoomStatus status) {
    switch (status) {
      case ChatRoomStatus.open:
        return 'Open';
      case ChatRoomStatus.inProgress:
        return 'In Progress';
      case ChatRoomStatus.resolved:
        return 'Resolved';
      case ChatRoomStatus.closed:
        return 'Closed';
    }
  }

  /// 獲取聊天室類型顯示文字
  static String getTypeDisplayText(ChatRoomType type) {
    switch (type) {
      case ChatRoomType.dispute:
        return 'Dispute';
      case ChatRoomType.support:
        return 'Support';
      case ChatRoomType.application:
        return 'Task Chat';
    }
  }
}
