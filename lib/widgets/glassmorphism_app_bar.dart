import 'package:flutter/material.dart';
import 'dart:ui';

/// 毛玻璃效果的 AppBar 組件
class GlassmorphismAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double blurRadius;
  final Color? backgroundColor;
  final Color? titleColor;
  final double elevation;
  final bool centerTitle;

  const GlassmorphismAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.blurRadius = 10.0,
    this.backgroundColor,
    this.titleColor,
    this.elevation = 0.0,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.2),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
          child: AppBar(
            title: Text(
              title,
              style: TextStyle(
                color: titleColor ?? colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: actions,
            leading: leading,
            automaticallyImplyLeading: automaticallyImplyLeading,
            backgroundColor: Colors.transparent,
            elevation: elevation,
            centerTitle: centerTitle,
            foregroundColor: titleColor ?? colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// 毛玻璃效果的 BottomNavigationBar 組件
class GlassmorphismBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int> onTap;
  final double blurRadius;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double elevation;

  const GlassmorphismBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.blurRadius = 10.0,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.2),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            items: items,
            onTap: onTap,
            backgroundColor: Colors.transparent,
            elevation: elevation,
            selectedItemColor: selectedItemColor ?? colorScheme.primary,
            unselectedItemColor:
                unselectedItemColor ?? colorScheme.onSurface.withOpacity(0.6),
            type: BottomNavigationBarType.fixed,
          ),
        ),
      ),
    );
  }
}

/// 毛玻璃效果的 Container 組件
class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final double blurRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final double? width;
  final double? height;

  const GlassmorphismContainer({
    super.key,
    required this.child,
    this.blurRadius = 10.0,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.2),
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: border ??
                Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 0.5,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 毛玻璃效果的 Card 組件
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final double blurRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Border? border;
  final double? elevation;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.blurRadius = 10.0,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withOpacity(0.2),
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              border: border ??
                  Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
              boxShadow: elevation != null
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: elevation!,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
