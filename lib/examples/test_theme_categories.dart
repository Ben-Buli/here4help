import 'package:flutter/material.dart';
import '../constants/theme_schemes.dart';
import '../services/theme_config_manager.dart';

/// 測試主題分類系統
class TestThemeCategories {
  static void testThemeCategorySystem() {
    print('=== 測試主題分類系統 ===');

    try {
      // 1. 檢查所有主題的 category 屬性
      print('\n1. 檢查所有主題的 category 屬性...');
      final allThemes = ThemeScheme.allThemes;

      final categoryCounts = <String, int>{};
      for (final theme in allThemes) {
        categoryCounts[theme.category] =
            (categoryCounts[theme.category] ?? 0) + 1;
        print('   ${theme.name}: ${theme.category}');
      }

      print('\n分類統計:');
      categoryCounts.forEach((category, count) {
        print('   $category: $count 個主題');
      });

      // 2. 測試 ThemeConfigManager 的分類邏輯
      print('\n2. 測試 ThemeConfigManager 的分類邏輯...');
      final themeManager = ThemeConfigManager();

      // 測試每個分類的主題
      for (final theme in allThemes) {
        final group = themeManager.groupedThemesWithDarkMode;
        final themeGroup = _getThemeGroupFromManager(themeManager, theme);

        print('   ${theme.name}:');
        print('     category: ${theme.category}');
        print('     themeGroup: $themeGroup');
        print(
            '     themeStyle: ${_getThemeStyleFromManager(themeManager, theme)}');

        // 驗證分類一致性
        if (theme.category.toLowerCase() == 'emotions' &&
            themeGroup != 'Emotions') {
          print('     ⚠️ 分類不一致：category=emotions 但 themeGroup=$themeGroup');
        } else if (theme.category.toLowerCase() == 'taiwan' &&
            themeGroup != 'Taiwan') {
          print('     ⚠️ 分類不一致：category=taiwan 但 themeGroup=$themeGroup');
        } else if (theme.category.toLowerCase() == 'ocean' &&
            themeGroup != 'Ocean') {
          print('     ⚠️ 分類不一致：category=ocean 但 themeGroup=$themeGroup');
        } else if (theme.category.toLowerCase() == 'morandi' &&
            themeGroup != 'Morandi') {
          print('     ⚠️ 分類不一致：category=morandi 但 themeGroup=$themeGroup');
        } else if (theme.category.toLowerCase() == 'business' &&
            themeGroup != 'Business') {
          print('     ⚠️ 分類不一致：category=business 但 themeGroup=$themeGroup');
        } else {
          print('     ✅ 分類一致');
        }
      }

      // 3. 測試特定主題的分類
      print('\n3. 測試特定主題的分類...');

      // 測試 H4H 主題
      final h4hTheme = null; // H4H theme has been removed
      if (h4hTheme != null) {
        print('   H4H 主題測試:');
        print('     category: ${h4hTheme.category}');
        print(
            '     themeGroup: ${_getThemeGroupFromManager(themeManager, h4hTheme)}');
        print(
            '     themeStyle: ${_getThemeStyleFromManager(themeManager, h4hTheme)}');

        if (h4hTheme.category == 'Emotions') {
          print('     ✅ H4H 主題正確分類為 Emotions');
        } else {
          print('     ❌ H4H 主題分類錯誤，期望 Emotions，實際 ${h4hTheme.category}');
        }
      }

      // 4. 測試分類的完整性
      print('\n4. 測試分類的完整性...');
      final expectedCategories = [
        'morandi',
        'ocean',
        'business',
        'emotions',
        'taiwan',
        'glassmorphism',
        'experimental'
      ];
      final actualCategories =
          allThemes.map((t) => t.category.toLowerCase()).toSet();

      print('   預期分類: $expectedCategories');
      print('   實際分類: ${actualCategories.toList()}');

      final missingCategories = expectedCategories
          .where((cat) => !actualCategories.contains(cat))
          .toList();
      final extraCategories = actualCategories
          .where((cat) => !expectedCategories.contains(cat))
          .toList();

      if (missingCategories.isEmpty && extraCategories.isEmpty) {
        print('   ✅ 分類完整，沒有遺漏或多余的分類');
      } else {
        if (missingCategories.isNotEmpty) {
          print('   ⚠️ 遺漏的分類: $missingCategories');
        }
        if (extraCategories.isNotEmpty) {
          print('   ⚠️ 多余的分類: $extraCategories');
        }
      }

      print('\n=== 測試完成 ===');
    } catch (e) {
      print('❌ 測試失敗: $e');
      print('錯誤堆疊: ${StackTrace.current}');
    }
  }

  /// 從 ThemeConfigManager 獲取主題組
  static String _getThemeGroupFromManager(
      ThemeConfigManager manager, ThemeScheme theme) {
    try {
      // 創建一個臨時的主題管理器來測試特定主題
      final tempManager = ThemeConfigManager();
      tempManager.setTheme(theme);

      // 獲取分組後的主題
      final grouped = tempManager.groupedThemesWithDarkMode;

      // 查找主題所在的組
      for (final entry in grouped.entries) {
        if (entry.value.any((t) => t.name == theme.name)) {
          return entry.key;
        }
      }

      return 'Unknown';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// 從 ThemeConfigManager 獲取主題風格
  static String _getThemeStyleFromManager(
      ThemeConfigManager manager, ThemeScheme theme) {
    try {
      // 創建一個臨時的主題管理器來測試特定主題
      final tempManager = ThemeConfigManager();
      tempManager.setTheme(theme);

      return tempManager.themeStyle;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// 測試特定分類的主題
  static void testSpecificCategory(String category) {
    print('=== 測試 $category 分類 ===');

    try {
      final allThemes = ThemeScheme.allThemes;
      final categoryThemes = allThemes
          .where((t) => t.category.toLowerCase() == category.toLowerCase())
          .toList();

      print('$category 分類主題數量: ${categoryThemes.length}');
      print('主題列表:');

      for (final theme in categoryThemes) {
        print('   - ${theme.name}: ${theme.displayName}');
        print('     primary: ${theme.primary}');
        print('     secondary: ${theme.secondary}');
        print('     background: ${theme.background}');
      }

      // 測試 ThemeConfigManager 的分類
      final themeManager = ThemeConfigManager();
      final grouped = themeManager.groupedThemesWithDarkMode;

      String? groupName;
      for (final entry in grouped.entries) {
        if (entry.value.any((t) => t.name == categoryThemes.first.name)) {
          groupName = entry.key;
          break;
        }
      }

      print('\nThemeConfigManager 分類: $groupName');
    } catch (e) {
      print('❌ 測試失敗: $e');
    }
  }
}
