import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// 客服事件結案 Dialog（評分 + 評論必填）
class SupportSolvedDialog extends StatefulWidget {
  final String? eventTitle;
  final VoidCallback? onCancel;
  final Function(int rating, String review)? onSubmit;

  const SupportSolvedDialog({
    super.key,
    this.eventTitle,
    this.onCancel,
    this.onSubmit,
  });

  @override
  State<SupportSolvedDialog> createState() => _SupportSolvedDialogState();
}

class _SupportSolvedDialogState extends State<SupportSolvedDialog> {
  double _rating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;
  String? _reviewError;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _reviewController.text.trim().isNotEmpty && !_isSubmitting;
  }

  void _validateReview() {
    setState(() {
      final reviewText = _reviewController.text.trim();
      if (reviewText.isEmpty) {
        _reviewError = 'Review is required';
      } else if (reviewText.length < 10) {
        _reviewError = 'Review must be at least 10 characters';
      } else {
        _reviewError = null;
      }
    });
  }

  Future<void> _handleSubmit() async {
    _validateReview();

    if (!_canSubmit || _reviewError != null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit
          ?.call(_rating.toInt(), _reviewController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCancel() {
    widget.onCancel?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Close Support Case',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : _handleCancel,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Title
                    if (widget.eventTitle != null) ...[
                      Text(
                        'Event: ${widget.eventTitle}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Description
                    const Text(
                      'Please rate your support experience and provide feedback:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rating Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rating *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Column(
                            children: [
                              RatingBar.builder(
                                initialRating: _rating,
                                minRating: 1,
                                direction: Axis.horizontal,
                                allowHalfRating: false,
                                itemCount: 5,
                                itemSize: 40,
                                itemPadding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                onRatingUpdate: (rating) {
                                  setState(() {
                                    _rating = rating;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getRatingText(_rating.toInt()),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Review Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reviewController,
                          maxLines: 4,
                          maxLength: 500,
                          enabled: !_isSubmitting,
                          decoration: InputDecoration(
                            hintText:
                                'Please describe your experience with our support team...',
                            border: const OutlineInputBorder(),
                            errorText: _reviewError,
                            counterText: '${_reviewController.text.length}/500',
                          ),
                          onChanged: (_) {
                            setState(() {
                              _reviewError = null;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : _handleCancel,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _canSubmit ? _handleSubmit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Very Poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

/// 顯示 Support Solved Dialog 的便利方法
Future<bool?> showSupportSolvedDialog({
  required BuildContext context,
  String? eventTitle,
  required Function(int rating, String review) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SupportSolvedDialog(
      eventTitle: eventTitle,
      onSubmit: onSubmit,
    ),
  );
}
