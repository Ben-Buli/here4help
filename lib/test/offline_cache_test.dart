import 'package:flutter/material.dart';
import '../services/cache/cache_manager.dart';
import '../services/offline/offline_manager.dart';
import '../services/api/offline_task_api.dart';

/// 離線快取功能測試頁面
class OfflineCacheTestPage extends StatefulWidget {
  const OfflineCacheTestPage({Key? key}) : super(key: key);

  @override
  State<OfflineCacheTestPage> createState() => _OfflineCacheTestPageState();
}

class _OfflineCacheTestPageState extends State<OfflineCacheTestPage> {
  final CacheManager _cacheManager = CacheManager.instance;
  final OfflineManager _offlineManager = OfflineManager.instance;
  final OfflineTaskApi _taskApi = OfflineTaskApi();

  String _testResults = '';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _offlineManager.addListener(_onOfflineStatusChanged);
  }

  @override
  void dispose() {
    _offlineManager.removeListener(_onOfflineStatusChanged);
    super.dispose();
  }

  void _onOfflineStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _testResults = '';
    });

    final results = StringBuffer();

    try {
      results.writeln('🧪 離線快取功能測試開始');
      results.writeln('=' * 40);

      // 測試1: 快取管理器基本功能
      results.writeln('\n1. 測試快取管理器基本功能');
      results.writeln('-' * 30);
      await _testCacheManager(results);

      // 測試2: 離線管理器功能
      results.writeln('\n2. 測試離線管理器功能');
      results.writeln('-' * 30);
      await _testOfflineManager(results);

      // 測試3: 離線感知 API
      results.writeln('\n3. 測試離線感知 API');
      results.writeln('-' * 30);
      await _testOfflineApi(results);

      // 測試4: 快取統計
      results.writeln('\n4. 快取統計資訊');
      results.writeln('-' * 30);
      await _testCacheStats(results);

      results.writeln('\n✅ 所有測試完成！');
    } catch (e) {
      results.writeln('\n❌ 測試失敗: $e');
    }

    setState(() {
      _testResults = results.toString();
      _isRunning = false;
    });
  }

  Future<void> _testCacheManager(StringBuffer results) async {
    try {
      // 測試任務列表快取
      final testTasks = [
        {'id': 1, 'title': '測試任務1', 'description': '這是測試任務1'},
        {'id': 2, 'title': '測試任務2', 'description': '這是測試任務2'},
        {'id': 3, 'title': '測試任務3', 'description': '這是測試任務3'},
      ];

      await _cacheManager.cacheTaskList(
        listType: 'test',
        tasks: testTasks,
        expiry: const Duration(minutes: 5),
      );
      results.writeln('✅ 任務列表快取成功');

      // 測試快取讀取
      final cachedTasks = await _cacheManager.getCachedTaskList('test');
      if (cachedTasks != null && cachedTasks.length == 3) {
        results.writeln('✅ 任務列表讀取成功，共 ${cachedTasks.length} 筆');
      } else {
        results.writeln('❌ 任務列表讀取失敗');
      }

      // 測試使用者資料快取
      final testProfile = {
        'id': 123,
        'name': '測試使用者',
        'email': 'test@example.com',
      };

      await _cacheManager.cacheUserProfile(
        userId: 123,
        profile: testProfile,
        expiry: const Duration(minutes: 10),
      );
      results.writeln('✅ 使用者資料快取成功');

      // 測試使用者資料讀取
      final cachedProfile = await _cacheManager.getCachedUserProfile(123);
      if (cachedProfile != null && cachedProfile['name'] == '測試使用者') {
        results.writeln('✅ 使用者資料讀取成功');
      } else {
        results.writeln('❌ 使用者資料讀取失敗');
      }
    } catch (e) {
      results.writeln('❌ 快取管理器測試失敗: $e');
    }
  }

  Future<void> _testOfflineManager(StringBuffer results) async {
    try {
      // 測試網路狀態
      final isOnline = _offlineManager.isOnline;
      results.writeln('📶 網路狀態: ${isOnline ? "線上" : "離線"}');
      results.writeln('🔗 連接類型: ${_offlineManager.connectionType}');

      // 測試離線動作佇列
      await _offlineManager.addOfflineAction(
        type: 'test_action',
        endpoint: '/test/endpoint',
        data: {'test': 'data'},
      );
      results.writeln('✅ 離線動作添加成功');

      final queueSize = _offlineManager.offlineQueue.length;
      results.writeln('📋 離線佇列大小: $queueSize');

      // 測試離線統計
      final stats = _offlineManager.getOfflineStats();
      results.writeln('📊 離線統計: ${stats.toString()}');
    } catch (e) {
      results.writeln('❌ 離線管理器測試失敗: $e');
    }
  }

  Future<void> _testOfflineApi(StringBuffer results) async {
    try {
      // 測試任務列表 API（會使用快取或網路）
      final taskListResult = await _taskApi.getTaskList(
        page: 1,
        perPage: 10,
        forceRefresh: false,
      );

      if (taskListResult['success'] == true) {
        final fromCache = taskListResult['fromCache'] ?? false;
        final isOffline = taskListResult['isOffline'] ?? false;
        results.writeln('✅ 任務列表 API 調用成功');
        results.writeln('   來源: ${fromCache ? "快取" : "網路"}');
        results.writeln('   狀態: ${isOffline ? "離線" : "線上"}');

        if (taskListResult['warning'] != null) {
          results.writeln('   警告: ${taskListResult['warning']}');
        }
      } else {
        results.writeln('❌ 任務列表 API 調用失敗: ${taskListResult['message']}');
      }

      // 測試任務詳情 API
      final taskDetailResult = await _taskApi.getTaskDetail(1);

      if (taskDetailResult['success'] == true) {
        final fromCache = taskDetailResult['fromCache'] ?? false;
        results.writeln('✅ 任務詳情 API 調用成功');
        results.writeln('   來源: ${fromCache ? "快取" : "網路"}');
      } else {
        results.writeln('❌ 任務詳情 API 調用失敗: ${taskDetailResult['message']}');
      }
    } catch (e) {
      results.writeln('❌ 離線 API 測試失敗: $e');
    }
  }

  Future<void> _testCacheStats(StringBuffer results) async {
    try {
      // 清理過期快取
      await _cacheManager.cleanExpiredCache();
      results.writeln('🧹 過期快取清理完成');

      // 測試快取失效
      await _cacheManager.invalidateCache('test');
      results.writeln('🗑️ 測試快取失效完成');

      results.writeln('📈 快取系統測試完成');
    } catch (e) {
      results.writeln('❌ 快取統計測試失敗: $e');
    }
  }

  Future<void> _clearAllCache() async {
    try {
      await _cacheManager.clearAllCache();
      await _offlineManager.clearOfflineQueue();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('所有快取已清理'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清理快取失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('離線快取測試'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearAllCache,
            icon: const Icon(Icons.clear_all),
            tooltip: '清理所有快取',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 狀態資訊卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '系統狀態',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _offlineManager.isOnline
                              ? Icons.wifi
                              : Icons.wifi_off,
                          color: _offlineManager.isOnline
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(_offlineManager.getConnectionStatusText()),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('離線佇列: ${_offlineManager.offlineQueue.length} 個動作'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 測試按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runTests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isRunning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('測試進行中...'),
                        ],
                      )
                    : const Text('開始測試'),
              ),
            ),

            const SizedBox(height: 16),

            // 測試結果
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '測試結果',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _testResults.isEmpty ? '點擊上方按鈕開始測試' : _testResults,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
