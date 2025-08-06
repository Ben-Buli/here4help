import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';

class FormCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool isRequired;
  final bool isError;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const FormCard({
    super.key,
    required this.title,
    this.icon,
    this.isRequired = false,
    this.isError = false,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題行
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: theme.primary, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.primary,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // 卡片內容
          Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isError
                    ? Colors.red
                    : theme.outlineVariant.withOpacity(0.3),
                width: isError ? 2 : 1,
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
