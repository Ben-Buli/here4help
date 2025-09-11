import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:here4help/services/api/dispute_api.dart';

/// 任務爭議對話框
class DisputeDialog extends StatefulWidget {
  final String taskId;
  final String chatRoomId; // 新增
  final String taskTitle;
  final VoidCallback? onDisputeSubmitted;

  const DisputeDialog({
    super.key,
    required this.taskId,
    required this.chatRoomId, // 新增
    required this.taskTitle,
    this.onDisputeSubmitted,
  });

  @override
  State<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<DisputeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(); // 新增
  final _descriptionController = TextEditingController();

  int _titleCharCount = 0; // 新增字數統計
  int _descriptionCharCount = 0; // 新增字數統計

  // 預先檢查是否已存在爭議
  Map<String, dynamic>? _existingDispute;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkExistingDispute();

    // 添加字數統計監聽器
    _titleController.addListener(() {
      setState(() {
        _titleCharCount = _titleController.text.length;
      });
    });

    _descriptionController.addListener(() {
      setState(() {
        _descriptionCharCount = _descriptionController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 檢查是否已存在爭議
  Future<void> _checkExistingDispute() async {
    try {
      final result = await DisputeApi.checkExistingDispute(
        chatRoomId: widget.chatRoomId,
      );

      setState(() {
        _existingDispute = result['exists'] ? result['dispute'] : null;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeDialog: 檢查現有爭議失敗: $e');
      setState(() {
        _isLoading = false;
      });

      // 顯示用戶友好的錯誤訊息
      if (mounted) {
        _showErrorMessage(_getErrorMessage(e));
      }
    }
  }

  /// 格式化日期時間
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  /// 獲取用戶友好的錯誤訊息
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // 檢查常見的錯誤類型
    if (errorString.contains('404') || errorString.contains('not found')) {
      return '服務暫時無法使用，請稍後再試';
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return '網路連線異常，請檢查網路設定';
    }

    if (errorString.contains('timeout')) {
      return '請求逾時，請稍後再試';
    }

    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return '登入已過期，請重新登入';
    }

    if (errorString.contains('forbidden') || errorString.contains('403')) {
      return '您沒有權限執行此操作';
    }

    if (errorString.contains('already exists') ||
        errorString.contains('duplicate')) {
      return '此任務已存在爭議記錄';
    }

    // 預設錯誤訊息
    return '操作失敗，請稍後再試';
  }

  /// 顯示錯誤訊息
  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '確定',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
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
        chatRoomId: widget.chatRoomId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示爭議提交成功

        // 顯示成功訊息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispute submitted, task status changed to dispute'),
            backgroundColor: Colors.green,
          ),
        );

        // 通知父組件刷新
        widget.onDisputeSubmitted?.call();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DisputeDialog: Dispute Submission Failed: $e');
      }

      if (mounted) {
        _showErrorMessage(_getErrorMessage(e));
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
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // 如果已存在爭議，顯示現有爭議資訊
    if (_existingDispute != null) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Dispute Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This task has already been submitted for dispute, please wait for the administrator to review.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Dispute Status: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${_existingDispute!['status']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Submitted Time: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDateTime(_existingDispute!['created_at']),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Last Updated Time: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDateTime(_existingDispute!['updated_at']),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    // 如果沒有現有爭議，顯示提交表單
    return AlertDialog(
      title: const Text('Submit Task Dispute'),
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
                      'Task',
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

              // 爭議標題
              const Text(
                'Dispute Title *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _titleController,
                maxLength: 100,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText:
                      'Please briefly describe the main problem of the dispute...',
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '$_titleCharCount/255',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a dispute title';
                  }
                  if (value.trim().length < 5) {
                    return 'Title must be at least 5 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 詳細說明
              const Text(
                'Detailed Description *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText:
                      'Please describe the reason for the dispute, the process, and your demands...',
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '$_descriptionCharCount/1000',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a detailed description';
                  }
                  if (value.trim().length < 20) {
                    return 'Description must be at least 20 characters';
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
                        'After submitting a dispute, the task will enter dispute status and the auto-complete countdown will stop. An administrator will review your dispute and make a decision.',
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
          child: const Text('Cancel'),
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
              : const Text('Submit'),
        ),
      ],
    );
  }
}

/// 快速爭議按鈕
class QuickDisputeButton extends StatelessWidget {
  final String taskId;
  final String chatRoomId; // 新增
  final String taskTitle;
  final VoidCallback? onDisputeSubmitted;

  const QuickDisputeButton({
    super.key,
    required this.taskId,
    required this.chatRoomId, // 新增
    required this.taskTitle,
    this.onDisputeSubmitted,
  });

  void _showDisputeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DisputeDialog(
        taskId: taskId,
        chatRoomId: chatRoomId, // 新增
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
      label: const Text('Dispute'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red[700],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
