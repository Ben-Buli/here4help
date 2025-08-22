import 'package:flutter/material.dart';
import '../services/socket/socket_reconnect_manager.dart';
import '../services/chat/offline_chat_service.dart';
import '../services/offline/offline_manager.dart';

/// Socket 重連功能測試頁面
class SocketReconnectTestPage extends StatefulWidget {
  const SocketReconnectTestPage({Key? key}) : super(key: key);

  @override
  State<SocketReconnectTestPage> createState() =>
      _SocketReconnectTestPageState();
}

class _SocketReconnectTestPageState extends State<SocketReconnectTestPage> {
  final SocketReconnectManager _socketManager = SocketReconnectManager.instance;
  final OfflineChatService _chatService = OfflineChatService.instance;
  final OfflineManager _offlineManager = OfflineManager.instance;

  String _testResults = '';
  bool _isRunning = false;

  // 測試配置
  static const String testServerUrl = 'ws://localhost:3001';
  static const int testChatRoomId = 1;

  @override
  void initState() {
    super.initState();
    _socketManager.addListener(_onSocketStatusChanged);
    _chatService.addListener(_onChatServiceChanged);
    _offlineManager.addListener(_onOfflineStatusChanged);

    _setupSocketEventListeners();
  }

  @override
  void dispose() {
    _socketManager.removeListener(_onSocketStatusChanged);
    _chatService.removeListener(_onChatServiceChanged);
    _offlineManager.removeListener(_onOfflineStatusChanged);
    super.dispose();
  }

  void _onSocketStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onChatServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onOfflineStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setupSocketEventListeners() {
    _socketManager.on('connected', (data) {
      _addTestResult('✅ Socket 連接成功');
    });

    _socketManager.on('disconnected', (reason) {
      _addTestResult('❌ Socket 連接斷開: $reason');
    });

    _socketManager.on('connect_error', (error) {
      _addTestResult('❌ Socket 連接錯誤: $error');
    });

    _socketManager.on('reconnect_attempt', (attemptNumber) {
      _addTestResult('🔄 Socket 重連嘗試: $attemptNumber');
    });

    _socketManager.on('reconnected', (attemptNumber) {
      _addTestResult('✅ Socket 重連成功，嘗試次數: $attemptNumber');
    });

    _socketManager.on('reconnect_failed', (data) {
      _addTestResult('❌ Socket 重連失敗');
    });

    _socketManager.on('max_reconnect_attempts_reached', (attempts) {
      _addTestResult('⚠️ 達到最大重連次數: $attempts');
    });
  }

  void _addTestResult(String message) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now().toString().substring(11, 19);
        _testResults += '[$timestamp] $message\n';
      });
    }
  }

  Future<void> _runConnectionTest() async {
    setState(() {
      _isRunning = true;
      _testResults = '';
    });

    _addTestResult('🧪 開始 Socket 連接測試');
    _addTestResult('=' * 40);

    try {
      // 測試1: 基本連接
      _addTestResult('\n1. 測試基本連接');
      _addTestResult('-' * 30);

      await _socketManager.connect(testServerUrl);
      await Future.delayed(const Duration(seconds: 3));

      // 測試2: 加入聊天室
      if (_socketManager.isConnected) {
        _addTestResult('\n2. 測試加入聊天室');
        _addTestResult('-' * 30);

        await _chatService.joinChatRoom(testChatRoomId);
        await Future.delayed(const Duration(seconds: 2));

        // 測試3: 發送訊息
        _addTestResult('\n3. 測試發送訊息');
        _addTestResult('-' * 30);

        final messageId = await _chatService.sendMessage(
          chatRoomId: testChatRoomId,
          content: '測試訊息 - ${DateTime.now()}',
        );
        _addTestResult('📤 發送測試訊息: $messageId');

        await Future.delayed(const Duration(seconds: 2));
      }

      // 測試4: 手動斷開連接
      _addTestResult('\n4. 測試手動斷開連接');
      _addTestResult('-' * 30);

      _socketManager.disconnect();
      await Future.delayed(const Duration(seconds: 2));

      _addTestResult('\n✅ 連接測試完成！');
    } catch (e) {
      _addTestResult('\n❌ 連接測試失敗: $e');
    }

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runReconnectTest() async {
    setState(() {
      _isRunning = true;
      _testResults = '';
    });

    _addTestResult('🧪 開始 Socket 重連測試');
    _addTestResult('=' * 40);

    try {
      // 測試1: 連接到無效伺服器（觸發重連）
      _addTestResult('\n1. 測試連接到無效伺服器');
      _addTestResult('-' * 30);

      await _socketManager.connect('ws://invalid-server:9999');

      // 等待幾次重連嘗試
      await Future.delayed(const Duration(seconds: 15));

      // 測試2: 手動重連到正確伺服器
      _addTestResult('\n2. 測試手動重連到正確伺服器');
      _addTestResult('-' * 30);

      _socketManager.disconnect();
      await Future.delayed(const Duration(seconds: 2));

      await _socketManager.connect(testServerUrl);
      await Future.delayed(const Duration(seconds: 5));

      _addTestResult('\n✅ 重連測試完成！');
    } catch (e) {
      _addTestResult('\n❌ 重連測試失敗: $e');
    }

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runOfflineTest() async {
    setState(() {
      _isRunning = true;
      _testResults = '';
    });

    _addTestResult('🧪 開始離線模式測試');
    _addTestResult('=' * 40);

    try {
      // 測試1: 在線狀態下發送訊息
      _addTestResult('\n1. 測試在線狀態下發送訊息');
      _addTestResult('-' * 30);

      if (!_socketManager.isConnected) {
        await _socketManager.connect(testServerUrl);
        await Future.delayed(const Duration(seconds: 3));
      }

      if (_socketManager.isConnected) {
        await _chatService.joinChatRoom(testChatRoomId);

        final messageId1 = await _chatService.sendMessage(
          chatRoomId: testChatRoomId,
          content: '在線訊息 - ${DateTime.now()}',
        );
        _addTestResult('📤 在線發送訊息: $messageId1');

        await Future.delayed(const Duration(seconds: 2));
      }

      // 測試2: 模擬離線狀態
      _addTestResult('\n2. 測試離線狀態下發送訊息');
      _addTestResult('-' * 30);

      _socketManager.disconnect();
      await Future.delayed(const Duration(seconds: 2));

      // 發送離線訊息
      final messageId2 = await _chatService.sendMessage(
        chatRoomId: testChatRoomId,
        content: '離線訊息 - ${DateTime.now()}',
      );
      _addTestResult('📤 離線發送訊息（將加入佇列）: $messageId2');

      final messageId3 = await _chatService.sendMessage(
        chatRoomId: testChatRoomId,
        content: '離線訊息2 - ${DateTime.now()}',
      );
      _addTestResult('📤 離線發送訊息2（將加入佇列）: $messageId3');

      // 顯示待發送統計
      final stats = _chatService.getPendingMessageStats();
      _addTestResult('📊 待發送訊息統計: ${stats.toString()}');

      // 測試3: 重新連接並處理佇列
      _addTestResult('\n3. 測試重新連接並處理佇列');
      _addTestResult('-' * 30);

      await _socketManager.connect(testServerUrl);
      await Future.delayed(const Duration(seconds: 5));

      // 檢查佇列是否已處理
      final finalStats = _chatService.getPendingMessageStats();
      _addTestResult('📊 重連後統計: ${finalStats.toString()}');

      _addTestResult('\n✅ 離線模式測試完成！');
    } catch (e) {
      _addTestResult('\n❌ 離線模式測試失敗: $e');
    }

    setState(() {
      _isRunning = false;
    });
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Socket 重連測試'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearResults,
            icon: const Icon(Icons.clear),
            tooltip: '清除結果',
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
                      'Socket 狀態',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),

                    // Socket 連接狀態
                    Row(
                      children: [
                        Icon(
                          _socketManager.isConnected
                              ? Icons.link
                              : Icons.link_off,
                          color: _socketManager.isConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_socketManager.getConnectionStatusText()),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // 網路狀態
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

                    // 重連統計
                    if (_socketManager.reconnectAttempts > 0)
                      Text(
                        '重連嘗試: ${_socketManager.reconnectAttempts}/${SocketReconnectManager.maxReconnectAttempts}',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    // 待發送訊息統計
                    Builder(
                      builder: (context) {
                        final stats = _chatService.getPendingMessageStats();
                        if (stats['queueSize'] > 0) {
                          return Text(
                            '待發送訊息: ${stats['queueSize']} 筆',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 測試按鈕
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runConnectionTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('連接測試'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runReconnectTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重連測試'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runOfflineTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('離線測試'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 手動控制按鈕
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _socketManager.connect(testServerUrl);
                    },
                    child: const Text('手動連接'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _socketManager.disconnect();
                    },
                    child: const Text('手動斷開'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _socketManager.manualReconnect();
                    },
                    child: const Text('手動重連'),
                  ),
                ),
              ],
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
                      Row(
                        children: [
                          Text(
                            '測試結果',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (_isRunning)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _testResults.isEmpty
                                ? '選擇上方測試按鈕開始測試'
                                : _testResults,
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
