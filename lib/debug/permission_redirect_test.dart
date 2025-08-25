import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 權限重定向測試工具
/// 用於測試被阻擋頁面的回溯功能
class PermissionRedirectTest {
  /// 測試未驗證用戶重定向
  static void testUnverifiedRedirect(BuildContext context) {
    debugPrint('🧪 [測試] 模擬未驗證用戶訪問 /chat 頁面');

    // 模擬訪問需要權限的頁面
    const testPath = '/chat';

    // 構建重定向 URL（模擬 PermissionGuard 的行為）
    final redirectUrl =
        '/permission-unverified?blocked=$testPath&from=$testPath';

    debugPrint('🧪 [測試] 重定向 URL: $redirectUrl');

    // 執行重定向
    context.go(redirectUrl);
  }

  /// 測試停權用戶重定向
  static void testSuspendedRedirect(BuildContext context) {
    debugPrint('🧪 [測試] 模擬停權用戶訪問 /task 頁面');

    // 模擬訪問需要權限的頁面
    const testPath = '/task';

    // 構建重定向 URL（模擬 PermissionGuard 的行為）
    final redirectUrl = '/permission-denied?blocked=$testPath&from=/home';

    debugPrint('🧪 [測試] 重定向 URL: $redirectUrl');

    // 執行重定向
    context.go(redirectUrl);
  }

  /// 測試複雜路徑重定向
  static void testComplexPathRedirect(BuildContext context) {
    debugPrint('🧪 [測試] 模擬訪問複雜路徑');

    // 模擬訪問帶查詢參數的頁面
    const testPath = '/task/detail?id=123&tab=info';

    // 需要對 URL 進行編碼
    final encodedPath = Uri.encodeComponent(testPath);
    final redirectUrl =
        '/permission-unverified?blocked=$encodedPath&from=/task';

    debugPrint('🧪 [測試] 複雜路徑重定向 URL: $redirectUrl');

    // 執行重定向
    context.go(redirectUrl);
  }

  /// 驗證查詢參數解析
  static void verifyQueryParameters(BuildContext context) {
    final state = GoRouterState.of(context);
    final currentUri = state.uri;

    debugPrint('🔍 [驗證] 當前完整 URI: $currentUri');
    debugPrint('🔍 [驗證] 路徑: ${currentUri.path}');
    debugPrint('🔍 [驗證] 查詢參數: ${currentUri.queryParameters}');

    final blocked = currentUri.queryParameters['blocked'];
    final from = currentUri.queryParameters['from'];

    debugPrint('🔍 [驗證] blocked 參數: $blocked');
    debugPrint('🔍 [驗證] from 參數: $from');

    if (blocked != null) {
      debugPrint('✅ [驗證] blocked 參數存在，可以正確回溯');
    } else if (from != null) {
      debugPrint('⚠️ [驗證] 只有 from 參數，使用備用方案');
    } else {
      debugPrint('❌ [驗證] 沒有任何回溯參數，將返回首頁');
    }
  }
}

/// 權限測試頁面 Widget
class PermissionTestPage extends StatelessWidget {
  const PermissionTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('權限重定向測試'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '權限重定向測試工具',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  PermissionRedirectTest.testUnverifiedRedirect(context),
              child: const Text('測試未驗證用戶重定向'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () =>
                  PermissionRedirectTest.testSuspendedRedirect(context),
              child: const Text('測試停權用戶重定向'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () =>
                  PermissionRedirectTest.testComplexPathRedirect(context),
              child: const Text('測試複雜路徑重定向'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  PermissionRedirectTest.verifyQueryParameters(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('驗證當前頁面參數'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              '使用說明：',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '1. 點擊測試按鈕會模擬權限重定向\n'
              '2. 在權限頁面點擊刷新按鈕測試回溯\n'
              '3. 查看控制台日誌了解詳細過程\n'
              '4. 驗證按鈕可以檢查當前頁面的參數',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
