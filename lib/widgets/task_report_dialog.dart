import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/services/api/task_reports_api.dart';

/// 任務檢舉對話框
class TaskReportDialog extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final VoidCallback? onReportSubmitted;

  const TaskReportDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.onReportSubmitted,
  });

  @override
  State<TaskReportDialog> createState() => _TaskReportDialogState();
}

class _TaskReportDialogState extends State<TaskReportDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await TaskReportsApi.submitReport(
        taskId: widget.taskId,
        reason: _selectedReason!,
        description: _descriptionController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pop(true); // 檢舉成功，返回 true
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report submitted! We will review it soon.'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }

      // 通知父組件刷新
      widget.onReportSubmitted?.call();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskReportDialog: Report submission failed: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submission failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = context.watch<ThemeConfigManager>();
    final dialogBackground =
        theme.dialogTheme.backgroundColor ?? themeManager.dialogBackgroundColor;
    final primaryColor = themeManager.dialogPrimaryColor;
    final titleColor = themeManager.dialogTitleColor;
    final warningColor = theme.colorScheme.error.withOpacity(0.85);
    final cardBackground =
        Color.alphaBlend(primaryColor.withOpacity(0.08), Colors.white);
    final cardBorder = primaryColor.withOpacity(0.2);
    final infoBackground =
        Color.alphaBlend(warningColor.withOpacity(0.12), Colors.white);
    final infoBorder = warningColor.withOpacity(0.25);

    return AlertDialog(
      backgroundColor: dialogBackground,
      shape: theme.dialogTheme.shape,
      titleTextStyle: theme.dialogTheme.titleTextStyle,
      contentTextStyle: theme.dialogTheme.contentTextStyle,
      title: Row(
        children: [
          Icon(Icons.report, color: warningColor),
          const SizedBox(width: 8),
          const Text('Report Task'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Task:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: titleColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.taskTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reason *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please select a reason',
                ),
                items: TaskReportsApi.getReportReasons().map((reason) {
                  return DropdownMenuItem<String>(
                    value: reason['value'],
                    child: Text(reason['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Detailed Description *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please describe the reason for the report...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a detailed description';
                  }
                  if (value.trim().length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: infoBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: infoBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: warningColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please ensure the report content is real and valid. False reports may result in account restrictions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: primaryColor),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: warningColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}

/// 任務檢舉按鈕
class TaskReportButton extends StatelessWidget {
  final String taskId;
  final String taskTitle;
  final VoidCallback? onReportSubmitted;
  final Widget? child;

  const TaskReportButton({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.onReportSubmitted,
    this.child,
  });

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TaskReportDialog(
        taskId: taskId,
        taskTitle: taskTitle,
        onReportSubmitted: onReportSubmitted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showReportDialog(context),
      child: child ??
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.report_outlined,
                size: 16,
                color: Colors.red,
              ),
              SizedBox(width: 4),
              Text(
                'Report',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
    );
  }
}
