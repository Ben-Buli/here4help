import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/theme_schemes.dart';

/// 主題管理服務
class ThemeManagementService {
  static final ThemeManagementService _instance =
      ThemeManagementService._internal();
  factory ThemeManagementService() => _instance;
  ThemeManagementService._internal();

  /// 當前主題
  ThemeScheme? _currentTheme;

  /// 主題變更回調
  final List<Function(ThemeScheme)> _themeChangeCallbacks = [];

  /// 主題分類快取
  final Map<String, List<ThemeScheme>> _categoryCache = {};

  /// 主題統計快取
  Map<String, dynamic>? _statisticsCache;

  /// 獲取當前主題
  ThemeScheme get currentTheme => _currentTheme ?? ThemeScheme.mainStyle;

  /// 設置當前主題
  void setCurrentTheme(ThemeScheme theme) {
    if (_currentTheme?.name != theme.name) {
      _currentTheme = theme;
      _notifyThemeChange(theme);
    }
  }

  /// 根據名稱設置主題
  void setThemeByName(String name) {
    final theme = ThemeScheme.getByName(name);
    setCurrentTheme(theme);
  }

  /// 根據分類獲取主題
  List<ThemeScheme> getThemesByCategory(String category) {
    if (!_categoryCache.containsKey(category)) {
      _categoryCache[category] = ThemeScheme.allThemes
          .where((theme) => theme.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    return _categoryCache[category]!;
  }

  /// 獲取所有主題
  List<ThemeScheme> getAllThemes() {
    return ThemeScheme.allThemes;
  }

  /// 獲取主題統計信息
  Map<String, dynamic> getThemeStatistics() {
    _statisticsCache ??= _generateThemeStatistics();
    return _statisticsCache!;
  }

  /// 生成主題統計信息
  Map<String, dynamic> _generateThemeStatistics() {
    final allThemes = getAllThemes();
    final categoryCounts = <String, int>{};
    
    for (final theme in allThemes) {
      categoryCounts[theme.category] = (categoryCounts[theme.category] ?? 0) + 1;
    }
    
    return {
      'total_themes': allThemes.length,
      'built_in_themes': allThemes.length,
      'current_theme': _currentTheme?.name ?? 'main_style',
      'category_counts': categoryCounts,
    };
  }

  /// 搜索主題
  List<ThemeScheme> searchThemes(String query) {
    if (query.isEmpty) return getAllThemes();

    final lowercaseQuery = query.toLowerCase();
    return getAllThemes().where((theme) {
      return theme.name.toLowerCase().contains(lowercaseQuery) ||
          theme.displayName.toLowerCase().contains(lowercaseQuery) ||
          theme.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// 獲取推薦主題
  List<ThemeScheme> getRecommendedThemes() {
    final allThemes = getAllThemes();
    final recommended = <ThemeScheme>[];

    // 添加主要風格
    final mainStyle = allThemes.firstWhere(
      (theme) => theme.name == 'main_style',
      orElse: () => allThemes.first,
    );
    recommended.add(mainStyle);

    // 添加每個分類的第一個主題
    final categories = allThemes.map((t) => t.category).toSet();
    for (final category in categories) {
      final categoryThemes = getThemesByCategory(category);
      if (categoryThemes.isNotEmpty) {
        final firstTheme = categoryThemes.first;
        if (firstTheme.name != mainStyle.name) {
          recommended.add(firstTheme);
        }
      }
    }

    return recommended;
  }

  /// 獲取相似主題
  List<ThemeScheme> getSimilarThemes(ThemeScheme baseTheme, {int limit = 5}) {
    final allThemes = getAllThemes();
    final similar = <ThemeScheme>[];

    for (final theme in allThemes) {
      if (theme.name == baseTheme.name) continue;

      // 計算相似度（基於顏色相似性）
      final similarity = _calculateColorSimilarity(baseTheme, theme);
      if (similarity > 0.3) {
        // 相似度閾值
        similar.add(theme);
      }
    }

    // 按相似度排序
    similar.sort((a, b) {
      final similarityA = _calculateColorSimilarity(baseTheme, a);
      final similarityB = _calculateColorSimilarity(baseTheme, b);
      return similarityB.compareTo(similarityA);
    });

    return similar.take(limit).toList();
  }

  /// 計算顏色相似度
  double _calculateColorSimilarity(ThemeScheme theme1, ThemeScheme theme2) {
    double totalSimilarity = 0.0;
    int colorCount = 0;

    // 比較主要顏色
    totalSimilarity += _colorDistance(theme1.primary, theme2.primary);
    totalSimilarity += _colorDistance(theme1.secondary, theme2.secondary);
    totalSimilarity += _colorDistance(theme1.accent, theme2.accent);
    totalSimilarity += _colorDistance(theme1.background, theme2.background);
    totalSimilarity += _colorDistance(theme1.surface, theme2.surface);
    colorCount += 5;

    return totalSimilarity / colorCount;
  }

  /// 計算顏色距離
  double _colorDistance(Color color1, Color color2) {
    final r1 = color1.red.toDouble();
    final g1 = color1.green.toDouble();
    final b1 = color1.blue.toDouble();

    final r2 = color2.red.toDouble();
    final g2 = color2.green.toDouble();
    final b2 = color2.blue.toDouble();

    // 使用歐幾里得距離
    final distance = math.sqrt(
        math.pow(r2 - r1, 2) + math.pow(g2 - g1, 2) + math.pow(b2 - b1, 2));

    // 正規化到 0-1 範圍（255 是最大距離）
    return 1.0 - (distance / 255.0);
  }

  /// 添加主題變更監聽器
  void addThemeChangeListener(Function(ThemeScheme) callback) {
    _themeChangeCallbacks.add(callback);
  }

  /// 移除主題變更監聽器
  void removeThemeChangeListener(Function(ThemeScheme) callback) {
    _themeChangeCallbacks.remove(callback);
  }

  /// 通知主題變更
  void _notifyThemeChange(ThemeScheme theme) {
    for (final callback in _themeChangeCallbacks) {
      try {
        callback(theme);
      } catch (e) {
        debugPrint('主題變更回調執行失敗: $e');
      }
    }
  }

  /// 清除快取
  void clearCache() {
    _categoryCache.clear();
    _statisticsCache = null;
  }

  /// 重新載入主題
  void reloadThemes() {
    clearCache();
    // 觸發主題重新載入
    _notifyThemeChange(currentTheme);
  }
}
