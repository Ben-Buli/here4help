import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:here4help/chat/utils/action_bar_config.dart';
import 'package:here4help/chat/widgets/task_card_components.dart';
import 'package:here4help/chat/utils/application_status_utils.dart';

/// 動態 Action Bar 組件
/// 根據任務狀態和用戶角色動態顯示操作按鈕
class DynamicActionBar extends StatelessWidget {
  final TaskStatus taskStatus;
  final UserRole userRole;
  final Map<String, VoidCallback> actionCallbacks;
  final bool showStatusBar;
  final String? statusDisplayName;
  final double? progressRatio;
  final Color? backgroundColor;
  final String? colorScheme; // 新增：指定配色方案 ('posted_tasks' 或 'my_works')

  const DynamicActionBar({
    super.key,
    required this.taskStatus,
    required this.userRole,
    required this.actionCallbacks,
    this.showStatusBar = true,
    this.statusDisplayName,
    this.progressRatio,
    this.backgroundColor,
    this.colorScheme, // 新增參數
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 [DynamicActionBar] build() 開始');
    debugPrint('  - taskStatus: $taskStatus');
    debugPrint('  - userRole: $userRole');
    debugPrint('  - showStatusBar: $showStatusBar');
    debugPrint('  - statusDisplayName: $statusDisplayName');
    debugPrint('  - progressRatio: $progressRatio');
    debugPrint('  - actionCallbacks keys: ${actionCallbacks.keys.toList()}');

    final actions = ActionBarConfigManager.getActionsForStatus(
      status: taskStatus,
      userRole: userRole,
      actionCallbacks: actionCallbacks,
    );

    debugPrint('  - 獲取到的 actions 數量: ${actions.length}');
    for (int i = 0; i < actions.length; i++) {
      final action = actions[i];
      debugPrint('    - Action $i: ${action.label} (${action.icon})');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 狀態顯示條
        if (showStatusBar) _buildStatusBar(context),

        // Action Bar 按鈕
        if (actions.isNotEmpty) _buildActionBar(context, actions),
      ],
    );
  }

  /// 構建狀態顯示條
  Widget _buildStatusBar(BuildContext context) {
    debugPrint('🔍 [DynamicActionBar] _buildStatusBar() 開始');

    final statusColor = ActionBarConfigManager.getStatusColor(taskStatus);
    final statusIcon = ActionBarConfigManager.getStatusIcon(taskStatus);

    debugPrint('  - statusColor: $statusColor');
    debugPrint('  - statusIcon: $statusIcon');
    debugPrint('  - statusDisplayName: $statusDisplayName');
    debugPrint('  - progressRatio: $progressRatio');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: statusColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusDisplayName ?? _getDefaultStatusName(taskStatus),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (progressRatio != null && progressRatio! > 0) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progressRatio,
                    backgroundColor: statusColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(progressRatio! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 構建 Action Bar
  Widget _buildActionBar(BuildContext context, List<ActionBarAction> actions) {
    debugPrint('🔍 [DynamicActionBar] _buildActionBar() 開始');
    debugPrint('  - actions 數量: ${actions.length}');
    debugPrint('  - colorScheme: $colorScheme');

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: _getContextualBackgroundColor(context),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          child: Row(
            children: actions
                .map(
                  (action) => Expanded(
                    child: _buildActionButton(context, action),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  /// 構建單個動作按鈕
  Widget _buildActionButton(BuildContext context, ActionBarAction action) {
    return IconTheme(
      data: IconThemeData(
        color: action.foregroundColor ??
            Theme.of(context).appBarTheme.foregroundColor ??
            Colors.white,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: action.foregroundColor ??
              Theme.of(context).appBarTheme.foregroundColor ??
              Colors.white,
        ),
        child: InkWell(
          onTap: () => _handleActionTap(context, action),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: action.backgroundColor != null
                      ? BoxDecoration(
                          color: action.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: action.backgroundColor != null
                        ? action.foregroundColor ?? Colors.white
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: action.backgroundColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 處理動作點擊
  void _handleActionTap(BuildContext context, ActionBarAction action) {
    if (action.requiresConfirmation) {
      _showConfirmationDialog(context, action);
    } else {
      action.onTap();
    }
  }

  /// 顯示確認對話框
  void _showConfirmationDialog(BuildContext context, ActionBarAction action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action.confirmationTitle ?? 'Confirm Action'),
        content: Text(action.confirmationContent ??
            'Are you sure you want to perform this action?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              action.onTap();
            },
            style: action.isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  /// 獲取上下文相關的背景顏色
  /// 根據配色方案和任務狀態返回適當的背景色
  Color _getContextualBackgroundColor(BuildContext context) {
    // 如果指定了配色方案，使用對應的配色邏輯
    debugPrint(
        '🔍 [_getContextualBackgroundColor()] colorScheme: $colorScheme');
    if (colorScheme != null) {
      switch (colorScheme) {
        case 'posted_tasks':
          return _getPostedTasksBackgroundColor(context);
        case 'my_works':
          return _getMyWorksBackgroundColor(context);
        default:
          return _getGlassNavColor(context);
      }
    }

    // 預設使用玻璃效果導航顏色
    return _getGlassNavColor(context);
  }

  /// 獲取 Posted Tasks 分頁的背景色（基於 tasks.status_id）
  Color _getPostedTasksBackgroundColor(BuildContext context) {
    // 將 TaskStatus 轉換為對應的狀態字符串
    final statusString = _taskStatusToString(taskStatus);

    // 使用 TaskCardUtils.getProgressData 獲取配色
    final progressData = TaskCardUtils.getProgressData(statusString);
    final baseColor = progressData['color'] as Color?;

    if (baseColor != null) {
      // 使用狀態對應的顏色，但降低透明度以保持玻璃效果
      return baseColor.withOpacity(0.3);
    }

    // 備用方案
    return _getGlassNavColor(context);
  }

  /// 獲取 My Works 分頁的背景色（基於 task_applications.status）
  Color _getMyWorksBackgroundColor(BuildContext context) {
    // 將 TaskStatus 轉換為對應的應用狀態字符串
    final applicationStatus = _taskStatusToApplicationStatus(taskStatus);

    // 使用 ApplicationStatusUtils.getStatusColor 獲取配色
    final statusColor =
        ApplicationStatusUtils.getStatusColor(applicationStatus);

    // 使用狀態對應的顏色，但降低透明度以保持玻璃效果
    return statusColor.withOpacity(0.3);
  }

  /// 將 TaskStatus 轉換為狀態字符串
  String _taskStatusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.pendingConfirmation:
        return 'Pending Confirmation';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.dispute:
        return 'Dispute';
      case TaskStatus.cancelled:
        return 'Cancelled';
      case TaskStatus.rejected:
        return 'Rejected';
    }
  }

  /// 將 TaskStatus 轉換為應用狀態字符串
  String _taskStatusToApplicationStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'applied'; // 任務開放時，應徵者狀態為已投遞
      case TaskStatus.inProgress:
        return 'accepted'; // 任務進行中時，應徵者狀態為已接受
      case TaskStatus.pendingConfirmation:
        return 'pending'; // 等待確認時，應徵者狀態為待確認
      case TaskStatus.completed:
        return 'completed'; // 任務完成時，應徵者狀態為已完成
      case TaskStatus.dispute:
        return 'dispute'; // 爭議時，應徵者狀態為爭議中
      case TaskStatus.cancelled:
        return 'cancelled'; // 任務取消時，應徵者狀態為已取消
      case TaskStatus.rejected:
        return 'rejected'; // 任務拒絕時，應徵者狀態為被拒絕
    }
  }

  /// 獲取玻璃效果導航顏色
  Color _getGlassNavColor(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;

    if (appBarTheme.backgroundColor != null) {
      return appBarTheme.backgroundColor!.withOpacity(0.8);
    }

    return theme.colorScheme.surface.withOpacity(0.8);
  }

  /// 獲取默認狀態名稱
  String _getDefaultStatusName(TaskStatus status) {
    debugPrint('🔍 [DynamicActionBar][_getDefaultStatusName] status: $status');
    switch (status) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.pendingConfirmation:
        return 'Pending Confirmation';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.dispute:
        return 'Dispute';
      case TaskStatus.cancelled:
        return 'Cancelled';
      case TaskStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Action Bar 構建器
/// 提供更靈活的構建方式
class ActionBarBuilder {
  final List<ActionBarAction> _actions = [];

  /// 添加動作
  ActionBarBuilder addAction(ActionBarAction action) {
    _actions.add(action);
    return this;
  }

  /// 添加簡單動作
  ActionBarBuilder addSimpleAction({
    required String id,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    _actions.add(ActionBarAction(
      id: id,
      label: label,
      icon: icon,
      onTap: onTap,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    ));
    return this;
  }

  /// 添加確認動作
  ActionBarBuilder addConfirmAction({
    required String id,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required String confirmTitle,
    required String confirmContent,
    bool isDestructive = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    _actions.add(ActionBarAction(
      id: id,
      label: label,
      icon: icon,
      onTap: onTap,
      backgroundColor: backgroundColor ?? (isDestructive ? Colors.red : null),
      foregroundColor: foregroundColor ?? (isDestructive ? Colors.white : null),
      isDestructive: isDestructive,
      requiresConfirmation: true,
      confirmationTitle: confirmTitle,
      confirmationContent: confirmContent,
    ));
    return this;
  }

  /// 構建 Action Bar
  Widget build(
    BuildContext context, {
    bool showStatusBar = false,
    TaskStatus? taskStatus,
    String? statusDisplayName,
    double? progressRatio,
    Color? backgroundColor,
    String? colorScheme, // 新增配色方案參數
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStatusBar && taskStatus != null)
          DynamicActionBar(
            taskStatus: taskStatus,
            userRole: UserRole.participant, // 這裡只用於狀態顯示
            actionCallbacks: const {},
            showStatusBar: true,
            statusDisplayName: statusDisplayName,
            progressRatio: progressRatio,
            colorScheme: colorScheme, // 傳遞配色方案
          ),
        if (_actions.isNotEmpty)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor ??
                      Theme.of(context).colorScheme.surface.withOpacity(0.8),
                ),
                padding: const EdgeInsets.only(top: 12, bottom: 10),
                child: Row(
                  children: _actions
                      .map(
                        (action) => Expanded(
                          child: DynamicActionBar(
                            taskStatus: TaskStatus.open, // 佔位符
                            userRole: UserRole.participant, // 佔位符
                            actionCallbacks: {},
                            showStatusBar: false,
                            colorScheme: colorScheme, // 傳遞配色方案
                          )._buildActionButton(context, action),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 清空動作
  ActionBarBuilder clear() {
    _actions.clear();
    return this;
  }

  /// 獲取動作列表
  List<ActionBarAction> get actions => List.unmodifiable(_actions);
}
