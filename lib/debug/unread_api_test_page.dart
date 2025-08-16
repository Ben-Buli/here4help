import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:here4help/services/unread_service_v2.dart';

/// 未讀 API V2 測試頁面
/// 用於驗證新的角色型未讀計算 API 是否正常工作
class UnreadApiTestPage extends StatefulWidget {
  const UnreadApiTestPage({super.key});

  @override
  State<UnreadApiTestPage> createState() => _UnreadApiTestPageState();
}

class _UnreadApiTestPageState extends State<UnreadApiTestPage> {
  Map<String, dynamic> _testResults = {};
  bool _isLoading = false;
  String _selectedScope = 'all';

  @override
  void initState() {
    super.initState();
    _runBasicTests();
  }

  Future<void> _runBasicTests() async {
    setState(() {
      _isLoading = true;
      _testResults = {};
    });

    try {
      // 測試 1: 分別獲取各分頁未讀數
      final postedData =
          await UnreadServiceV2.getUnreadByScope(scope: 'posted');
      final myWorksData =
          await UnreadServiceV2.getUnreadByScope(scope: 'myworks');
      final allData = await UnreadServiceV2.getUnreadByScope(scope: 'all');

      // 測試 2: 使用便捷方法
      final totalUnread = await UnreadServiceV2.getTotalUnread();
      final postedUnread = await UnreadServiceV2.getPostedTasksUnread();
      final myWorksUnread = await UnreadServiceV2.getMyWorksUnread();

      // 測試 3: 批量獲取
      final batchData = await UnreadServiceV2.getAllUnreadData();

      setState(() {
        _testResults = {
          'basic_api_tests': {
            'posted_scope': postedData,
            'myworks_scope': myWorksData,
            'all_scope': allData,
          },
          'convenience_methods': {
            'total_unread': totalUnread,
            'posted_rooms_count': postedUnread.length,
            'myworks_rooms_count': myWorksUnread.length,
          },
          'batch_data': {
            'total': batchData.total,
            'posted_rooms': batchData.postedRooms.length,
            'myworks_rooms': batchData.myWorksRooms.length,
            'all_rooms': batchData.allRooms.length,
          },
          'consistency_check': {
            'posted_total_match': postedData['total'] ==
                batchData.postedRooms.values
                    .fold<int>(0, (sum, count) => sum + count),
            'myworks_total_match': myWorksData['total'] ==
                batchData.myWorksRooms.values
                    .fold<int>(0, (sum, count) => sum + count),
            'total_calculation_correct': allData['total'] == batchData.total,
          }
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _testMarkAsRead() async {
    try {
      // 獲取一個有未讀的房間進行測試
      final allData = await UnreadServiceV2.getUnreadByScope(scope: 'all');
      final byRoom = allData['by_room'] as Map<String, dynamic>? ?? {};

      if (byRoom.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有未讀訊息可供測試')),
        );
        return;
      }

      final roomId = byRoom.keys.first;
      final beforeCount = byRoom[roomId] as int;

      // 標記為已讀
      final result = await UnreadServiceV2.markRoomAsRead(roomId);

      // 重新檢查未讀數
      final afterData = await UnreadServiceV2.getUnreadByScope(scope: 'all');
      final afterByRoom = afterData['by_room'] as Map<String, dynamic>? ?? {};
      final afterCount = afterByRoom[roomId] as int? ?? 0;

      setState(() {
        _testResults['mark_as_read_test'] = {
          'room_id': roomId,
          'before_count': beforeCount,
          'after_count': afterCount,
          'api_response': result,
          'success': afterCount == 0,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('房間 $roomId 標記測試：$beforeCount → $afterCount'),
          backgroundColor: afterCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('標記測試失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('未讀 API V2 測試'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runBasicTests,
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
                  _buildScopeSelector(),
                  const SizedBox(height: 16),
                  _buildTestResults(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildScopeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('選擇測試範圍:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedScope,
              items: ['all', 'posted', 'myworks']
                  .map((scope) =>
                      DropdownMenuItem(value: scope, child: Text(scope)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedScope = value);
                }
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                try {
                  final data = await UnreadServiceV2.getUnreadByScope(
                      scope: _selectedScope);
                  setState(() {
                    _testResults['scope_test'] = data;
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResults['scope_test'] = {'error': e.toString()};
                    _isLoading = false;
                  });
                }
              },
              child: Text('測試 $_selectedScope 範圍'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResults() {
    if (_testResults.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暫無測試結果'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('測試結果:', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('測試操作:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _runBasicTests,
                  child: const Text('基礎測試'),
                ),
                ElevatedButton(
                  onPressed: _testMarkAsRead,
                  child: const Text('測試標記已讀'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final data = await UnreadServiceV2.getAllUnreadData();
                      setState(() {
                        _testResults['batch_test'] = {
                          'total': data.total,
                          'posted_count': data.postedRooms.length,
                          'myworks_count': data.myWorksRooms.length,
                          'all_count': data.allRooms.length,
                        };
                      });
                    } catch (e) {
                      setState(() {
                        _testResults['batch_test'] = {'error': e.toString()};
                      });
                    }
                  },
                  child: const Text('批量數據測試'),
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
