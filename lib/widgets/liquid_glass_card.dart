import 'dart:ui';
import 'package:flutter/material.dart';

/// 液態玻璃風格卡片組件
///
/// 主要特徵：
/// 1. 半透明 + 模糊背景 (Gaussian Blur)
/// 2. 光影與折射感 (高光、陰影、漸層)
/// 3. 柔和色彩與漸層 (低飽和度)
/// 4. 圓角與流線型形狀 (Border Radius)
/// 5. 層次感 (多層玻璃板效果)
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double opacity;
  final Color? backgroundColor;
  final bool enableBorder;
  final bool enableShadow;
  final VoidCallback? onTap;
  final double blurSigma;

  const LiquidGlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.opacity = 0.15,
    this.backgroundColor,
    this.enableBorder = true,
    this.enableShadow = true,
    this.onTap,
    this.blurSigma = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 根據主題選擇玻璃背景色
    final glassColor = backgroundColor ??
        (isDark
            ? Colors.white.withOpacity(opacity * 0.8)
            : Colors.white.withOpacity(opacity));

    // 邊框顏色 - 亮邊框效果
    final borderColor =
        isDark ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.7);

    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // 多層漸層效果
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glassColor.withOpacity(opacity + 0.1), // 較亮的左上角
            glassColor.withOpacity(opacity), // 基礎透明度
            glassColor.withOpacity(opacity - 0.05), // 較暗的右下角
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        // 亮邊框
        border: enableBorder
            ? Border.all(
                color: borderColor,
                width: 1.0,
              )
            : null,
        // 柔和投影
        boxShadow: enableShadow
            ? [
                // 主要陰影
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                // 內陰影效果
                BoxShadow(
                  color: Colors.white.withOpacity(isDark ? 0.05 : 0.3),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: child,
    );

    // 背景模糊效果
    Widget blurredCard = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: cardContent,
      ),
    );

    // 添加點擊效果
    if (onTap != null) {
      blurredCard = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: colorScheme.primary.withOpacity(0.1),
          highlightColor: colorScheme.primary.withOpacity(0.05),
          child: blurredCard,
        ),
      );
    }

    return Container(
      margin: margin,
      child: blurredCard,
    );
  }
}

/// 液態玻璃風格變體 - 用於不同場景
class LiquidGlassVariants {
  /// 任務卡片專用風格
  static LiquidGlassCard taskCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry? margin,
  }) {
    return LiquidGlassCard(
      borderRadius: 20.0,
      padding: const EdgeInsets.all(16),
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      opacity: 0.12,
      enableBorder: true,
      enableShadow: true,
      onTap: onTap,
      blurSigma: 15.0,
      child: child,
    );
  }

  /// 操作欄專用風格
  static LiquidGlassCard actionBar({
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    return LiquidGlassCard(
      borderRadius: 16.0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: margin,
      opacity: 0.08,
      enableBorder: true,
      enableShadow: false,
      blurSigma: 8.0,
      child: child,
    );
  }

  /// 浮動對話框專用風格
  static LiquidGlassCard dialog({
    required Widget child,
  }) {
    return LiquidGlassCard(
      borderRadius: 28.0,
      padding: const EdgeInsets.all(24),
      opacity: 0.25,
      enableBorder: true,
      enableShadow: true,
      blurSigma: 20.0,
      child: child,
    );
  }

  /// 微妙變體 - 用於不希望太突出的元素
  static LiquidGlassCard subtle({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return LiquidGlassCard(
      borderRadius: 16.0,
      padding: padding ?? const EdgeInsets.all(12),
      margin: margin,
      opacity: 0.06,
      enableBorder: false,
      enableShadow: false,
      onTap: onTap,
      blurSigma: 6.0,
      child: child,
    );
  }
}
