import 'package:flutter/material.dart';
import 'package:here4help/chat/widgets/dynamic_action_bar.dart';
import 'package:here4help/chat/utils/action_bar_config.dart';
import 'package:here4help/chat/widgets/task_card_components.dart';
import 'package:here4help/chat/utils/application_status_utils.dart';

/// Action Bar 配色測試組件
/// 用於測試不同分頁的配色效果
class ActionBarColorTest extends StatelessWidget {
  const ActionBarColorTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Action Bar 配色測試'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Posted Tasks 分頁配色（Creator 角色）',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildColorTestSection(
              context,
              'posted_tasks',
              'Open',
              TaskStatus.open,
            ),
            const SizedBox(height: 16),
            _buildColorTestSection(
              context,
              'posted_tasks',
              'In Progress',
              TaskStatus.inProgress,
            ),
            const SizedBox(height: 16),
            _buildColorTestSection(
              context,
              'posted_tasks',
              'Completed',
              TaskStatus.completed,
            ),
            const SizedBox(height: 32),
            const Text(
              'My Works 分頁配色（Participant 角色）',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildColorTestSection(
              context,
              'my_works',
              'Applied',
              TaskStatus.open,
            ),
            const SizedBox(height: 16),
            _buildColorTestSection(
              context,
              'my_works',
              'Accepted',
              TaskStatus.inProgress,
            ),
            const SizedBox(height: 16),
            _buildColorTestSection(
              context,
              'my_works',
              'Completed',
              TaskStatus.completed,
            ),
            const SizedBox(height: 32),
            const Text(
              '配色對比說明',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildColorComparison(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorTestSection(
    BuildContext context,
    String colorScheme,
    String statusName,
    TaskStatus taskStatus,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$statusName ($colorScheme)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DynamicActionBar(
              taskStatus: taskStatus,
              userRole: UserRole.participant,
              actionCallbacks: const {},
              showStatusBar: true,
              statusDisplayName: statusName,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 8),
            _buildColorInfo(colorScheme, statusName),
          ],
        ),
      ),
    );
  }

  Widget _buildColorInfo(String colorScheme, String statusName) {
    Color? color;
    String source = '';

    if (colorScheme == 'posted_tasks') {
      final progressData = TaskCardUtils.getProgressData(statusName);
      color = progressData['color'] as Color?;
      source = 'TaskCardUtils.getProgressData()';
    } else if (colorScheme == 'my_works') {
      final applicationStatus = _getApplicationStatusFromTaskStatus(statusName);
      color = ApplicationStatusUtils.getStatusColor(applicationStatus);
      source = 'ApplicationStatusUtils.getStatusColor()';
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color ?? Colors.grey),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '來源: $source\n顏色: ${color?.toString() ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '配色方案對比',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildComparisonRow('Open', 'applied'),
            _buildComparisonRow('In Progress', 'accepted'),
            _buildComparisonRow('Completed', 'completed'),
            _buildComparisonRow('Dispute', 'dispute'),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String taskStatus, String applicationStatus) {
    final taskColor =
        TaskCardUtils.getProgressData(taskStatus)['color'] as Color?;
    final appColor = ApplicationStatusUtils.getStatusColor(applicationStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: taskColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Posted Tasks: $taskStatus'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: appColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text('My Works: $applicationStatus'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getApplicationStatusFromTaskStatus(String taskStatus) {
    switch (taskStatus) {
      case 'Open':
        return 'applied';
      case 'In Progress':
        return 'accepted';
      case 'Completed':
        return 'completed';
      case 'Dispute':
        return 'dispute';
      default:
        return 'applied';
    }
  }
}
