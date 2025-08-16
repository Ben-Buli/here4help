import 'package:flutter/material.dart';
import 'package:here4help/constants/task_status.dart';
import 'package:here4help/constants/theme_schemes.dart';

/// 共享的任務卡片組件
/// 可以在 Posted Tasks 和 My Works 兩個分頁中重用
class TaskCardWidget extends StatelessWidget {
  final Map<String, dynamic> taskData;
  final Map<String, dynamic>? applicationData;
  final String role; // 'creator' 或 'participant'
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final List<Map<String, dynamic>>? applicants;
  final Map<String, int> unreadByRoom;
  final VoidCallback? onTap;

  const TaskCardWidget({
    super.key,
    required this.taskData,
    this.applicationData,
    required this.role,
    required this.isExpanded,
    this.onToggleExpand,
    this.applicants,
    required this.unreadByRoom,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 根據角色獲取狀態顯示
    final statusDisplay = _getStatusDisplay();
    final statusColor = _getStatusColor(theme);

    // 獲取任務基本信息
    final taskId = taskData['id']?.toString() ?? '';
    final title = taskData['title']?.toString() ?? '無標題';
    final description = taskData['description']?.toString() ?? '';
    final location = taskData['location']?.toString() ?? '';
    final languageRequirement =
        taskData['language_requirement']?.toString() ?? '';
    final hashtags = taskData['hashtags']?.toString() ?? '';

    // 計算未讀數量
    final unreadCount = _calculateUnreadCount();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題和狀態行
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusDisplay,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 描述
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: isExpanded ? null : 2,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
              ),

            // 位置和語言要求
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (location.isNotEmpty) ...[
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (languageRequirement.isNotEmpty) ...[
                    Icon(Icons.language, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      languageRequirement,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 標籤
            if (hashtags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 4,
                  children: hashtags.split(',').map((tag) {
                    final trimmedTag = tag.trim();
                    if (trimmedTag.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#$trimmedTag',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // 應徵者信息（僅在 Posted Tasks 中顯示）
            if (role == 'creator' &&
                applicants != null &&
                applicants!.isNotEmpty)
              _buildApplicantsSection(),

            // 展開/收起按鈕
            if (onToggleExpand != null)
              InkWell(
                onTap: onToggleExpand,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isExpanded ? '收起' : '展開',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 根據角色獲取狀態顯示
  String _getStatusDisplay() {
    final statusId = taskData['status_id'];
    final statusCode = taskData['status_code'];

    if (role == 'creator') {
      return TaskStatus.getMappedStatusForRole(
        taskStatusId: statusId ?? 0,
        applicationStatus: null,
        userRole: 'creator',
      );
    } else {
      // 對於 participant，需要從 applicationData 獲取 application status
      final applicationStatus = applicationData?['status']?.toString();
      return TaskStatus.getMappedStatusForRole(
        taskStatusId: statusId ?? 0,
        applicationStatus: applicationStatus,
        userRole: 'participant',
      );
    }
  }

  /// 獲取狀態顏色
  Color _getStatusColor(ThemeData theme) {
    final statusDisplay = _getStatusDisplay();
    final themedColors = TaskStatus.themedColors(theme.colorScheme);

    if (themedColors.containsKey(statusDisplay)) {
      return themedColors[statusDisplay]!.bg;
    }

    return theme.primaryColor;
  }

  /// 計算未讀數量
  int _calculateUnreadCount() {
    if (role == 'creator' && applicants != null) {
      // Posted Tasks：計算所有應徵者聊天室的未讀總數
      int totalUnread = 0;
      for (final applicant in applicants!) {
        final roomId = applicant['chat_room_id']?.toString();
        if (roomId != null) {
          totalUnread += unreadByRoom[roomId] ?? 0;
        }
      }
      return totalUnread;
    } else if (role == 'participant' && applicationData != null) {
      // My Works：計算任務聊天室的未讀數量
      final roomId = applicationData!['chat_room_id']?.toString();
      if (roomId != null) {
        return unreadByRoom[roomId] ?? 0;
      }
    }
    return 0;
  }

  /// 構建應徵者信息區域
  Widget _buildApplicantsSection() {
    if (applicants == null || applicants!.isEmpty)
      return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '應徵者 (${applicants!.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_calculateUnreadCount() > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_calculateUnreadCount()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            ...applicants!.map((applicant) {
              final name = applicant['user_name']?.toString() ?? '未知用戶';
              final roomId = applicant['chat_room_id']?.toString();
              final unreadCount =
                  roomId != null ? unreadByRoom[roomId] ?? 0 : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}
