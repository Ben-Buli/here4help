import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/providers/permission_provider.dart';
import 'package:here4help/auth/services/user_service.dart';

class PermissionUnverifiedPage extends StatefulWidget {
  final String? message;
  final String? currentPath;

  const PermissionUnverifiedPage({
    super.key,
    this.message,
    this.currentPath,
  });

  @override
  State<PermissionUnverifiedPage> createState() =>
      _PermissionUnverifiedPageState();
}

class _PermissionUnverifiedPageState extends State<PermissionUnverifiedPage> {
  bool _isRefreshing = false;
  final String _refreshButtonText = 'Try Again';
  String _buttonText = 'Try Again';
  Color? _buttonBackgroundColor;
  Color? _buttonForegroundColor;

  /// 重設按鈕樣式
  void _resetButtonStyle() {
    if (mounted) {
      setState(() {
        _buttonText = _refreshButtonText;
        _buttonBackgroundColor = null;
        _buttonForegroundColor = null;
        _isRefreshing = false;
      });
    }
  }

  /// 設置按鈕為成功狀態
  void _setButtonSuccess() {
    if (mounted) {
      setState(() {
        _buttonText = 'Success! Redirecting...';
        _buttonBackgroundColor = const Color.fromARGB(255, 89, 140, 91);
        _buttonForegroundColor = Colors.white;
        _isRefreshing = false;
      });
    }
  }

  /// 設置按鈕為失敗狀態
  void _setButtonError(String errorMessage) {
    if (mounted) {
      setState(() {
        _buttonText = '❌ $errorMessage';
        _buttonBackgroundColor = const Color.fromARGB(255, 180, 65, 56);
        _buttonForegroundColor = Colors.white;
        _isRefreshing = false;
      });
    }
  }

  /// 手動刷新用戶資訊和權限
  Future<void> _refreshUserData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _buttonText = 'Updating...';
    });

    try {
      // 1. 刷新 UserService 中的用戶資料
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.refreshUserInfo();

      // 2. 刷新 PermissionProvider 中的權限狀態
      final permissionProvider =
          Provider.of<PermissionProvider>(context, listen: false);

      // 如果用戶資料刷新成功，同步權限狀態
      if (userService.currentUser != null) {
        permissionProvider
            .updatePermission(userService.currentUser!.permission);

        // 檢查權限是否已經足夠，如果是則自動返回到被阻擋的頁面
        if (userService.currentUser!.permission > 0) {
          _setButtonSuccess();

          // 延遲一下讓用戶看到成功訊息，然後返回
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _returnToBlockedPage(context);
          }
          return;
        }
      }

      // 如果權限仍然不足，顯示更新完成訊息
      _setButtonError('No permission change');

      // 3秒後重設按鈕樣式
      await Future.delayed(const Duration(seconds: 3));
      _resetButtonStyle();
    } catch (e) {
      debugPrint('❌ 刷新用戶資料失敗: $e');
      _setButtonError('Update failed');

      // 3秒後重設按鈕樣式
      await Future.delayed(const Duration(seconds: 3));
      _resetButtonStyle();
    }
  }

  /// 返回到被阻擋的頁面（用戶原本想要進入的頁面）
  void _returnToBlockedPage(BuildContext context) {
    final state = GoRouterState.of(context);
    final blockedPath = state.uri.queryParameters['blocked']; // 被阻擋的頁面
    final fromPath = state.uri.queryParameters['from']; // 來源頁面

    debugPrint('🔍 [PermissionUnverified] 當前 URL: ${state.uri}');
    debugPrint('🔍 [PermissionUnverified] 查詢參數: ${state.uri.queryParameters}');
    debugPrint('🔙 [PermissionUnverified] blocked 參數: $blockedPath');
    debugPrint('🔙 [PermissionUnverified] from 參數: $fromPath');

    // 優先使用 blocked 參數，其次使用 from 參數
    final targetPath = blockedPath ?? fromPath;

    if (targetPath != null &&
        targetPath.isNotEmpty &&
        targetPath != '/permission-unverified') {
      debugPrint('🔙 導航到目標頁面: $targetPath');
      context.go(targetPath);
    } else {
      // 如果沒有有效的目標頁面，返回首頁
      debugPrint('🔙 沒有有效的目標頁面資訊，返回首頁');
      context.go('/home');
    }
  }

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
    // 從 Provider 獲取用戶權限狀態
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    final userPermission = permissionProvider.permission;

    // 使用傳入的訊息或從權限狀態生成
    const displayMessage = 'After verification, you can access all features.';
    // widget.message ?? PermissionService.getPermissionStatus(userPermission);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom -
                48,
          ),
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

              SizedBox(height: MediaQuery.of(context).size.height * 0.04),

              // 標題
              Text(
                'User Unverified',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.02),

              SizedBox(height: MediaQuery.of(context).size.height * 0.03),

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

              SizedBox(height: MediaQuery.of(context).size.height * 0.03),

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
                  // 手動刷新按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isRefreshing ? null : _refreshUserData,
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(_buttonBackgroundColor == Colors.green
                              ? Icons.check
                              : _buttonBackgroundColor == Colors.red
                                  ? Icons.error
                                  : Icons.refresh),
                      label: Text(_buttonText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonBackgroundColor ??
                            Theme.of(context).colorScheme.tertiaryContainer,
                        foregroundColor: _buttonForegroundColor ??
                            Theme.of(context).colorScheme.tertiary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 智能返回按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleSmartBack(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
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
        ),
      ),
    );
  }
}
