import 'package:flutter/material.dart';
import 'package:here4help/chat/widgets/optimized_tab_unread_mixin.dart';
import 'package:here4help/chat/services/smart_read_status_manager.dart';

/// 優化後的 Posted Tasks Widget 整合示例
/// 展示如何使用新的統一未讀狀態管理器
class OptimizedPostedTasksWidget extends StatefulWidget {
  const OptimizedPostedTasksWidget({super.key});

  @override
  State<OptimizedPostedTasksWidget> createState() =>
      _OptimizedPostedTasksWidgetState();
}

class _OptimizedPostedTasksWidgetState extends State<OptimizedPostedTasksWidget>
    with OptimizedTabUnreadMixin, SmartReadStatusMixin {
  final List<Map<String, dynamic>> _allTasks = [];

  @override
  void initState() {
    super.initState();

    // 初始化分頁未讀管理器
    initializeTabUnreadManager('posted_tasks');

    // 載入數據
    _loadTasks();
  }

  /// 載入任務數據（簡化版本）
  Future<void> _loadTasks() async {
    // 模擬載入任務數據
    await Future.delayed(const Duration(seconds: 1));

    // 假設載入了一些任務數據
    _allTasks.addAll([
      {
        'id': '1',
        'title': 'Task 1',
        'applicants': [
          {'chat_room_id': 'room_1', 'applier_name': 'User A'},
          {'chat_room_id': 'room_2', 'applier_name': 'User B'},
        ]
      },
      {
        'id': '2',
        'title': 'Task 2',
        'applicants': [
          {'chat_room_id': 'room_3', 'applier_name': 'User C'},
        ]
      },
    ]);

    // 註冊房間到分頁的映射關係
    final roomIds = <String>[];
    for (final task in _allTasks) {
      final applicants = task['applicants'] as List? ?? [];
      for (final applicant in applicants) {
        final roomId = applicant['chat_room_id']?.toString();
        if (roomId != null && roomId.isNotEmpty) {
          roomIds.add(roomId);
        }
      }
    }

    registerRoomsToTab(roomIds);

    if (mounted) {
      setState(() {
        // 觸發 UI 更新
      });
    }
  }

  @override
  void onTabUnreadChanged(bool hasUnread) {
    super.onTabUnreadChanged(hasUnread);

    // 可以在這裡添加特定的處理邏輯
    debugPrint('📱 [OptimizedPostedTasks] Tab 未讀狀態變化: $hasUnread');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Posted Tasks'),
            const SizedBox(width: 8),
            // 使用新的 Tab 未讀消費者
            TabUnreadConsumer(
              tabKey: 'posted_tasks',
              builder: (context, hasUnread) {
                return hasUnread
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: _allTasks.length,
        itemBuilder: (context, index) {
          final task = _allTasks[index];
          return _buildOptimizedTaskCard(task);
        },
      ),
    );
  }

  /// 建構優化後的任務卡片
  Widget _buildOptimizedTaskCard(Map<String, dynamic> task) {
    final applicants = task['applicants'] as List? ?? [];

    return Card(
      child: ExpansionTile(
        title: Text(task['title'] ?? 'Untitled Task'),
        children: applicants.map<Widget>((applicant) {
          return _buildOptimizedApplicantItem(applicant);
        }).toList(),
      ),
    );
  }

  /// 建構優化後的應徵者項目
  Widget _buildOptimizedApplicantItem(Map<String, dynamic> applicant) {
    final roomId = applicant['chat_room_id']?.toString() ?? '';
    final applierName = applicant['applier_name']?.toString() ?? 'Unknown';

    return ListTile(
      leading: CircleAvatar(
        child: Text(applierName.substring(0, 1)),
      ),
      title: Text(applierName),
      trailing: RoomUnreadConsumer(
        roomId: roomId,
        builder: (context, unreadCount) {
          return unreadCount > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const SizedBox.shrink();
        },
      ),
      onTap: () {
        // 進入聊天室
        _navigateToChatRoom(roomId);
      },
    );
  }

  /// 導航到聊天室
  void _navigateToChatRoom(String roomId) {
    // 設置為活躍聊天室
    onEnterChatRoom(roomId);

    // 導航邏輯（簡化）
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MockChatDetailPage(
          roomId: roomId,
          onExit: onLeaveChatRoom,
        ),
      ),
    );
  }
}

/// 模擬聊天詳情頁面
class _MockChatDetailPage extends StatelessWidget {
  const _MockChatDetailPage({
    required this.roomId,
    required this.onExit,
  });

  final String roomId;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Room $roomId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 離開聊天室時的處理
            onExit();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('模擬聊天室 $roomId'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 模擬標記已讀
                SmartReadStatusManager.instance.markRoomRead(
                  roomId: roomId,
                  immediate: true,
                );
              },
              child: const Text('標記為已讀'),
            ),
          ],
        ),
      ),
    );
  }
}
