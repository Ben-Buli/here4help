import 'package:flutter/material.dart';

/// 同意完成二次確認 Dialog
class ConfirmCompletionDialog extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final Future<Map<String, dynamic>> Function() onPreview;
  final Future<void> Function() onConfirm;

  const ConfirmCompletionDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.onPreview,
    required this.onConfirm,
  });

  @override
  State<ConfirmCompletionDialog> createState() =>
      _ConfirmCompletionDialogState();
}

class _ConfirmCompletionDialogState extends State<ConfirmCompletionDialog> {
  bool _isLoading = true;
  bool _isConfirming = false;
  Map<String, dynamic>? _previewData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await widget.onPreview();
      setState(() {
        _previewData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Completion'),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading preview...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 32),
              const SizedBox(height: 8),
              Text(
                'Failed to load preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_previewData == null) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('No preview data available'),
        ),
      );
    }

    final data = _previewData!;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final fee = (data['fee'] as num?)?.toDouble() ?? 0.0;
    final net = (data['net'] as num?)?.toDouble() ?? 0.0;
    final feeRate = (data['fee_rate'] as num?)?.toDouble() ?? 0.0;

    return Column(
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
          'Please review the completion details:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Task Reward', '\$${amount.toStringAsFixed(2)}'),
        _buildInfoRow('Service Fee (${(feeRate * 100).toStringAsFixed(1)}%)',
            '\$${fee.toStringAsFixed(2)}'),
        const Divider(),
        _buildInfoRow(
          'Net Amount',
          '\$${net.toStringAsFixed(2)}',
          isTotal: true,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This action will transfer the reward points to the tasker.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isLoading) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loadPreview,
          child: const Text('Retry'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isConfirming ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _isConfirming ? null : _handleConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        child: _isConfirming
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Confirm'),
      ),
    ];
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isConfirming = true;
    });

    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm completion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }
}
