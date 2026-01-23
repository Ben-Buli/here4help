import 'package:flutter/material.dart';
import 'package:here4help/theme/h4h_theme_extension.dart';

/// 任務標題（AppBar 專用）
/// - 主標題：任務名稱（可點擊彈出任務詳情）
/// - 次標題：聊天對象名稱 + 任務狀態
class TaskAppBarTitle extends StatelessWidget {
  const TaskAppBarTitle({
    super.key,
    required this.task,
    this.chatPartnerName,
    this.userRole,
    this.chatPartnerInfo,
    this.rating,
    this.reviewsCount,
    this.titleStyle,
    this.subtitleStyle,
  });

  /// 任務資料（需包含 title 等欄位）
  final Map<String, dynamic> task;

  /// 聊天對象名稱
  final String? chatPartnerName;

  /// 當前使用者在聊天室中的角色
  final String? userRole;

  /// 聊天對象資訊
  final Map<String, dynamic>? chatPartnerInfo;

  /// 對象評分與評論數（可選）
  final double? rating;
  final int? reviewsCount;

  /// 樣式（可選）
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExtension =
        theme.extension<Here4HelpThemeExtension>() ??
            Here4HelpThemeExtension(
              appBarTextColor: theme.colorScheme.onSurface,
              appBarSubtitleColor: theme.colorScheme.onSurface.withOpacity(0.8),
              appBarGradient: const [],
              navigationBarBackground: theme.colorScheme.surface,
              navigationBarSelectedColor: theme.colorScheme.primary,
              navigationBarUnselectedColor:
                  theme.colorScheme.onSurface.withOpacity(0.7),
              dialogBackgroundColor: theme.colorScheme.surface,
              dialogTitleColor: theme.colorScheme.onSurface,
              dialogContentColor: theme.colorScheme.onSurface.withOpacity(0.9),
              dialogPrimaryColor: theme.colorScheme.primary,
            );

    final titleColor = themeExtension.appBarTextColor;
    final subtitleColor = themeExtension.appBarSubtitleColor;

        // 根據使用者角色決定顯示的聊天對象名稱
        String displayPartnerName = chatPartnerName ?? 'Chat Partner';
        if (chatPartnerInfo != null && chatPartnerInfo!.isNotEmpty) {
          displayPartnerName =
              chatPartnerInfo!['name'] as String? ?? displayPartnerName;
        }

        // 獲取任務狀態顯示
        // String statusDisplay = _getStatusDisplay();

    return GestureDetector(
      onTap: () => _showTaskInfoDialog(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (task['title'] as String?)?.trim().isNotEmpty == true
                ? task['title'] as String
                : 'Untitled Task',
            style: titleStyle ??
                TextStyle(
                  fontSize: 20,
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 顯示聊天對象名稱和任務狀態
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayPartnerName,
                style: subtitleStyle ??
                    TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      fontWeight: FontWeight.w400,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 獲取任務狀態顯示文字
  // String _getStatusDisplay() {
  //   // 如果是 participant 角色，優先使用 application_status
  //   if (userRole == 'participant') {
  //     final applicationStatus = task['application_status']?.toString();
  //     if (applicationStatus != null && applicationStatus.isNotEmpty) {
  //       return ApplicationStatusUtils.getDisplayName(applicationStatus);
  //     }
  //   }

  //   // 優先使用 mapped_status（後端計算的角色視角狀態）
  //   if (task['mapped_status'] != null &&
  //       task['mapped_status'].toString().isNotEmpty) {
  //     return task['mapped_status'].toString();
  //   }

  //   // 備用：使用 status.display_name
  //   final status = task['status'];
  //   if (status is Map<String, dynamic> && status['display_name'] != null) {
  //     return status['display_name'].toString();
  //   }

  //   // 最後備用：使用舊的 status 字段
  //   if (task['status'] != null && task['status'].toString().isNotEmpty) {
  //     return TaskStatus.getDisplayStatus(task['status'].toString());
  //   }

  //   return '';
  // }

  // /// 獲取狀態標籤的顏色
  // Color _getStatusColor(ThemeScheme themeScheme) {
  //   // 如果是 participant 角色，使用 ApplicationStatusUtils 的顏色
  //   if (userRole == 'participant') {
  //     final applicationStatus = task['application_status']?.toString();
  //     if (applicationStatus != null && applicationStatus.isNotEmpty) {
  //       return ApplicationStatusUtils.getStatusColor(applicationStatus);
  //     }
  //   }

  //   final status = _getStatusDisplay();

  //   switch (status.toLowerCase()) {
  //     case 'open':
  //       return themeScheme.primary;
  //     case 'in progress':
  //       return themeScheme.secondary;
  //     case 'pending confirmation':
  //     case 'pending review':
  //       return themeScheme.accent;
  //     case 'completed':
  //       return Colors.green;
  //     case 'dispute':
  //       return themeScheme.error;
  //     case 'rejected':
  //       return Colors.red;
  //     case 'cancelled':
  //       return Colors.grey;
  //     default:
  //       return themeScheme.primary;
  //   }
  // }

  void _showTaskInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((task['title'] as String?) ?? 'Task Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Task Description',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['description'] as String?) ?? 'No description'),
              const SizedBox(height: 8),
              const Text('Reward Point:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                task['reward_point'] != null
                    ? '${task['reward_point']} Points'
                    : task['salary'] != null
                        ? '${task['salary']} Points'
                        : 'N/A',
              ),
              const SizedBox(height: 8),
              const Text('Request Language:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['language_requirement'] as String?) ??
                  'No language requirement'),
              const SizedBox(height: 8),
              const Text('Location:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['location'] as String?) ?? 'No location'),
              const SizedBox(height: 8),
              const Text('Task Date:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['task_date'] as String?) ?? 'No task date'),
              const SizedBox(height: 8),
              const Text('Application Question:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['application_question'] as String?) ??
                  'No application question'),
              const SizedBox(height: 8),
              const Text('Posted by:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('UserName: ${chatPartnerName ?? 'No user name'}'),
              Row(
                children: [
                  if ((rating ?? 0.0) == 0.0) ...[
                    const Icon(Icons.eco,
                        color: Color.fromARGB(255, 106, 151, 112), size: 16),
                    const SizedBox(width: 4),
                    const Text('No reviews yet.')
                  ] else ...[
                    const Icon(Icons.star,
                        color: Color.fromARGB(255, 255, 187, 0), size: 16),
                    const SizedBox(width: 4),
                    Text('$rating'),
                    Text(' ($reviewsCount reviews)'),
                  ]
                ],
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
