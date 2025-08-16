import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:here4help/services/notification_service.dart';

/// 未讀標記時機測試頁面
/// 用於驗證執行時間差修復是否有效
class UnreadTimingTestPage extends StatefulWidget {
  const UnreadTimingTestPage({super.key});

  @override
  State<UnreadTimingTestPage> createState() => _UnreadTimingTestPageState();
}

class _UnreadTimingTestPageState extends State<UnreadTimingTestPage> {
  Map<String, dynamic> _testResults = {};
  bool _isLoading = false;
  StreamSubscription<Map<String, int>>? _unreadSubscription;

  @override
  void initState() {
    super.initState();
    _runTimingTest();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _runTimingTest() async {
    setState(() {
      _isLoading = true;
      _testResults = {};
    });

    try {
      final center = NotificationCenter();

      // 測試 1: 檢查初始化狀態
      _testResults['initialization_check'] = {
        'is_initialized': center.isInitialized,
        'service_type': center.service.runtimeType.toString(),
        'is_placeholder': center.service is NotificationServicePlaceholder,
      };

      // 測試 2: 等待未讀數據載入
      final startTime = DateTime.now();
      await center.waitForUnreadData(timeout: const Duration(seconds: 5));
      final waitTime = DateTime.now().difference(startTime).inMilliseconds;

      _testResults['wait_result'] = {
        'wait_time_ms': waitTime,
        'final_initialized': center.isInitialized,
        'final_service_type': center.service.runtimeType.toString(),
      };

      // 測試 3: 訂閱未讀數據流
      _unreadSubscription = center.byRoomStream.listen((data) {
        if (mounted) {
          setState(() {
            _testResults['stream_data'] = {
              'room_count': data.length,
              'total_unread':
                  data.values.fold<int>(0, (sum, count) => sum + count),
              'sample_rooms': data.entries
                  .take(3)
                  .map((e) => '${e.key}: ${e.value}')
                  .toList(),
              'received_at': DateTime.now().toIso8601String(),
            };
          });
        }
      });

      // 測試 4: 強制刷新快照
      await center.service.refreshSnapshot();

      _testResults['snapshot_refresh'] = {
        'completed': true,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 等待一段時間讓 Stream 數據到達
      await Future.delayed(const Duration(milliseconds: 1000));
    } catch (e) {
      _testResults['error'] = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('未讀標記時機測試'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runTimingTest,
            tooltip: '重新測試',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTestSummary(),
                  const SizedBox(height: 16),
                  _buildDetailedResults(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildTestSummary() {
    final initCheck =
        _testResults['initialization_check'] as Map<String, dynamic>?;
    final waitResult = _testResults['wait_result'] as Map<String, dynamic>?;
    final streamData = _testResults['stream_data'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('測試摘要',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (initCheck != null) ...[
              Text(
                  '初始狀態: ${initCheck['is_initialized'] ? '✅ 已初始化' : '❌ 未初始化'}'),
              Text('服務類型: ${initCheck['service_type']}'),
            ],
            if (waitResult != null) ...[
              Text('等待時間: ${waitResult['wait_time_ms']}ms'),
              Text(
                  '最終狀態: ${waitResult['final_initialized'] ? '✅ 已初始化' : '❌ 未初始化'}'),
            ],
            if (streamData != null) ...[
              Text('房間數量: ${streamData['room_count']}'),
              Text('總未讀數: ${streamData['total_unread']}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedResults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('詳細結果',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  _formatJson(_testResults),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('測試操作',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _runTimingTest,
                  child: const Text('重新測試'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await NotificationCenter().service.refreshSnapshot();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('快照已刷新')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('刷新失敗: $e'),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('刷新快照'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/chat');
                  },
                  child: const Text('前往聊天頁面'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatJson(dynamic obj) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(obj);
  }
}
