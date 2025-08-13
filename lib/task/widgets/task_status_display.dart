import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/task_status_service.dart';
import '../../widgets/task_status_selector.dart';

/// 任務狀態顯示元件 - 用於替換現有的硬編碼狀態顯示
class TaskStatusDisplay extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isEditable;
  final ValueChanged<TaskStatusModel?>? onStatusChanged;
  final VoidCallback? onEdit;

  const TaskStatusDisplay({
    super.key,
    required this.task,
    this.isEditable = false,
    this.onStatusChanged,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskStatusService>(
      builder: (context, statusService, child) {
        // 從任務中提取狀態資訊
        final statusIdentifier = _getStatusIdentifier();

        if (isEditable) {
          return _buildEditableStatus(context, statusService, statusIdentifier);
        } else {
          return _buildReadOnlyStatus(context, statusService, statusIdentifier);
        }
      },
    );
  }

  /// 從任務資料中提取狀態識別符
  dynamic _getStatusIdentifier() {
    // 優先使用 status_id (新格式)
    if (task['status_id'] != null) {
      return task['status_id'] is int
          ? task['status_id']
          : int.tryParse(task['status_id'].toString());
    }

    // 其次使用 status_code
    if (task['status_code'] != null &&
        task['status_code'].toString().isNotEmpty) {
      return task['status_code'].toString();
    }

    // 最後使用舊的 status 欄位 (向後相容)
    if (task['status'] != null && task['status'].toString().isNotEmpty) {
      return task['status'].toString();
    }

    return 'open'; // 預設狀態
  }

  /// 建立可編輯的狀態顯示
  Widget _buildEditableStatus(BuildContext context,
      TaskStatusService statusService, dynamic statusIdentifier) {
    final currentStatus = statusIdentifier is int
        ? statusService.getById(statusIdentifier)
        : statusService.getByCode(statusIdentifier.toString());

    return Row(
      children: [
        Expanded(
          child: TaskStatusChip(
            statusIdentifier: statusIdentifier,
            showIcon: true,
            showProgress: true,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed:
              onEdit ?? () => _showStatusEditDialog(context, currentStatus),
          tooltip: '編輯狀態',
        ),
      ],
    );
  }

  /// 建立唯讀的狀態顯示
  Widget _buildReadOnlyStatus(BuildContext context,
      TaskStatusService statusService, dynamic statusIdentifier) {
    return TaskStatusChip(
      statusIdentifier: statusIdentifier,
      showIcon: true,
      showProgress: true,
    );
  }

  /// 顯示狀態編輯對話框
  void _showStatusEditDialog(
      BuildContext context, TaskStatusModel? currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('變更任務狀態'),
        content: SizedBox(
          width: double.maxFinite,
          child: TaskStatusSelector(
            initialStatusCode: currentStatus?.code,
            onStatusChanged: (newStatus) {
              Navigator.pop(context);
              onStatusChanged?.call(newStatus);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

/// 任務狀態篩選器 - 用於任務列表頁面的狀態篩選
class TaskStatusFilter extends StatefulWidget {
  final List<String>? selectedStatusCodes;
  final ValueChanged<List<String>>? onChanged;

  const TaskStatusFilter({
    super.key,
    this.selectedStatusCodes,
    this.onChanged,
  });

  @override
  State<TaskStatusFilter> createState() => _TaskStatusFilterState();
}

class _TaskStatusFilterState extends State<TaskStatusFilter> {
  late List<String> _selectedCodes;

  @override
  void initState() {
    super.initState();
    _selectedCodes = List.from(widget.selectedStatusCodes ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskStatusService>(
      builder: (context, statusService, child) {
        final activeStatuses = statusService.getActiveStatuses();

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: activeStatuses.map((status) {
            final isSelected = _selectedCodes.contains(status.code);
            final style = statusService.getStatusStyle(
                status.code, Theme.of(context).colorScheme);

            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (style.icon != null) ...[
                    Icon(
                      style.icon,
                      size: 14,
                      color: isSelected
                          ? style.backgroundColor
                          : style.foregroundColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(status.displayName),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCodes.add(status.code);
                  } else {
                    _selectedCodes.remove(status.code);
                  }
                });
                widget.onChanged?.call(_selectedCodes);
              },
              backgroundColor: style.backgroundColor,
              selectedColor: style.foregroundColor,
              checkmarkColor: style.backgroundColor,
            );
          }).toList(),
        );
      },
    );
  }
}

/// 任務狀態統計圖表
class TaskStatusStats extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final bool showCounts;

  const TaskStatusStats({
    super.key,
    required this.tasks,
    this.showCounts = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskStatusService>(
      builder: (context, statusService, child) {
        final statusCounts = <String, int>{};

        // 統計各狀態的任務數量
        for (final task in tasks) {
          final statusIdentifier = _getStatusIdentifier(task);
          final statusCode = statusIdentifier is int
              ? statusService.getById(statusIdentifier)?.code
              : statusIdentifier.toString();

          if (statusCode != null) {
            statusCounts[statusCode] = (statusCounts[statusCode] ?? 0) + 1;
          }
        }

        final activeStatuses = statusService.getActiveStatuses();
        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '任務狀態分布',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...activeStatuses
                .where((status) => statusCounts.containsKey(status.code))
                .map((status) {
              final count = statusCounts[status.code] ?? 0;
              final percentage =
                  tasks.isNotEmpty ? (count / tasks.length) * 100 : 0.0;
              final style =
                  statusService.getStatusStyle(status.code, colorScheme);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      style.icon,
                      size: 16,
                      color: style.foregroundColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        status.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: style.foregroundColor,
                        ),
                      ),
                    ),
                    if (showCounts) ...[
                      Text(
                        count.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: style.backgroundColor,
                        valueColor:
                            AlwaysStoppedAnimation(style.foregroundColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  dynamic _getStatusIdentifier(Map<String, dynamic> task) {
    if (task['status_id'] != null) {
      return task['status_id'] is int
          ? task['status_id']
          : int.tryParse(task['status_id'].toString());
    }

    if (task['status_code'] != null &&
        task['status_code'].toString().isNotEmpty) {
      return task['status_code'].toString();
    }

    if (task['status'] != null && task['status'].toString().isNotEmpty) {
      return task['status'].toString();
    }

    return 'open';
  }
}

