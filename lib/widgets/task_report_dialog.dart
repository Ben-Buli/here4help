import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
          const SnackBar(
            content: Text('檢舉已提交！我們會盡快審核。'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 通知父組件刷新
      widget.onReportSubmitted?.call();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskReportDialog: 檢舉提交失敗: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('檢舉提交失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.report, color: Colors.red),
          SizedBox(width: 8),
          Text('檢舉任務'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 任務資訊
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '檢舉任務：',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
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

              // 檢舉原因選擇
              const Text(
                '檢舉原因 *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '請選擇檢舉原因',
                ),
                items: TaskReportsApi.reportReasons.map((reason) {
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
                    return '請選擇檢舉原因';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 詳細說明
              const Text(
                '詳細說明 *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '請詳細描述檢舉原因...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入詳細說明';
                  }
                  if (value.trim().length < 10) {
                    return '說明至少需要10個字元';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // 提示文字
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '請確保檢舉內容真實有效。虛假檢舉可能導致帳號受限。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
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
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
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
              : const Text('提交檢舉'),
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

