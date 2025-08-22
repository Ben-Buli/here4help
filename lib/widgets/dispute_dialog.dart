import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:here4help/services/api/dispute_api.dart';

/// 申訴對話框
class DisputeDialog extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final VoidCallback? onDisputeSubmitted;

  const DisputeDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.onDisputeSubmitted,
  });

  @override
  State<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<DisputeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _selectedReason = 'task_not_completed';
  bool _isSubmitting = false;

  // 申訴原因選項
  final Map<String, String> _reasonOptions = {
    'task_not_completed': '任務未完成',
    'poor_quality': '工作品質不佳',
    'communication_issue': '溝通問題',
    'payment_dispute': '付款爭議',
    'safety_concern': '安全顧慮',
    'other': '其他',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await DisputeApi.submitDispute(
        taskId: widget.taskId,
        reason: _selectedReason,
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示申訴成功

        // 顯示成功訊息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('申訴已提交，任務狀態已更改為爭議中'),
            backgroundColor: Colors.green,
          ),
        );

        // 通知父組件刷新
        widget.onDisputeSubmitted?.call();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeDialog: 申訴提交失敗: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('申訴提交失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('提交申訴'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      '任務',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.taskTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 申訴原因
              const Text(
                '申訴原因 *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _reasonOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedReason = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請選擇申訴原因';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 詳細說明
              const Text(
                '詳細說明 *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '請詳細描述申訴的原因和情況...',
                  contentPadding: EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入詳細說明';
                  }
                  if (value.trim().length < 10) {
                    return '說明至少需要10個字符';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // 提示文字
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '提交申訴後，任務將進入爭議狀態，自動完成倒數將停止。管理員將審核您的申訴並做出裁決。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
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
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitDispute,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('提交申訴'),
        ),
      ],
    );
  }
}

/// 快速申訴按鈕
class QuickDisputeButton extends StatelessWidget {
  final String taskId;
  final String taskTitle;
  final VoidCallback? onDisputeSubmitted;

  const QuickDisputeButton({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.onDisputeSubmitted,
  });

  void _showDisputeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DisputeDialog(
        taskId: taskId,
        taskTitle: taskTitle,
        onDisputeSubmitted: onDisputeSubmitted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDisputeDialog(context),
      icon: const Icon(Icons.report_problem, size: 16),
      label: const Text('申訴'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red[700],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
