import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:here4help/chat/utils/support_action_bar_config.dart';

/// 客服聊天室動態 Action Bar 組件
/// 專門用於客服聊天室，根據客服事件狀態和用戶角色動態顯示操作按鈕
class SupportDynamicActionBar extends StatelessWidget {
  final UserRole userRole;
  final Map<String, VoidCallback> actionCallbacks;
  final SupportStatus? supportStatus;
  final bool showStatusBar;
  final String? statusDisplayName;
  final Color? backgroundColor;

  const SupportDynamicActionBar({
    super.key,
    required this.userRole,
    required this.actionCallbacks,
    this.supportStatus,
    this.showStatusBar = true,
    this.statusDisplayName,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final actions = SupportActionBarConfigManager.getActionsForSupportStatus(
      userRole: userRole,
      actionCallbacks: actionCallbacks,
      supportStatus: supportStatus,
    );

    if (kDebugMode && actions.isEmpty) {
      debugPrint(
          '⚠️ [SupportDynamicActionBar] No actions available for $supportStatus/$userRole');
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
    final statusColor =
        SupportActionBarConfigManager.getSupportStatusColor(supportStatus);
    final statusIcon =
        SupportActionBarConfigManager.getSupportStatusIcon(supportStatus);

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
            child: Text(
              statusDisplayName ??
                  SupportActionBarConfigManager.getSupportStatusName(
                      supportStatus),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 構建 Action Bar
  Widget _buildActionBar(BuildContext context, List<ActionBarAction> actions) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(context),
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

  /// 獲取背景顏色
  Color _getBackgroundColor(BuildContext context) {
    if (backgroundColor != null) {
      return backgroundColor!;
    }

    // 根據客服狀態獲取對應的背景色
    if (supportStatus != null) {
      final statusColor =
          SupportActionBarConfigManager.getSupportStatusColor(supportStatus);
      return statusColor.withOpacity(0.3); // 使用狀態顏色但降低透明度以保持玻璃效果
    }

    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;

    if (appBarTheme.backgroundColor != null) {
      return appBarTheme.backgroundColor!.withOpacity(0.8);
    }

    return theme.colorScheme.surface.withOpacity(0.8);
  }
}

/// Support Action Bar 構建器
/// 提供更靈活的構建方式
class SupportActionBarBuilder {
  final List<ActionBarAction> _actions = [];

  /// 添加動作
  SupportActionBarBuilder addAction(ActionBarAction action) {
    _actions.add(action);
    return this;
  }

  /// 添加簡單動作
  SupportActionBarBuilder addSimpleAction({
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
  SupportActionBarBuilder addConfirmAction({
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

  /// 構建 Support Action Bar
  Widget build(
    BuildContext context, {
    bool showStatusBar = false,
    SupportStatus? supportStatus,
    String? statusDisplayName,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStatusBar && supportStatus != null)
          SupportDynamicActionBar(
            userRole: UserRole.customer, // 這裡只用於狀態顯示
            actionCallbacks: const {},
            supportStatus: supportStatus,
            showStatusBar: true,
            statusDisplayName: statusDisplayName,
            backgroundColor: backgroundColor,
          ),
        if (_actions.isNotEmpty)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor ??
                      _getSupportStatusBackgroundColor(context, supportStatus),
                ),
                padding: const EdgeInsets.only(top: 12, bottom: 10),
                child: Row(
                  children: _actions
                      .map(
                        (action) => Expanded(
                          child: SupportDynamicActionBar(
                            userRole: UserRole.customer, // 佔位符
                            actionCallbacks: const {},
                            showStatusBar: false,
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
  SupportActionBarBuilder clear() {
    _actions.clear();
    return this;
  }

  /// 獲取動作列表
  List<ActionBarAction> get actions => List.unmodifiable(_actions);

  /// 根據客服狀態獲取背景顏色的靜態方法
  static Color _getSupportStatusBackgroundColor(
      BuildContext context, SupportStatus? supportStatus) {
    if (supportStatus != null) {
      final statusColor =
          SupportActionBarConfigManager.getSupportStatusColor(supportStatus);
      return statusColor.withOpacity(0.3); // 使用狀態顏色但降低透明度以保持玻璃效果
    }

    return Theme.of(context).colorScheme.surface.withOpacity(0.8);
  }
}
