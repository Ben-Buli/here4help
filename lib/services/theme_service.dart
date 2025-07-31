import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/constants/theme_schemes.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';

  ThemeScheme _currentTheme = ThemeScheme.morandiBlue;

  ThemeScheme get currentTheme => _currentTheme;

  ThemeService() {
    _loadTheme();
  }

  /// 載入保存的主題設定
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_themeKey);

      if (themeName != null) {
        _currentTheme = ThemeScheme.getByName(themeName);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('載入主題設定失敗: $e');
    }
  }

  /// 切換主題
  Future<void> setTheme(ThemeScheme theme) async {
    if (_currentTheme.name != theme.name) {
      _currentTheme = theme;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_themeKey, theme.name);
        notifyListeners();
      } catch (e) {
        debugPrint('保存主題設定失敗: $e');
      }
    }
  }

  /// 切換到指定主題名稱
  Future<void> setThemeByName(String themeName) async {
    final theme = ThemeScheme.getByName(themeName);
    await setTheme(theme);
  }

  /// 重置為預設主題
  Future<void> resetToDefault() async {
    await setTheme(ThemeScheme.morandiBlue);
  }

  /// 獲取當前主題的 ThemeData
  ThemeData get themeData => _currentTheme.toThemeData();

  /// 獲取所有可用主題
  List<ThemeScheme> get allThemes => ThemeScheme.allThemes;
}
