import 'package:flutter/material.dart';

/// 主題分類枚舉
enum ThemeCategory {
  morandi('Morandi', Icons.palette, 'Elegant Morandi style theme collection'),
  ocean('Ocean', Icons.beach_access, 'Refreshing ocean style theme collection'),
  business('Business', Icons.business,
      'Professional business style theme collection'),
  emotions(
      'Emotions', Icons.favorite, 'Rich emotional expression theme collection'),
  taiwan('Taiwan', Icons.location_on, 'Themes with Taiwanese characteristics'),
  glassmorphism('Glassmorphism', Icons.blur_on,
      'Modern glassmorphism effect theme collection'),
  experimental('Experimental', Icons.science,
      'Innovative experimental theme collection');

  const ThemeCategory(this.displayName, this.icon, this.description);

  final String displayName;
  final IconData icon;
  final String description;
}

/// 主題分類管理器
class ThemeCategoryManager {
  static final Map<ThemeCategory, List<String>> _categoryThemes = {};

  /// 初始化分類主題映射
  static void initializeCategoryThemes() {
    _categoryThemes.clear();

    // 根據 ThemeScheme.allThemes 中的實際分類來填充
    // 這裡我們手動定義分類，因為 ThemeScheme 已經有 category 屬性
    _categoryThemes[ThemeCategory.morandi] = [
      'morandi_blue',
      'morandi_green',
      'morandi_purple',
      'morandi_pink',
      'morandi_orange',
      'morandi_lemon',
    ];

    _categoryThemes[ThemeCategory.ocean] = [
      'beach_sunset',
      'ocean_gradient',
      'sandy_footprints',
      'sunset_beach',
      'clownfish',
      'patrick_star',
    ];

    _categoryThemes[ThemeCategory.business] = [
      'main_style',
      'meta_business_style',
      'business_gradient',
      'glassmorphism_blur',
      'glassmorphism_blue_grey',
    ];

    _categoryThemes[ThemeCategory.emotions] = [
      'rainbow_pride',
      'blue_pink',
      'pink_theme',
      'yellow_white_purple',
      'bear_gay_flat',
      'pride_s_curve',
    ];

    _categoryThemes[ThemeCategory.taiwan] = [
      'milk_tea_earth',
      'minimalist_still',
      'taipei_2019_pantone',
      'taipei_101',
    ];

    _categoryThemes[ThemeCategory.glassmorphism] = [
      'glassmorphism_blur',
      'glassmorphism_blue_grey',
    ];

    _categoryThemes[ThemeCategory.experimental] = [
      'main_style',
    ];
  }

  /// 獲取指定分類的所有主題名稱
  static List<String> getThemeNamesByCategory(ThemeCategory category) {
    return _categoryThemes[category] ?? [];
  }

  /// 獲取所有分類的主題名稱
  static Map<ThemeCategory, List<String>> getAllCategoryThemes() {
    return Map.unmodifiable(_categoryThemes);
  }

  /// 獲取所有主題名稱
  static List<String> getAllThemeNames() {
    return _categoryThemes.values.expand((names) => names).toList();
  }

  /// 根據名稱查找主題分類
  static ThemeCategory? findCategoryByThemeName(String themeName) {
    for (final entry in _categoryThemes.entries) {
      if (entry.value.contains(themeName)) {
        return entry.key;
      }
    }
    return null;
  }

  /// 獲取主題統計信息
  static Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{};
    for (final category in ThemeCategory.values) {
      final themeNames = _categoryThemes[category] ?? [];
      stats[category.displayName] = {
        'count': themeNames.length,
        'icon': category.icon.codePoint,
        'description': category.description,
        'themes': themeNames,
      };
    }
    return stats;
  }
}

/// 初始化分類系統
void initializeThemeCategories() {
  ThemeCategoryManager.initializeCategoryThemes();
}
