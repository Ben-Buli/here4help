import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';

class SupportIssueDialog extends StatefulWidget {
  const SupportIssueDialog({super.key});

  @override
  State<SupportIssueDialog> createState() => _SupportIssueDialogState();
}

class _SupportIssueDialogState extends State<SupportIssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scrollController = ScrollController(); // 添加滾動控制器
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose(); // 釋放滾動控制器
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
      });
    }
  }

  // 保留 _setError 方法以備將來使用
  // void _setError(String error) {
  //   setState(() {
  //     _submitError = error;
  //   });
  // }

  // 當輸入框獲得焦點時，確保它可見
  void _onTextFieldFocus() {
    // 延遲執行，確保鍵盤動畫完成
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    // 修復鍵盤出現時的高度計算問題
    // 當鍵盤出現時，使用較小的最大高度，但確保不會太小
    final screenHeight = mediaQuery.size.height;
    final maxDialogHeight = bottomInset > 0
        ? (screenHeight * 0.6)
            .clamp(400.0, screenHeight * 0.8) // 鍵盤出現時使用 60% 螢幕高度
        : (screenHeight * 0.9)
            .clamp(360.0, screenHeight * 0.9); // 無鍵盤時使用 90% 螢幕高度

    return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24, // 移除動態 bottom padding，避免過度壓縮
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxDialogHeight,
            ),
            child: SingleChildScrollView(
              controller: _scrollController, // 使用滾動控制器
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // 確保在鍵盤出現時能夠滾動到可見區域
              physics: const ClampingScrollPhysics(),
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent, // 改為 translucent，不攔截滾動事件
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題
                      Row(
                        children: [
                          const Icon(
                            Icons.support_agent,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Contact Support',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please describe your issue and we\'ll help you as soon as possible.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 標題輸入
                      const Text(
                        'Title *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Brief description of your issue',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLength: 255,
                        textInputAction: TextInputAction.next,
                        onTap: _onTextFieldFocus, // 添加焦點監聽
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          if (value.trim().length < 5) {
                            return 'Title must be at least 5 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 描述輸入
                      const Text(
                        'Description *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          hintText:
                              'Please provide more details about your issue...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: 4,
                        maxLength: 1000,
                        textInputAction: TextInputAction.newline,
                        onTap: _onTextFieldFocus, // 添加焦點監聽
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          if (value.trim().length < 10) {
                            return 'Description must be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // 錯誤訊息顯示
                      if (_submitError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red[600], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _submitError!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 按鈕
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}
