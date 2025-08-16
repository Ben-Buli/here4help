import 'package:flutter/material.dart';

/// 共享的未讀徽章組件
/// 可以在兩個分頁中重用，顯示未讀消息數量
class UnreadBadgeWidget extends StatelessWidget {
  final int unreadCount;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showZero;

  const UnreadBadgeWidget({
    super.key,
    required this.unreadCount,
    this.size = 20,
    this.backgroundColor,
    this.textColor,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    // 如果沒有未讀消息且不顯示零，則不顯示徽章
    if (unreadCount <= 0 && !showZero) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.error;
    final txtColor = textColor ?? theme.colorScheme.onError;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          unreadCount > 99 ? '99+' : unreadCount.toString(),
          style: TextStyle(
            color: txtColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 帶有未讀徽章的圖標組件
class IconWithUnreadBadge extends StatelessWidget {
  final IconData icon;
  final int unreadCount;
  final double iconSize;
  final double badgeSize;
  final Color? iconColor;
  final Color? badgeColor;
  final bool showZero;

  const IconWithUnreadBadge({
    super.key,
    required this.icon,
    required this.unreadCount,
    this.iconSize = 24,
    this.badgeSize = 16,
    this.iconColor,
    this.badgeColor,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: iconColor,
        ),
        Positioned(
          right: 0,
          top: 0,
          child: UnreadBadgeWidget(
            unreadCount: unreadCount,
            size: badgeSize,
            backgroundColor: badgeColor,
            showZero: showZero,
          ),
        ),
      ],
    );
  }
}

/// 帶有未讀徽章的文字組件
class TextWithUnreadBadge extends StatelessWidget {
  final String text;
  final int unreadCount;
  final TextStyle? textStyle;
  final double badgeSize;
  final Color? badgeColor;
  final bool showZero;

  const TextWithUnreadBadge({
    super.key,
    required this.text,
    required this.unreadCount,
    this.textStyle,
    this.badgeSize = 16,
    this.badgeColor,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: textStyle),
        const SizedBox(width: 4),
        UnreadBadgeWidget(
          unreadCount: unreadCount,
          size: badgeSize,
          backgroundColor: badgeColor,
          showZero: showZero,
        ),
      ],
    );
  }
}
