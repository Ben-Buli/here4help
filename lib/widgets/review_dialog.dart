import 'package:flutter/material.dart';
import 'package:here4help/services/api/review_api.dart';
import 'package:here4help/constants/app_colors.dart';

class ReviewDialog extends StatefulWidget {
  final String taskId;
  final String taskerId;
  final String taskerName;
  final String taskTitle;
  final VoidCallback? onReviewSubmitted;

  const ReviewDialog({
    super.key,
    required this.taskId,
    required this.taskerId,
    required this.taskerName,
    required this.taskTitle,
    this.onReviewSubmitted,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任務資訊
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task: ${widget.taskTitle}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reviewing: ${widget.taskerName}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 評分星級
            const Text(
              'Rating *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _rating = index + 1;
                      _errorMessage = null;
                    });
                  },
                  child: Icon(
                    Icons.star,
                    size: 40,
                    color: index < _rating ? Colors.amber : Colors.grey[300],
                  ),
                );
              }),
            ),
            if (_rating > 0)
              Center(
                child: Text(
                  _getRatingText(_rating),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 評論（可選）
            const Text(
              'Comment (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),

            // 錯誤訊息
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
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
              : const Text('Submit Review'),
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      setState(() {
        _errorMessage = 'Please select a rating';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ReviewApi.submitReview(
        taskId: widget.taskId,
        taskerId: widget.taskerId,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();

        // 顯示成功訊息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // 通知父組件刷新
        if (widget.onReviewSubmitted != null) {
          widget.onReviewSubmitted!();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }
}

/// 快捷評價按鈕
class QuickReviewButton extends StatelessWidget {
  final String taskId;
  final String taskerId;
  final String taskerName;
  final String taskTitle;
  final VoidCallback? onReviewSubmitted;
  final bool isEnabled;

  const QuickReviewButton({
    super.key,
    required this.taskId,
    required this.taskerId,
    required this.taskerName,
    required this.taskTitle,
    this.onReviewSubmitted,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isEnabled ? () => _showReviewDialog(context) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? AppColors.primary : Colors.grey[300],
        foregroundColor: isEnabled ? Colors.white : Colors.grey[600],
        minimumSize: const Size(80, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: const Text(
        'Review',
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReviewDialog(
          taskId: taskId,
          taskerId: taskerId,
          taskerName: taskerName,
          taskTitle: taskTitle,
          onReviewSubmitted: onReviewSubmitted,
        );
      },
    );
  }
}
