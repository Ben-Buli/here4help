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
            content: Text('爭議已提交，任務狀態已更改為爭議中'),
            backgroundColor: Colors.green,
          ),
        );

        // 通知父組件刷新
        widget.onDisputeSubmitted?.call();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeDialog: 爭議提交失敗: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('爭議提交失敗: $e'),
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
            Text('爭議已存在'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此任務已經提交過爭議，無法重複提交。'),
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
                  Text(
                    '爭議 ID: ${_existingDispute!['id']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '狀態: ${_existingDispute!['status']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '提交時間: ${_formatDateTime(_existingDispute!['created_at'])}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      );
    }

    // 如果沒有現有爭議，顯示提交表單
    return AlertDialog(
      title: const Text('提交任務爭議'),
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

              // 爭議標題
              const Text(
                '爭議標題 *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _titleController,
                maxLength: 255,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '請簡要描述爭議的主要問題...',
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '$_titleCharCount/255',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入爭議標題';
                  }
                  if (value.trim().length < 5) {
                    return '標題至少需要5個字符';
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
                maxLength: 1000,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '請詳細描述爭議的原因、經過和您的訴求...',
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '$_descriptionCharCount/1000',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入詳細說明';
                  }
                  if (value.trim().length < 20) {
                    return '說明至少需要20個字符';
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
                        '提交爭議後，任務將進入爭議狀態，自動完成倒數將停止。管理員將審核您的爭議並做出裁決。',
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
              : const Text('提交爭議'),
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
      label: const Text('爭議'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red[700],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
