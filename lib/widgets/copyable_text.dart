import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableText extends StatelessWidget {
  final String text;
  final String? displayText;
  final TextStyle? textStyle;
  final String? copyMessage;
  final IconData? copyIcon;
  final double iconSize;
  final Color? iconColor;

  const CopyableText({
    super.key,
    required this.text,
    this.displayText,
    this.textStyle,
    this.copyMessage,
    this.copyIcon = Icons.copy,
    this.iconSize = 16.0,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayText ?? text,
          style: textStyle,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _copyToClipboard(context),
          child: Tooltip(
            message: 'Copy to clipboard',
            child: Icon(
              copyIcon,
              size: iconSize,
              color: iconColor ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));

    // 顯示複製成功的 SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copyMessage ?? 'Copied to clipboard: $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// 銀行資訊專用的複製文字組件
class BankInfoCopyableText extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const BankInfoCopyableText({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: labelStyle ?? const TextStyle(fontSize: 12),
        ),
        Expanded(
          child: CopyableText(
            text: value,
            textStyle: valueStyle ?? const TextStyle(fontSize: 12),
            copyMessage: 'Copied $label: $value',
            iconSize: 14.0,
          ),
        ),
      ],
    );
  }
}
