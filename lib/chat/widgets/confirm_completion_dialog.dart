import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';

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
    final theme = Theme.of(context);
    final themeManager = context.watch<ThemeConfigManager>();
    final dialogBackground =
        theme.dialogTheme.backgroundColor ?? themeManager.dialogBackgroundColor;

    return AlertDialog(
      backgroundColor: dialogBackground,
      shape: theme.dialogTheme.shape,
      titleTextStyle: theme.dialogTheme.titleTextStyle,
      contentTextStyle: theme.dialogTheme.contentTextStyle,
      title: const Text('Confirm Completion'),
      content: _buildContent(themeManager),
      actions: _buildActions(themeManager.dialogPrimaryColor),
    );
  }

  Widget _buildContent(ThemeConfigManager themeManager) {
    final theme = Theme.of(context);
    final primaryColor = themeManager.dialogPrimaryColor;
    final infoBackground =
        Color.alphaBlend(primaryColor.withOpacity(0.12), Colors.white);
    final infoBorder = primaryColor.withOpacity(0.2);
    final subduedText = themeManager.dialogContentColor.withOpacity(0.75);

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
      final errorColor = theme.colorScheme.error;
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: errorColor, size: 32),
              const SizedBox(height: 8),
              Text(
                'Failed to load preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: errorColor,
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
        Text(
          'Please review the completion details:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: themeManager.dialogTitleColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          'Task Reward',
          '\$${amount.toStringAsFixed(2)}',
          primaryColor,
          subduedText,
        ),
        _buildInfoRow('Service Fee (${(feeRate * 100).toStringAsFixed(1)}%)',
            '\$${fee.toStringAsFixed(2)}', primaryColor, subduedText),
        const Divider(),
        _buildInfoRow(
          'Net Amount',
          '\$${net.toStringAsFixed(2)}',
          primaryColor,
          subduedText,
          isTotal: true,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: infoBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: infoBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This action will transfer the reward points to the tasker.',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color primary, Color secondary,
      {bool isTotal = false}) {
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
              color: isTotal ? primary : secondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? primary : secondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(Color primaryColor) {
    if (_isLoading) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: primaryColor),
          child: const Text('Cancel'),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: primaryColor),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loadPreview,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Retry'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isConfirming ? null : () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(foregroundColor: primaryColor),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _isConfirming ? null : _handleConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
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
