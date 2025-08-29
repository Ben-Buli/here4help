import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/services/chat_cache_manager.dart';

class UpdateStatusIndicator extends StatefulWidget {
  const UpdateStatusIndicator({super.key});

  @override
  State<UpdateStatusIndicator> createState() => _UpdateStatusIndicatorState();
}

class _UpdateStatusIndicatorState extends State<UpdateStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatCacheManager>(
      builder: (context, cacheManager, child) {
        // 如果沒有更新訊息，不顯示
        if (cacheManager.updateMessage == null) {
          return const SizedBox.shrink();
        }

        // 根據更新狀態選擇顏色和圖標
        Color backgroundColor;
        Color textColor;
        IconData icon;

        if (cacheManager.isUpdating) {
          backgroundColor = Colors.blue;
          textColor = Colors.white;
          icon = Icons.sync;
        } else if (cacheManager.hasNewData) {
          backgroundColor = Colors.green;
          textColor = Colors.white;
          icon = Icons.check_circle;
        } else {
          backgroundColor = Colors.grey;
          textColor = Colors.white;
          icon = Icons.info;
        }

        // 觸發動畫
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animationController.forward();
        });

        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 圖標
                  Icon(
                    icon,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),

                  // 文字
                  Flexible(
                    child: Text(
                      cacheManager.updateMessage!,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // 如果是更新中，顯示旋轉圖標
                  if (cacheManager.isUpdating) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 更新狀態橫幅（全寬顯示）
class UpdateStatusBanner extends StatelessWidget {
  const UpdateStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatCacheManager>(
      builder: (context, cacheManager, child) {
        debugPrint('🔍 [UpdateStatusBanner] build() 開始');
        debugPrint('  - updateMessage: ${cacheManager.updateMessage}');
        debugPrint('  - isUpdating: ${cacheManager.isUpdating}');
        debugPrint('  - hasNewData: ${cacheManager.hasNewData}');
        debugPrint('  - lastUpdate: ${cacheManager.lastUpdate}');
        debugPrint('  - isCacheValid: ${cacheManager.isCacheValid}');
        debugPrint('  - isCacheEmpty: ${cacheManager.isCacheEmpty}');

        // 如果沒有更新訊息，不顯示
        if (cacheManager.updateMessage == null) {
          debugPrint('🔍 [UpdateStatusBanner] 沒有更新訊息，不顯示');
          return const SizedBox.shrink();
        }

        debugPrint('🔍 [UpdateStatusBanner] 準備顯示狀態橫幅');

        // 根據更新狀態選擇顏色
        Color backgroundColor;
        Color textColor;
        IconData icon;

        try {
          if (cacheManager.isUpdating) {
            backgroundColor = Colors.blue.shade100;
            textColor = Colors.blue.shade800;
            icon = Icons.sync;
            debugPrint('🔍 [UpdateStatusBanner] 狀態：更新中 (藍色)');
          } else if (cacheManager.hasNewData) {
            backgroundColor = Colors.green.shade100;
            textColor = Colors.green.shade800;
            icon = Icons.check_circle;
            debugPrint('🔍 [UpdateStatusBanner] 狀態：有新數據 (綠色)');
          } else {
            backgroundColor = Colors.grey.shade100;
            textColor = Colors.grey.shade800;
            icon = Icons.info;
            debugPrint('🔍 [UpdateStatusBanner] 狀態：一般信息 (灰色)');
          }
        } catch (e) {
          debugPrint('❌ [UpdateStatusBanner] 狀態顏色設定失敗: $e');
          // 使用預設顏色作為後備
          backgroundColor = Colors.grey.shade100;
          textColor = Colors.grey.shade800;
          icon = Icons.info;
        }

        debugPrint('🔍 [UpdateStatusBanner] 開始構建 Container');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: textColor.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 圖標
              Icon(
                icon,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 12),

              // 文字
              Expanded(
                child: Builder(
                  builder: (context) {
                    try {
                      final message = cacheManager.updateMessage!;
                      debugPrint('🔍 [UpdateStatusBanner] 顯示訊息: $message');

                      return Text(
                        message,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    } catch (e) {
                      debugPrint('❌ [UpdateStatusBanner] 顯示訊息失敗: $e');
                      return const Text(
                        '更新狀態顯示錯誤',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                  },
                ),
              ),

              // 如果是更新中，顯示旋轉圖標
              if (cacheManager.isUpdating)
                Builder(
                  builder: (context) {
                    try {
                      debugPrint('🔍 [UpdateStatusBanner] 顯示更新中圖標');
                      return SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      );
                    } catch (e) {
                      debugPrint('❌ [UpdateStatusBanner] 顯示更新中圖標失敗: $e');
                      return const SizedBox(width: 16, height: 16);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
