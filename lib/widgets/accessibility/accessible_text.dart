import 'package:flutter/material.dart';
import '../../services/accessibility/font_size_service.dart';

/// 無障礙文字組件
/// 自動應用字級縮放和可讀性檢查
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final bool checkReadability;

  const AccessibleText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.checkReadability = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FontSizeService.instance,
      builder: (context, child) {
        final fontService = FontSizeService.instance;
        final scaledStyle = style != null 
            ? fontService.getScaledTextStyle(style!)
            : TextStyle(fontSize: fontService.getScaledFontSize(14.0));

        // 可讀性檢查
        if (checkReadability) {
          final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
          if (!fontService.isReadable(scaledStyle, backgroundColor)) {
            debugPrint('AccessibleText: 可讀性警告 - 文字對比度不足');
          }
        }

        return Semantics(
          label: semanticsLabel ?? text,
          child: Text(
            text,
            style: scaledStyle,
            textAlign: textAlign,
            overflow: overflow,
            maxLines: maxLines,
          ),
        );
      },
    );
  }
}

/// 無障礙標題組件
class AccessibleHeading extends StatelessWidget {
  final String text;
  final int level; // 1-6, 對應 H1-H6
  final TextStyle? style;
  final TextAlign? textAlign;

  const AccessibleHeading(
    this.text, {
    Key? key,
    this.level = 1,
    this.style,
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = _getHeadingStyle(theme, level);
    final finalStyle = style != null ? defaultStyle.merge(style) : defaultStyle;

    return Semantics(
      header: true,
      child: AccessibleText(
        text,
        style: finalStyle,
        textAlign: textAlign,
        semanticsLabel: 'Heading level $level: $text',
      ),
    );
  }

  TextStyle _getHeadingStyle(ThemeData theme, int level) {
    switch (level) {
      case 1:
        return theme.textTheme.headlineLarge ?? const TextStyle(fontSize: 32, fontWeight: FontWeight.bold);
      case 2:
        return theme.textTheme.headlineMedium ?? const TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
      case 3:
        return theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
      case 4:
        return theme.textTheme.titleLarge ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
      case 5:
        return theme.textTheme.titleMedium ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
      case 6:
        return theme.textTheme.titleSmall ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
      default:
        return theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    }
  }
}

/// 無障礙按鈕組件
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
  final String? tooltip;
  final ButtonStyle? style;

  const AccessibleButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.semanticsLabel,
    this.tooltip,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget button = ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel,
      child: button,
    );
  }
}
