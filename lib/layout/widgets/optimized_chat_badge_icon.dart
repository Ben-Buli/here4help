import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/services/unified_unread_manager.dart';

/// 優化後的聊天徽章圖標 - 使用統一未讀管理器
class OptimizedChatBadgeIcon extends StatelessWidget {
  const OptimizedChatBadgeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedUnreadManager>(
      builder: (context, unreadManager, child) {
        final shouldShowBadge = unreadManager.shouldShowNavigationBadge;

        // 調試信息（可以在生產環境中移除）
        debugPrint('🔍 [OptimizedChatBadgeIcon] 底部導航紅點狀態: $shouldShowBadge');
        debugPrint('  - 總未讀數: ${unreadManager.totalUnreadCount}');

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.message),
            if (shouldShowBadge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 可選：顯示具體未讀數字的版本
class DetailedChatBadgeIcon extends StatelessWidget {
  const DetailedChatBadgeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedUnreadManager>(
      builder: (context, unreadManager, child) {
        final totalUnread = unreadManager.totalUnreadCount;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.message),
            if (totalUnread > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    totalUnread > 99 ? '99+' : '$totalUnread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
