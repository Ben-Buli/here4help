import 'package:flutter/material.dart';

/// 駁回完成理由輸入 Dialog
class DisagreeCompletionDialog extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final Function(String reason) onDisagreeSubmitted;

  const DisagreeCompletionDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.onDisagreeSubmitted,
  });

  @override
  State<DisagreeCompletionDialog> createState() =>
      _DisagreeCompletionDialogState();
}

class _DisagreeCompletionDialogState extends State<DisagreeCompletionDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disagree Completion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task: ${widget.taskTitle}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Please provide a reason for disagreeing with the completion:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Enter your reason...',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_reasonController.text.length}/300',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
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
              : const Text('Disagree'),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    final reason = _reasonController.text.trim();

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for disagreeing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onDisagreeSubmitted(reason);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit disagree: $e'),
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
}
