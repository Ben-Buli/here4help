import 'package:flutter/material.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:provider/provider.dart';

/// 任務標題（AppBar 專用）
/// - 主標題：任務名稱（可點擊彈出任務詳情）
/// - 次標題：聊天對象名稱
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
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        // 使用主題配色
        final titleColor = themeManager.effectiveTheme.surface;
        final subtitleColor = themeManager.effectiveTheme.onSecondary;

        // 根據使用者角色決定顯示的聊天對象名稱
        String displayPartnerName = chatPartnerName ?? 'Chat Partner';
        if (chatPartnerInfo != null && chatPartnerInfo!.isNotEmpty) {
          displayPartnerName =
              chatPartnerInfo!['name'] as String? ?? displayPartnerName;
        }

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
                style: titleStyle ?? TextStyle(fontSize: 20, color: titleColor),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                displayPartnerName,
                style: subtitleStyle ??
                    TextStyle(fontSize: 12, color: subtitleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

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
                    ? 'NT\$${task['reward_point']}'
                    : task['salary'] != null
                        ? 'NT\$${task['salary']}'
                        : 'N/A',
              ),
              const SizedBox(height: 8),
              const Text('Request Language:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['language_requirement'] as String?) ?? '—'),
              const SizedBox(height: 8),
              const Text('Location:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['location'] as String?) ?? '—'),
              const SizedBox(height: 8),
              const Text('Task Date:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['task_date'] as String?) ?? '—'),
              const SizedBox(height: 8),
              const Text('Application Question:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((task['application_question'] as String?) ?? '—'),
              const SizedBox(height: 8),
              const Text('Posted by:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('UserName: ' +
                  (((task['creator_name'] as String?)?.trim().isNotEmpty ==
                          true)
                      ? (task['creator_name'] as String)
                      : (chatPartnerName ?? '—'))),
              Row(
                children: [
                  const Icon(Icons.star,
                      color: Color.fromARGB(255, 255, 187, 0), size: 16),
                  const SizedBox(width: 4),
                  Text('${rating ?? 0.0}'),
                  Text(' (${reviewsCount ?? 0} reviews)'),
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
