import 'package:flutter/material.dart';
import 'package:here4help/constants/theme_schemes.dart';

/// 帶有模糊背景效果的下拉選單
class BlurredDropdown<T> extends StatelessWidget {
  final String? hint;
  final T? value;
  final List<T> items;
  final String Function(T) itemToString;
  final void Function(T?) onChanged;
  final ThemeScheme theme;
  final double? blurRadius;
  final Color? backgroundColor;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isExpanded;
  final InputBorder? border;
  final EdgeInsetsGeometry? contentPadding;

  const BlurredDropdown({
    super.key,
    this.hint,
    required this.value,
    required this.items,
    required this.itemToString,
    required this.onChanged,
    required this.theme,
    this.blurRadius,
    this.backgroundColor,
    this.prefixIcon,
    this.suffixIcon,
    this.isExpanded = true,
    this.border,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return theme.createBlurredDropdownBackground(
      blurRadius: blurRadius,
      backgroundColor: backgroundColor,
      child: DropdownButtonFormField<T>(
        value: value,
        hint: hint != null ? Text(hint!) : null,
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemToString(item),
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 16,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        isExpanded: isExpanded,
        decoration: InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: border ??
              OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primary.withOpacity(0.3)),
              ),
          enabledBorder: border ??
              OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primary.withOpacity(0.3)),
              ),
          focusedBorder: border ??
              OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primary, width: 2),
              ),
          contentPadding: contentPadding ??
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
          filled: false, // 不填滿背景，讓模糊效果顯示
        ),
        dropdownColor: Colors.transparent, // 讓下拉選單背景透明
        icon: Icon(
          Icons.arrow_drop_down,
          color: theme.primary,
        ),
        style: TextStyle(
          color: theme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// 帶有模糊背景效果的彈出選單
class BlurredPopupMenuButton<T> extends StatelessWidget {
  final Widget child;
  final List<PopupMenuEntry<T>> itemBuilder;
  final void Function(T)? onSelected;
  final ThemeScheme theme;
  final double? blurRadius;
  final Color? backgroundColor;
  final Offset? offset;
  final bool enabled;

  const BlurredPopupMenuButton({
    super.key,
    required this.child,
    required this.itemBuilder,
    this.onSelected,
    required this.theme,
    this.blurRadius,
    this.backgroundColor,
    this.offset,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      itemBuilder: (context) => itemBuilder,
      onSelected: onSelected,
      enabled: enabled,
      offset: offset ?? const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.transparent, // 讓彈出選單背景透明
      elevation: 0,
      child: child,
    );
  }
}
