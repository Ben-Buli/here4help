import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';

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
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return Icon(
          icon,
          size: size,
          color: color ?? themeManager.currentTheme.primary,
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
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: themeManager.currentTheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: themeManager.currentTheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        );
      },
    );
  }
}

/// 主題感知的輸入欄位組件
class ThemeAwareTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool filled;
  final EdgeInsetsGeometry? contentPadding;

  const ThemeAwareTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.filled = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;

        return TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: filled,
            fillColor: theme.surface.withOpacity(0.8), // 使用主題表面色作為背景
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.secondary.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.secondary.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.error, width: 2),
            ),
            labelStyle: TextStyle(
              color: theme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            hintStyle: TextStyle(
              color: theme.onSurface.withOpacity(0.5),
            ),
            errorStyle: TextStyle(
              color: theme.error,
              fontSize: 12,
            ),
          ),
          style: TextStyle(
            color: theme.onSurface,
            fontSize: 16,
          ),
        );
      },
    );
  }
}

/// 主題感知的下拉選單組件
class ThemeAwareDropdownButtonFormField<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String? Function(T?)? validator;
  final void Function(T?)? onChanged;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final String Function(T) itemTextBuilder;
  final bool filled;
  final EdgeInsetsGeometry? contentPadding;

  const ThemeAwareDropdownButtonFormField({
    super.key,
    required this.value,
    required this.items,
    required this.itemTextBuilder,
    this.validator,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.filled = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;

        return DropdownButtonFormField<T>(
          value: value,
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemTextBuilder(item),
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 16,
                ),
              ),
            );
          }).toList(),
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: prefixIcon,
            filled: filled,
            fillColor: theme.surface.withOpacity(0.8), // 使用主題表面色作為背景
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.secondary.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.secondary.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.error, width: 2),
            ),
            labelStyle: TextStyle(
              color: theme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            hintStyle: TextStyle(
              color: theme.onSurface.withOpacity(0.5),
            ),
            errorStyle: TextStyle(
              color: theme.error,
              fontSize: 12,
            ),
          ),
          dropdownColor: theme.surface.withOpacity(0.95), // 下拉選單背景色
          icon: Icon(
            Icons.arrow_drop_down,
            color: theme.primary,
          ),
          style: TextStyle(
            color: theme.onSurface,
            fontSize: 16,
          ),
        );
      },
    );
  }
}

/// 主題感知的容器組件（用於替換白色背景）
class ThemeAwareContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool useSurfaceColor;
  final double opacity;

  const ThemeAwareContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.useSurfaceColor = true,
    this.opacity = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;

        return Container(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          decoration: BoxDecoration(
            color: useSurfaceColor
                ? theme.surface.withOpacity(opacity)
                : Colors.transparent,
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: useSurfaceColor
                ? Border.all(
                    color: theme.secondary.withOpacity(0.2),
                    width: 1,
                  )
                : null,
          ),
          child: child,
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
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return Text(
          text,
          style: style?.copyWith(
                color: style?.color ?? themeManager.currentTheme.onSurface,
              ) ??
              TextStyle(
                color: themeManager.currentTheme.onSurface,
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
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return SizedBox(
          width: width,
          height: height,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeManager.currentTheme.primary,
              foregroundColor: themeManager.currentTheme.onPrimary,
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
                        themeManager.currentTheme.onPrimary,
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
