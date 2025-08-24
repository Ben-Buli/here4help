import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/providers/permission_provider.dart';
import 'package:here4help/services/permission_service.dart';

class PermissionUnverifiedPage extends StatelessWidget {
  final String? message;
  final String? currentPath;

  const PermissionUnverifiedPage({
    super.key,
    this.message,
    this.currentPath,
  });

  /// 智能返回邏輯
  /// 優先返回用戶之前訪問的頁面，如果沒有則返回首頁
  void _handleSmartBack(BuildContext context) {
    final state = GoRouterState.of(context);
    final fromPath = state.uri.queryParameters['from']; // 真正的上一頁
    final blockedPath = state.uri.queryParameters['blocked']; // 被阻擋的頁面

    debugPrint('🔙 智能返回: fromPath=$fromPath, blockedPath=$blockedPath');

    if (fromPath != null && fromPath.isNotEmpty) {
      // 檢查上一頁是否為基本頁面（permission = 0）
      if (_isBasicPage(fromPath)) {
        debugPrint('🔙 返回到基本頁面: $fromPath');
        context.go(fromPath);
        return;
      }
    }

    // 如果沒有有效的上一頁，返回首頁
    debugPrint('🔙 返回到首頁');
    context.go('/home');
  }

  /// 檢查是否為基本頁面（permission = 0）
  bool _isBasicPage(String path) {
    final basicPages = ['/home', '/account', '/task'];
    return basicPages.contains(path);
  }

  @override
  Widget build(BuildContext context) {
    // 從 GoRouterState 獲取當前路徑和查詢參數
    final state = GoRouterState.of(context);

    // 從 Provider 獲取用戶權限狀態
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    final userPermission = permissionProvider.permission;

    // 使用傳入的訊息或從權限狀態生成
    final displayMessage =
        message ?? PermissionService.getPermissionStatus(userPermission);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 403 圖示
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.notifications_active,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          const SizedBox(height: 32),

          // 標題
          Text(
            'User Unverified',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 16),

          // 副標題
          Text(
            'After verification, you can access all features.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 24),

          // 錯誤訊息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayMessage,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // // 被阻擋的路徑資訊
          // Container(
          //   padding: const EdgeInsets.all(12),
          //   decoration: BoxDecoration(
          //     color: Colors.grey.shade50,
          //     borderRadius: BorderRadius.circular(8),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(
          //         Icons.location_on_outlined,
          //         color: Colors.grey.shade600,
          //         size: 20,
          //       ),
          //       const SizedBox(width: 8),
          //       Expanded(
          //         child: Text(
          //           'Blocked path: $fromPath',
          //           style: TextStyle(
          //             color: Colors.grey.shade600,
          //             fontSize: 14,
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          // const SizedBox(height: 40),

          // 按鈕區域

          Column(
            children: [
              // 智能返回按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleSmartBack(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 返回首頁按鈕
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Home'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 聯繫客服按鈕
              TextButton.icon(
                onPressed: () {
                  // 前往客服頁面
                  context.go('/account/support/contact');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact support feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact Support'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
              ),
              // 用戶安全設置按鈕
              TextButton.icon(
                onPressed: () {
                  // 前往用戶安全設置頁面
                  context.go('/account/security');
                },
                icon: const Icon(Icons.security),
                label: const Text('Security Settings'),
              )
            ],
          ),
        ],
      ),
    );
  }
}
