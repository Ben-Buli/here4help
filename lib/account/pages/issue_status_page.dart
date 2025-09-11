import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/api/support_event_api.dart';
import 'package:here4help/widgets/support_issue_dialog.dart';

/// 客服事件狀態頁面
///
/// 顯示單一活躍客服事件的 Timeline 進度
class IssueStatusPage extends StatefulWidget {
  const IssueStatusPage({super.key});

  @override
  State<IssueStatusPage> createState() => _IssueStatusPageState();
}

class _IssueStatusPageState extends State<IssueStatusPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _activeEvent;

  @override
  void initState() {
    super.initState();
    _loadActiveEvent();
  }

  Future<void> _loadActiveEvent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 獲取使用者的客服事件
      final response = await SupportEventApi.getSupportChatList();

      if (response['success'] == true && response['data'] != null) {
        final chatList = response['data']['chat_list'] as List?;

        // 尋找活躍的客服事件
        final activeEvent = chatList?.firstWhere(
          (chat) =>
              chat['event_status'] == 'submitted' ||
              chat['event_status'] == 'in_progress',
          orElse: () => null,
        );

        setState(() {
          _activeEvent = activeEvent;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message'] ?? 'Failed to load support status';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading support status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadActiveEvent,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 如果沒有活躍事件，顯示創建新事件的界面
    if (_activeEvent == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.support_agent,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No issue pending at the moment',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'You can create a new support case if you need help.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateIssueDialog,
              icon: const Icon(Icons.add),
              label: const Text('Contact Us'),
            ),
          ],
        ),
      );
    }

    // 顯示活躍事件的 Timeline
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 事件標題和 ID - 移除 Card UI
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeEvent!['event_title'] ?? 'Support Case',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Issue Case ID: ${_activeEvent!['event_id'] ?? 'Unknown'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 時間軸居中顯示，帶邊框
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: _buildTimeline(),
            ),
          ),
          const SizedBox(height: 40),

          // 前往聊天室按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _goToSupportChat(),
              icon: const Icon(Icons.chat),
              label: const Text('Go to Support Chat'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final status = _activeEvent!['event_status'] as String;
    final createdAt = _activeEvent!['event_created_at'] as String?;
    final updatedAt = _activeEvent!['event_updated_at'] as String?;

    return Column(
      children: [
        _buildTimelineStep(
          title: 'Submitted',
          subtitle: createdAt != null ? _formatDateTime(createdAt) : 'Unknown',
          isCompleted: true, // Submitted 總是完成
          isActive: status == 'submitted',
          showConnector: true,
        ),
        _buildTimelineStep(
          title: 'In Progress',
          subtitle: status == 'in_progress' && updatedAt != null
              ? _formatDateTime(updatedAt)
              : status == 'in_progress'
                  ? 'Admin is handling your case'
                  : 'Waiting for admin to claim',
          isCompleted:
              status == 'in_progress' || status == 'resolved', // 當前狀態或已完成都顯示勾
          isActive: status == 'in_progress',
          showConnector: true,
        ),
        _buildTimelineStep(
          title: 'Resolved',
          subtitle: status == 'resolved'
              ? 'Case has been resolved'
              : 'Pending completion',
          isCompleted: status == 'resolved',
          isActive: status == 'resolved',
          showConnector: false, // 最後一個不顯示連接線
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool showConnector,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圓圈和連接線的容器
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.primary
                        : isActive
                            ? AppColors.primary.withOpacity(0.3)
                            : Colors.grey[300],
                    border: isActive && !isCompleted
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                // 連接線從圓圈底部開始
                if (showConnector)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 2,
                    height: 32,
                    color: isCompleted ? AppColors.primary : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted
                              ? AppColors.primary
                              : isActive
                                  ? Colors.black
                                  : Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  void _goToSupportChat() {
    final roomId = _activeEvent!['room_id'];
    if (roomId != null) {
      context.go('/account/support/contact/chat?room_id=$roomId');
    }
  }

  void _showCreateIssueDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const SupportIssueDialog(),
    );

    if (result != null) {
      await _createSupportIssue(result['title']!, result['description']!);
    }
  }

  Future<void> _createSupportIssue(String title, String description) async {
    try {
      final response = await SupportEventApi.createIssue(
        title: title,
        description: description,
      );

      // SupportEventApi.createIssue 直接回傳 data['data']，不是完整回應結構
      if (response['room_id'] != null) {
        final roomId = response['room_id'];

        if (mounted) {
          // 顯示成功訊息
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Support case created successfully!'),
              backgroundColor: Color.fromARGB(255, 128, 161, 129),
              duration: Duration(seconds: 2),
            ),
          );

          // 重新載入頁面以顯示新創建的事件
          _loadActiveEvent();

          // 導航到聊天室
          context.go('/account/support/contact/chat?room_id=$roomId');
        }
      } else {
        if (mounted) {
          // 顯示錯誤消息
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create support case: Invalid response'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // 顯示錯誤消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create support case: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
