import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_service.dart';

/// 主題感知的圖標
class ThemeAwareIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const ThemeAwareIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Icon(
          icon,
          size: size,
          color: color ?? themeService.currentTheme.primary,
        );
      },
    );
  }
}

/// 主題感知的圓形徽章
class ThemeAwareCircleBadge extends StatelessWidget {
  final String text;
  final double size;
  final double fontSize;

  const ThemeAwareCircleBadge({
    super.key,
    required this.text,
    this.size = 16,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: themeService.currentTheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: themeService.currentTheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        );
      },
    );
  }
}

/// 主題感知的容器
class ThemeAwareContainer extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  const ThemeAwareContainer({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Container(
          padding: padding,
          margin: margin,
          decoration: BoxDecoration(
            color: backgroundColor ?? themeService.currentTheme.primary,
            borderRadius: borderRadius,
            border: border,
          ),
          child: this.child,
        );
      },
    );
  }
}

/// 主題感知的文字
class ThemeAwareText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  const ThemeAwareText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Text(
          text,
          style: style?.copyWith(
                color: style?.color ?? themeService.currentTheme.onSurface,
              ) ??
              TextStyle(
                color: themeService.currentTheme.onSurface,
              ),
          textAlign: textAlign,
          maxLines: maxLines,
        );
      },
    );
  }
}

/// 主題感知的按鈕
class ThemeAwareButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const ThemeAwareButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return SizedBox(
          width: width,
          height: height,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeService.currentTheme.primary,
              foregroundColor: themeService.currentTheme.onPrimary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        themeService.currentTheme.onPrimary,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(text),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
