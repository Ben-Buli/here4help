import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:here4help/services/api/review_api.dart';
import 'package:here4help/constants/app_colors.dart';

class ReviewDialog extends StatefulWidget {
  final String taskId;
  final String taskerId;
  final String taskerName;
  final String taskTitle;
  final VoidCallback? onReviewSubmitted;
  final bool readOnlyMode; // 新增：唯讀模式
  final Map<String, dynamic>? existingReview; // 新增：現有評分資料

  const ReviewDialog({
    super.key,
    required this.taskId,
    required this.taskerId,
    required this.taskerName,
    required this.taskTitle,
    this.onReviewSubmitted,
    this.readOnlyMode = false,
    this.existingReview,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double _rating = 1.0; // 預設 1 分
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // 如果是唯讀模式且有現有評分，載入現有資料
    if (widget.readOnlyMode && widget.existingReview != null) {
      _rating = (widget.existingReview!['rating'] ?? 1).toDouble();
      _commentController.text = widget.existingReview!['comment'] ?? '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.readOnlyMode ? 'Review Details' : 'Submit Review'),
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

            // 評分星級 - 簡化為單一排
            const Text(
              'Rating *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemSize: 40,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: widget.readOnlyMode
                    ? (rating) {}
                    : (rating) {
                        setState(() {
                          _rating = rating;
                          _errorMessage = null;
                        });
                      },
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getRatingText(_rating.toInt()),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 評論 - 必填
            const Text(
              'Comment *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500, // 調整為 500 字
              enabled: !widget.readOnlyMode,
              decoration: const InputDecoration(
                hintText: 'Please share your experience...',
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
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.readOnlyMode ? 'Close' : 'Cancel'),
        ),
        if (!widget.readOnlyMode)
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
        return 'Please rate';
    }
  }

  Future<void> _submitReview() async {
    // 驗證評分
    if (_rating < 1) {
      setState(() {
        _errorMessage = 'Please select a rating';
      });
      return;
    }

    // 驗證評論必填
    if (_commentController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Comment is required';
      });
      return;
    }

    // 驗證評論長度
    if (_commentController.text.trim().length < 10) {
      setState(() {
        _errorMessage = 'Comment must be at least 10 characters';
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
        rating: _rating.toInt(),
        comment: _commentController.text.trim(),
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
        widget.onReviewSubmitted?.call();
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
  final bool hasExistingReview;
  final Map<String, dynamic>? existingReview;

  const QuickReviewButton({
    super.key,
    required this.taskId,
    required this.taskerId,
    required this.taskerName,
    required this.taskTitle,
    this.onReviewSubmitted,
    this.hasExistingReview = false,
    this.existingReview,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showReviewDialog(context),
      icon: Icon(hasExistingReview ? Icons.visibility : Icons.star),
      label: Text(hasExistingReview ? 'Reviewed' : 'Reviews'),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            hasExistingReview ? Colors.grey[600] : AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        taskId: taskId,
        taskerId: taskerId,
        taskerName: taskerName,
        taskTitle: taskTitle,
        onReviewSubmitted: onReviewSubmitted,
        readOnlyMode: hasExistingReview,
        existingReview: existingReview,
      ),
    );
  }
}
