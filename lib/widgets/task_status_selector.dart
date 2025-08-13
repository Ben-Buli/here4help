import 'package:flutter/material.dart';
import '../services/task_status_service.dart';

/// 任務狀態選擇器元件 - 使用動態載入的狀態資料
class TaskStatusSelector extends StatefulWidget {
  final String? initialStatusCode;
  final ValueChanged<TaskStatusModel?>? onStatusChanged;
  final bool enabled;
  final String? hintText;
  final bool showIcon;

  const TaskStatusSelector({
    super.key,
    this.initialStatusCode,
    this.onStatusChanged,
    this.enabled = true,
    this.hintText = '選擇狀態',
    this.showIcon = true,
  });

  @override
  State<TaskStatusSelector> createState() => _TaskStatusSelectorState();
}

class _TaskStatusSelectorState extends State<TaskStatusSelector> {
  final TaskStatusService _statusService = TaskStatusService();
  TaskStatusModel? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _initializeStatus();
  }

  Future<void> _initializeStatus() async {
    // 確保狀態服務已初始化
    await _statusService.initialize();

    // 設定初始狀態
    if (widget.initialStatusCode != null) {
      _selectedStatus = _statusService.getByCode(widget.initialStatusCode!);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _statusService,
      builder: (context, child) {
        if (_statusService.isLoading) {
          return DropdownButtonFormField<TaskStatusModel>(
            items: const [],
            onChanged: null,
            decoration: const InputDecoration(
              suffixIcon: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              hintText: '載入中...',
            ),
          );
        }

        if (_statusService.error != null) {
          return DropdownButtonFormField<TaskStatusModel>(
            items: const [],
            onChanged: null,
            decoration: InputDecoration(
              suffixIcon: Icon(
                Icons.error_outline,
                color: colorScheme.error,
              ),
              hintText: '載入失敗',
              errorText: _statusService.error,
            ),
          );
        }

        final activeStatuses = _statusService.getActiveStatuses();

        return DropdownButtonFormField<TaskStatusModel>(
          value: _selectedStatus,
          items: activeStatuses.map((status) {
            final style =
                _statusService.getStatusStyle(status.code, colorScheme);

            return DropdownMenuItem<TaskStatusModel>(
              value: status,
              child: Row(
                children: [
                  if (widget.showIcon && style.icon != null) ...[
                    Icon(
                      style.icon,
                      size: 16,
                      color: style.foregroundColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      status.displayName,
                      style: TextStyle(
                        color: style.foregroundColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (status.progressRatio > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: style.backgroundColor,
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: status.progressRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: style.foregroundColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: widget.enabled
              ? (TaskStatusModel? newStatus) {
                  setState(() {
                    _selectedStatus = newStatus;
                  });
                  widget.onStatusChanged?.call(newStatus);
                }
              : null,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: widget.showIcon && _selectedStatus != null
                ? Icon(
                    _statusService
                        .getStatusStyle(_selectedStatus!.code, colorScheme)
                        .icon,
                    color: _statusService
                        .getStatusStyle(_selectedStatus!.code, colorScheme)
                        .foregroundColor,
                  )
                : null,
          ),
          validator: (value) {
            if (value == null) {
              return '請選擇狀態';
            }
            return null;
          },
        );
      },
    );
  }
}

/// 任務狀態標籤元件 - 顯示狀態資訊
class TaskStatusChip extends StatelessWidget {
  final dynamic statusIdentifier; // 可以是 code (String) 或 id (int)
  final bool showIcon;
  final bool showProgress;
  final double? customSize;

  const TaskStatusChip({
    super.key,
    required this.statusIdentifier,
    this.showIcon = true,
    this.showProgress = false,
    this.customSize,
  });

  @override
  Widget build(BuildContext context) {
    final statusService = TaskStatusService();
    final colorScheme = Theme.of(context).colorScheme;

    // 如果服務尚未載入，顯示預設樣式
    if (!statusService.isLoaded) {
      return Chip(
        label: Text(statusIdentifier.toString()),
        backgroundColor: colorScheme.surfaceContainerHighest,
      );
    }

    final displayName = statusService.getDisplayName(statusIdentifier);
    final style = statusService.getStatusStyle(statusIdentifier, colorScheme);
    final progressRatio = statusService.getProgressRatio(statusIdentifier);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: customSize != null ? customSize! * 0.4 : 12,
        vertical: customSize != null ? customSize! * 0.2 : 6,
      ),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius:
            BorderRadius.circular(customSize != null ? customSize! * 0.3 : 16),
        border: Border.all(
          color: style.foregroundColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && style.icon != null) ...[
            Icon(
              style.icon,
              size: customSize != null ? customSize! * 0.5 : 14,
              color: style.foregroundColor,
            ),
            SizedBox(width: customSize != null ? customSize! * 0.2 : 6),
          ],
          Text(
            displayName,
            style: TextStyle(
              color: style.foregroundColor,
              fontSize: customSize != null ? customSize! * 0.35 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showProgress && progressRatio > 0) ...[
            SizedBox(width: customSize != null ? customSize! * 0.2 : 8),
            Container(
              width: customSize != null ? customSize! * 0.8 : 24,
              height: customSize != null ? customSize! * 0.1 : 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                    customSize != null ? customSize! * 0.05 : 1.5),
                color: style.foregroundColor.withValues(alpha: 0.3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressRatio,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                        customSize != null ? customSize! * 0.05 : 1.5),
                    color: style.foregroundColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 任務狀態進度條元件
class TaskStatusProgressBar extends StatelessWidget {
  final dynamic statusIdentifier;
  final double height;
  final bool showPercentage;

  const TaskStatusProgressBar({
    super.key,
    required this.statusIdentifier,
    this.height = 6,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusService = TaskStatusService();
    final colorScheme = Theme.of(context).colorScheme;

    if (!statusService.isLoaded) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: colorScheme.surfaceContainerHighest,
        ),
      );
    }

    final progressRatio = statusService.getProgressRatio(statusIdentifier);
    final style = statusService.getStatusStyle(statusIdentifier, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: style.backgroundColor,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progressRatio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: style.foregroundColor,
              ),
            ),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(progressRatio * 100).toInt()}%',
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
