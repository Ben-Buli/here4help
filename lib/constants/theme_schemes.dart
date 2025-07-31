import 'package:flutter/material.dart';

/// 主題色系配置
class ThemeScheme {
  final String name;
  final String displayName;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color onPrimary;
  final Color onSecondary;
  final Color onBackground;
  final Color onSurface;
  final Color error;
  final Color onError;
  final Color success;
  final Color warning;
  final Color shadow;

  const ThemeScheme({
    required this.name,
    required this.displayName,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.onPrimary,
    required this.onSecondary,
    required this.onBackground,
    required this.onSurface,
    required this.error,
    required this.onError,
    required this.success,
    required this.warning,
    required this.shadow,
  });

  /// 莫蘭迪藍色系
  static const ThemeScheme morandiBlue = ThemeScheme(
    name: 'morandi_blue',
    displayName: 'Morandi Blue',
    primary: Color(0xFF7B8A95),
    secondary: Color(0xFF9BA8B4),
    accent: Color(0xFFB8C5D1),
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFF8FAFC),
    onPrimary: Color(0xFFF8FAFC),
    onSecondary: Color(0xFF2D3748),
    onBackground: Color(0xFF2D3748),
    onSurface: Color(0xFF2D3748),
    error: Color(0xFFB56576),
    onError: Color(0xFFF8FAFC),
    success: Color(0xFF8FBC8F),
    warning: Color(0xFFD4A574),
    shadow: Color(0xFF5A6B7A),
  );

  /// 莫蘭迪綠色系
  static const ThemeScheme morandiGreen = ThemeScheme(
    name: 'morandi_green',
    displayName: 'Morandi Green',
    primary: Color(0xFF8FBC8F),
    secondary: Color(0xFFA8C5A8),
    accent: Color(0xFFC5D4C5),
    background: Color(0xFFF8FCF8),
    surface: Color(0xFFF8FCF8),
    onPrimary: Color(0xFFF8FCF8),
    onSecondary: Color(0xFF2D482D),
    onBackground: Color(0xFF2D482D),
    onSurface: Color(0xFF2D482D),
    error: Color(0xFFB56576),
    onError: Color(0xFFF8FCF8),
    success: Color(0xFF7B8A95),
    warning: Color(0xFFD4A574),
    shadow: Color(0xFF5A7A5A),
  );

  /// 莫蘭迪紫色系
  static const ThemeScheme morandiPurple = ThemeScheme(
    name: 'morandi_purple',
    displayName: 'Morandi Purple',
    primary: Color(0xFF9B8A95),
    secondary: Color(0xFFB4A8B4),
    accent: Color(0xFFD1C5D1),
    background: Color(0xFFFCF8FC),
    surface: Color(0xFFFCF8FC),
    onPrimary: Color(0xFFFCF8FC),
    onSecondary: Color(0xFF482D48),
    onBackground: Color(0xFF482D48),
    onSurface: Color(0xFF482D48),
    error: Color(0xFFB56576),
    onError: Color(0xFFFCF8FC),
    success: Color(0xFF8FBC8F),
    warning: Color(0xFFD4A574),
    shadow: Color(0xFF7A5A7A),
  );

  /// 莫蘭迪粉色系
  static const ThemeScheme morandiPink = ThemeScheme(
    name: 'morandi_pink',
    displayName: 'Morandi Pink',
    primary: Color(0xFFB56576),
    secondary: Color(0xFFC5A8B4),
    accent: Color(0xFFD1C5D1),
    background: Color(0xFFFCF8FA),
    surface: Color(0xFFFCF8FA),
    onPrimary: Color(0xFFFCF8FA),
    onSecondary: Color(0xFF482D37),
    onBackground: Color(0xFF482D37),
    onSurface: Color(0xFF482D37),
    error: Color(0xFF7B8A95),
    onError: Color(0xFFFCF8FA),
    success: Color(0xFF8FBC8F),
    warning: Color(0xFFD4A574),
    shadow: Color(0xFF7A5A6B),
  );

  /// 莫蘭迪橙色系
  static const ThemeScheme morandiOrange = ThemeScheme(
    name: 'morandi_orange',
    displayName: 'Morandi Orange',
    primary: Color(0xFFD4A574),
    secondary: Color(0xFFE0B8A8),
    accent: Color(0xFFECD1C5),
    background: Color(0xFFFCFAF8),
    surface: Color(0xFFFCFAF8),
    onPrimary: Color(0xFFFCFAF8),
    onSecondary: Color(0xFF48372D),
    onBackground: Color(0xFF48372D),
    onSurface: Color(0xFF48372D),
    error: Color(0xFFB56576),
    onError: Color(0xFFFCFAF8),
    success: Color(0xFF8FBC8F),
    warning: Color(0xFF7B8A95),
    shadow: Color(0xFF7A6B5A),
  );

  /// 深色主題
  static const ThemeScheme darkTheme = ThemeScheme(
    name: 'dark_theme',
    displayName: 'Dark Theme',
    primary: Color(0xFF2D3748),
    secondary: Color(0xFF4A5568),
    accent: Color(0xFF718096),
    background: Color(0xFF1A202C),
    surface: Color(0xFF2D3748),
    onPrimary: Color(0xFFF7FAFC),
    onSecondary: Color(0xFFF7FAFC),
    onBackground: Color(0xFFF7FAFC),
    onSurface: Color(0xFFF7FAFC),
    error: Color(0xFFE53E3E),
    onError: Color(0xFFF7FAFC),
    success: Color(0xFF38A169),
    warning: Color(0xFFD69E2E),
    shadow: Color(0xFF000000),
  );

  /// 所有可用主題
  static const List<ThemeScheme> allThemes = [
    morandiBlue,
    morandiGreen,
    morandiPurple,
    morandiPink,
    morandiOrange,
    darkTheme,
  ];

  /// 根據名稱獲取主題
  static ThemeScheme getByName(String name) {
    return allThemes.firstWhere(
      (theme) => theme.name == name,
      orElse: () => morandiBlue,
    );
  }

  /// 轉換為 Material ThemeData
  ThemeData toThemeData() {
    return ThemeData(
      scaffoldBackgroundColor: background,
      splashColor: accent,
      highlightColor: accent,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        foregroundColor: onPrimary,
        shadowColor: shadow,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
      ).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        surface: surface,
        onSurface: onSurface,
        error: error,
        onError: onError,
      ),
      useMaterial3: true,
    );
  }
}
