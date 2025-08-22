import 'package:flutter/material.dart';
import '../accessibility/accessible_text.dart';
import '../../services/accessibility/semantics_service.dart';

/// 空狀態組件
/// 提供統一的空狀態 UI 模板
class EmptyStateWidget extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double? iconSize;

  const EmptyStateWidget({
    Key? key,
    this.icon,
    this.iconAsset,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize = 80.0,
  }) : super(key: key);

  /// 預設的空狀態樣式
  static const EmptyStateWidget noTasks = EmptyStateWidget(
    icon: Icons.assignment_outlined,
    title: '暫無任務',
    description: '目前沒有任務，快去發布或應徵任務吧！',
    actionLabel: '瀏覽任務',
  );

  static const EmptyStateWidget noChats = EmptyStateWidget(
    icon: Icons.chat_bubble_outline,
    title: '暫無聊天',
    description: '還沒有聊天記錄，開始應徵任務來建立聊天吧！',
    actionLabel: '瀏覽任務',
  );

  static const EmptyStateWidget noNotifications = EmptyStateWidget(
    icon: Icons.notifications_none,
    title: '暫無通知',
    description: '目前沒有新通知',
  );

  static const EmptyStateWidget noHistory = EmptyStateWidget(
    icon: Icons.history,
    title: '暫無歷史記錄',
    description: '還沒有完成的任務記錄',
  );

  static const EmptyStateWidget noFavorites = EmptyStateWidget(
    icon: Icons.favorite_border,
    title: '暫無收藏',
    description: '還沒有收藏的任務，去收藏一些感興趣的任務吧！',
    actionLabel: '瀏覽任務',
  );

  static const EmptyStateWidget noSearchResults = EmptyStateWidget(
    icon: Icons.search_off,
    title: '沒有搜尋結果',
    description: '試試其他關鍵字或調整篩選條件',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticsService = SemanticsService.instance;

    return semanticsService.annotateEmptyState(
      emptyMessage: description != null ? '$title. $description' : title,
      onAction: onAction,
      actionLabel: actionLabel,
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
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 16,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    final color = iconColor ?? theme.colorScheme.onSurface.withOpacity(0.3);
    
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
        Icons.inbox_outlined,
        size: iconSize,
        color: color,
      );
    }
  }
}

/// 空狀態建構器
class EmptyStateBuilder {
  static Widget buildTasksEmpty({VoidCallback? onBrowseTasks}) {
    return EmptyStateWidget(
      icon: Icons.assignment_outlined,
      title: '暫無任務',
      description: '目前沒有任務，快去發布或應徵任務吧！',
      actionLabel: onBrowseTasks != null ? '瀏覽任務' : null,
      onAction: onBrowseTasks,
    );
  }

  static Widget buildChatsEmpty({VoidCallback? onBrowseTasks}) {
    return EmptyStateWidget(
      icon: Icons.chat_bubble_outline,
      title: '暫無聊天',
      description: '還沒有聊天記錄，開始應徵任務來建立聊天吧！',
      actionLabel: onBrowseTasks != null ? '瀏覽任務' : null,
      onAction: onBrowseTasks,
    );
  }

  static Widget buildSearchEmpty({
    required String query,
    VoidCallback? onClearSearch,
  }) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: '沒有找到相關結果',
      description: '找不到與「$query」相關的內容，試試其他關鍵字吧',
      actionLabel: onClearSearch != null ? '清除搜尋' : null,
      onAction: onClearSearch,
    );
  }

  static Widget buildNetworkEmpty({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.cloud_off,
      title: '網路連線問題',
      description: '請檢查網路連線後重試',
      actionLabel: onRetry != null ? '重試' : null,
      onAction: onRetry,
    );
  }
}
