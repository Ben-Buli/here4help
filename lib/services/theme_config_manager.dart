import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/constants/theme_schemes.dart';

/// 主題配置管理器 - 提供更優化的主題配置系統
class ThemeConfigManager extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  static const String _themeModeKey = 'theme_mode';
  static const String _themePresetsKey = 'theme_presets';

  ThemeScheme _currentTheme = ThemeScheme.morandiBlue;
  AppThemeMode _themeMode = AppThemeMode.system;
  Map<String, ThemePreset> _themePresets = {};

  ThemeScheme get currentTheme => _currentTheme;
  AppThemeMode get themeMode => _themeMode;
  Map<String, ThemePreset> get themePresets => _themePresets;

  ThemeConfigManager() {
    _loadConfiguration();
  }

  /// 載入所有配置
  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 載入主題設定
      final themeName = prefs.getString(_themeKey);
      if (themeName != null) {
        _currentTheme = ThemeScheme.getByName(themeName);
      }

      // 載入主題模式
      final themeModeIndex =
          prefs.getInt(_themeModeKey) ?? AppThemeMode.system.index;
      _themeMode = AppThemeMode.values[themeModeIndex];

      // 載入主題預設
      _loadThemePresets();

      notifyListeners();
    } catch (e) {
      debugPrint('載入主題配置失敗: $e');
    }
  }

  /// 載入主題預設
  Future<void> _loadThemePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetsJson = prefs.getString(_themePresetsKey);

      if (presetsJson != null) {
        // 這裡可以解析保存的預設配置
        _initializeDefaultPresets();
      } else {
        _initializeDefaultPresets();
      }
    } catch (e) {
      debugPrint('載入主題預設失敗: $e');
      _initializeDefaultPresets();
    }
  }

  /// 初始化預設主題配置
  void _initializeDefaultPresets() {
    _themePresets = {
      'morandi_collection': const ThemePreset(
        name: 'morandi_collection',
        displayName: '莫蘭迪色系合集',
        description: '優雅的莫蘭迪色系主題集合',
        themes: [
          ThemeScheme.morandiBlue,
          ThemeScheme.morandiGreen,
          ThemeScheme.morandiPurple,
          ThemeScheme.morandiPink,
          ThemeScheme.morandiOrange,
        ],
        icon: Icons.palette,
      ),
      'ocean_collection': const ThemePreset(
        name: 'ocean_collection',
        displayName: '海洋風格合集',
        description: '清新的海洋風格主題集合',
        themes: [
          ThemeScheme.oceanGradient,
          ThemeScheme.sandyFootprints,
          ThemeScheme.beachSunset,
        ],
        icon: Icons.beach_access,
      ),
      'business_collection': const ThemePreset(
        name: 'business_collection',
        displayName: '商業風格合集',
        description: '專業的商業風格主題集合',
        themes: [
          ThemeScheme.metaBusinessStyle,
          ThemeScheme.minimalistStill,
          ThemeScheme.milkTeaEarth,
        ],
        icon: Icons.business,
      ),
      'glassmorphism_collection': const ThemePreset(
        name: 'glassmorphism_collection',
        displayName: '毛玻璃風格合集',
        description: '現代毛玻璃效果主題集合',
        themes: [
          ThemeScheme.glassmorphismBlur,
          ThemeScheme.mainStyle,
        ],
        icon: Icons.blur_on,
      ),
    };
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

  /// 設定主題模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_themeModeKey, mode.index);
        notifyListeners();
      } catch (e) {
        debugPrint('保存主題模式設定失敗: $e');
      }
    }
  }

  /// 獲取所有可用主題（包括自定義主題）
  List<ThemeScheme> get allThemes {
    final List<ThemeScheme> allThemes = [...ThemeScheme.allThemes];
    return allThemes;
  }

  /// 獲取按類型分組的主題
  Map<String, List<ThemeScheme>> get groupedThemes {
    final Map<String, List<ThemeScheme>> groups = {};

    for (final theme in ThemeScheme.allThemes) {
      String groupName = _getThemeGroup(theme);
      groups.putIfAbsent(groupName, () => []).add(theme);
    }

    return groups;
  }

  /// 獲取包含 Dark Mode 的所有主題
  List<ThemeScheme> get allThemesWithDarkMode {
    final List<ThemeScheme> allThemes = [...ThemeScheme.allThemes];

    // 為每個主題生成 Dark Mode 版本
    for (final theme in ThemeScheme.allThemes) {
      allThemes.add(theme.toDarkMode());
    }

    return allThemes;
  }

  /// 獲取包含 Dark Mode 的按類型分組主題
  Map<String, List<ThemeScheme>> get groupedThemesWithDarkMode {
    final Map<String, List<ThemeScheme>> groups = {};

    for (final theme in allThemesWithDarkMode) {
      String groupName = _getThemeGroup(theme);
      groups.putIfAbsent(groupName, () => []).add(theme);
    }

    return groups;
  }

  /// 獲取指定主題類型的顏色選項
  List<ThemeScheme> getColorOptionsForTheme(ThemeScheme baseTheme) {
    String groupName = _getThemeGroup(baseTheme);
    return groupedThemes[groupName] ?? [baseTheme];
  }

  /// 根據主題名稱判斷所屬類型
  String _getThemeGroup(ThemeScheme theme) {
    // 移除 _dark 後綴來判斷原始主題類型
    String baseName = theme.name.replaceAll('_dark', '');

    if (baseName.startsWith('morandi_')) {
      return 'Morandi';
    } else if (baseName.contains('ocean') ||
        baseName.contains('beach') ||
        baseName.contains('sandy')) {
      return 'Ocean';
    } else if (baseName.contains('business') ||
        baseName.contains('meta') ||
        baseName.contains('minimalist') ||
        baseName.contains('milk_tea')) {
      return 'Business';
    } else if (baseName.contains('glassmorphism') ||
        baseName.contains('main_style')) {
      return 'Glassmorphism';
    } else {
      return 'Other';
    }
  }

  /// 獲取主題模式選項
  List<AppThemeMode> get themeModes => AppThemeMode.values;

  /// 重置為預設主題
  Future<void> resetToDefault() async {
    await setTheme(ThemeScheme.morandiBlue);
    await setThemeMode(AppThemeMode.system);
  }

  /// 獲取當前主題的 ThemeData
  ThemeData get themeData {
    return effectiveTheme.toThemeData();
  }

  /// 獲取實際生效的主題（考慮 Theme Mode 設置）
  ThemeScheme get effectiveTheme {
    // 如果當前主題已經是 Dark Mode，直接返回
    if (_currentTheme.name.endsWith('_dark')) {
      return _currentTheme;
    }

    // 根據 Theme Mode 決定是否使用 Dark Mode
    switch (_themeMode) {
      case AppThemeMode.light:
        // Light Mode：確保使用 Light 主題
        if (_currentTheme.name.endsWith('_dark')) {
          // 如果當前是 Dark 主題，找到對應的 Light 主題
          String lightThemeName = _currentTheme.name.replaceAll('_dark', '');
          return ThemeScheme.getByName(lightThemeName);
        }
        return _currentTheme;

      case AppThemeMode.dark:
        // Dark Mode：使用 Dark 主題
        if (!_currentTheme.name.endsWith('_dark')) {
          // 如果當前是 Light 主題，生成對應的 Dark 主題
          return _currentTheme.toDarkMode();
        }
        return _currentTheme;

      case AppThemeMode.system:
        // System Mode：根據系統設置決定
        final Brightness brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        if (brightness == Brightness.dark) {
          // 系統是 Dark Mode
          if (!_currentTheme.name.endsWith('_dark')) {
            return _currentTheme.toDarkMode();
          }
        } else {
          // 系統是 Light Mode
          if (_currentTheme.name.endsWith('_dark')) {
            String lightThemeName = _currentTheme.name.replaceAll('_dark', '');
            return ThemeScheme.getByName(lightThemeName);
          }
        }
        return _currentTheme;
    }
  }

  /// 驗證主題配置
  bool validateTheme(ThemeScheme theme) {
    // 檢查必要屬性
    if (theme.name.isEmpty || theme.displayName.isEmpty) {
      return false;
    }

    // 檢查顏色對比度
    if (!_checkColorContrast(theme.primary, theme.onPrimary)) {
      return false;
    }

    if (!_checkColorContrast(theme.secondary, theme.onSecondary)) {
      return false;
    }

    if (!_checkColorContrast(theme.background, theme.onBackground)) {
      return false;
    }

    if (!_checkColorContrast(theme.surface, theme.onSurface)) {
      return false;
    }

    return true;
  }

  /// 檢查顏色對比度
  bool _checkColorContrast(Color background, Color foreground) {
    // 簡化的對比度檢查
    final double luminance1 = background.computeLuminance();
    final double luminance2 = foreground.computeLuminance();
    final double contrast = (luminance1 + 0.05) / (luminance2 + 0.05);
    return contrast >= 3.0 || contrast <= 1 / 3.0; // WCAG AA 標準
  }

  /// 獲取主題建議
  List<ThemeScheme> getThemeSuggestions() {
    final currentStyle = _getThemeStyle(effectiveTheme);
    return ThemeScheme.allThemes
        .where((theme) => _getThemeStyle(theme) == currentStyle)
        .toList();
  }

  /// 獲取主題風格
  String _getThemeStyle(ThemeScheme theme) {
    if (theme.name.startsWith('morandi_')) {
      return 'morandi';
    } else if (theme.name.contains('ocean') || theme.name.contains('beach')) {
      return 'ocean';
    } else if (theme.name.contains('glassmorphism') ||
        theme.name.contains('blur')) {
      return 'glassmorphism';
    } else if (theme.name.contains('business') || theme.name.contains('meta')) {
      return 'business';
    } else {
      return 'default';
    }
  }

  /// 獲取主題統計資訊
  Map<String, dynamic> getThemeStatistics() {
    return {
      'total_themes': allThemes.length,
      'built_in_themes': ThemeScheme.allThemes.length,
      'current_theme': _currentTheme.name,
      'theme_mode': _themeMode.name,
      'presets_count': _themePresets.length,
    };
  }

  /// 獲取當前主題風格類型
  String get themeStyle {
    return _getThemeStyle(effectiveTheme);
  }

  /// 獲取 AppBar 文字顏色
  Color get appBarTextColor {
    final theme = effectiveTheme;
    final style = _getThemeStyle(theme);
    switch (style) {
      case 'ocean':
        return Colors.white; // 海洋主題保持白色
      case 'morandi':
        return Colors.white; // 莫蘭迪主題使用白色文字
      case 'glassmorphism':
        return theme.primary; // Glassmorphism 主題使用主要色
      case 'business':
        // Meta 主題使用深色文字
        if (theme.name == 'meta_business_style' ||
            theme.name == 'meta_business_style_dark') {
          return const Color(0xFF1C1E21); // 深灰文字
        }
        // 彩虹主題使用深色文字
        if (theme.name == 'business_gradient' ||
            theme.name == 'business_gradient_dark') {
          return const Color(0xFF1F2937); // 深灰文字
        }
        // 奶茶主題使用深色文字
        if (theme.name == 'milk_tea_earth' ||
            theme.name == 'milk_tea_earth_dark') {
          return const Color(0xFF2D3748); // 深灰文字
        }
        // 簡約主題使用深色文字
        if (theme.name == 'minimalist_still' ||
            theme.name == 'minimalist_still_dark') {
          return const Color(0xFF2D3748); // 深灰文字
        }
        // 其他商業主題使用主題主要色
        return theme.primary;
      default:
        // Sandy 主題使用白色文字
        if (theme.name == 'sandy_footprints' ||
            theme.name == 'sandy_footprints_dark') {
          return Colors.white;
        }
        return theme.primary; // 標準主題使用主要色
    }
  }

  /// 獲取 AppBar 背景漸層
  List<Color> get appBarGradient {
    final theme = effectiveTheme;
    final style = _getThemeStyle(effectiveTheme);
    switch (style) {
      case 'ocean':
        return [
          const Color(0xFF3B82F6).withOpacity(0.9), // 海藍色
          const Color(0xFF60A5FA).withOpacity(0.8), // 中藍色
        ];
      case 'morandi':
        return [
          theme.primary, // 莫蘭迪主題使用主要色
          theme.primary.withOpacity(0.8), // 稍微透明的版本
        ];
      case 'glassmorphism':
        return [
          Colors.white, // 純白色背景
          Colors.white, // 純白色背景
        ];
      case 'business':
        // Meta 主題使用白色半透明模糊毛玻璃背景
        if (theme.name == 'meta_business_style' ||
            theme.name == 'meta_business_style_dark') {
          return [
            Colors.white.withOpacity(0.3), // 白色半透明
            Colors.white.withOpacity(0.2), // 更透明的白色
          ];
        }
        // 彩虹主題使用白色半透明模糊毛玻璃背景
        if (theme.name == 'business_gradient' ||
            theme.name == 'business_gradient_dark') {
          return [
            Colors.white.withOpacity(0.3), // 白色半透明
            Colors.white.withOpacity(0.2), // 更透明的白色
          ];
        }
        // 其他商業主題使用白色半透明模糊毛玻璃風格
        return [
          Colors.white.withOpacity(0.3), // 白色半透明
          Colors.white.withOpacity(0.2), // 更透明的白色
        ];
      default:
        // Beach 主題使用碧綠色背景
        if (theme.name == 'beach_sunset' || theme.name == 'beach_sunset_dark') {
          return [
            const Color(0xFF00BCD4).withOpacity(0.9), // 碧綠色
            const Color(0xFF26C6DA).withOpacity(0.8), // 淺碧綠色
          ];
        }
        return [
          theme.primary.withOpacity(0.8),
          theme.secondary.withOpacity(0.6),
        ];
    }
  }

  /// 獲取毛玻璃效果的表面色
  Color get glassmorphismSurface {
    final theme = effectiveTheme;
    final style = _getThemeStyle(effectiveTheme);
    switch (style) {
      case 'morandi':
        return theme.surface;
      case 'ocean':
      case 'glassmorphism':
        return Colors.white; // Glassmorphism 主題使用純白色，不透明
      case 'business':
        return Colors.white; // Business 主題使用純白色，不透明
      default:
        return Colors.white.withOpacity(0.2); // 半透明白色
    }
  }

  /// 獲取導航欄背景色
  Color get navigationBarBackground {
    final theme = effectiveTheme;
    final style = _getThemeStyle(effectiveTheme);
    switch (style) {
      case 'ocean':
        return const Color(0xFF3B82F6).withOpacity(0.9); // 海藍色半透明
      case 'morandi':
        return theme.primary.withOpacity(0.9); // 莫蘭迪主題使用主要色半透明
      case 'glassmorphism':
        return Colors.white; // Glassmorphism 主題使用純白色，不透明
      case 'business':
        return Colors.white.withOpacity(0.3); // Business 主題使用半透明白色
      default:
        // Beach 主題使用碧綠色半透明背景
        if (theme.name == 'beach_sunset' || theme.name == 'beach_sunset_dark') {
          return const Color(0xFF00BCD4).withOpacity(0.3); // 碧綠色半透明
        }
        return Colors.white.withOpacity(0.2); // 標準主題使用半透明白色
    }
  }

  /// 獲取導航欄選中項目顏色
  Color get navigationBarSelectedColor {
    final theme = effectiveTheme;
    final style = _getThemeStyle(effectiveTheme);
    switch (style) {
      case 'ocean':
        return const Color.fromARGB(255, 229, 194, 163); // 沙灘色
      case 'morandi':
        return Colors.white; // 莫蘭迪主題使用白色（在深色背景上）
      case 'glassmorphism':
      case 'business':
      default:
        return theme.primary; // 使用主題主要色
    }
  }

  /// 獲取導航欄未選中項目顏色
  Color get navigationBarUnselectedColor {
    final theme = effectiveTheme;
    final style = _getThemeStyle(effectiveTheme);
    switch (style) {
      case 'ocean':
        return Colors.white.withOpacity(0.7); // 半透明白色
      case 'morandi':
        return Colors.white.withOpacity(0.6); // 莫蘭迪主題使用半透明白色（在深色背景上）
      case 'glassmorphism':
      case 'business':
      default:
        return theme.onSurface.withOpacity(0.7); // 半透明深色
    }
  }

  /// 獲取輸入框文字顏色 - 確保在 Dark Mode 下使用亮色文字
  Color get inputTextColor {
    final theme = effectiveTheme;
    // 在 Dark Mode 下使用亮色文字，在 Light Mode 下使用暗色文字
    if (_isDarkMode(theme)) {
      return Colors.white; // Dark Mode 使用白色文字
    } else {
      return theme.onSurface; // Light Mode 使用主題文字顏色
    }
  }

  /// 獲取輸入框提示文字顏色 - 確保在 Dark Mode 下使用亮色文字
  Color get inputHintTextColor {
    final theme = effectiveTheme;
    // 在 Dark Mode 下使用亮色提示文字，在 Light Mode 下使用暗色提示文字
    if (_isDarkMode(theme)) {
      return Colors.white.withOpacity(0.7); // Dark Mode 使用半透明白色
    } else {
      return theme.onSurface.withOpacity(0.7); // Light Mode 使用半透明主題文字顏色
    }
  }

  /// 檢查是否為 Dark Mode 主題
  bool _isDarkMode(ThemeScheme theme) {
    return theme.name.contains('_dark') ||
        theme.name.contains('dark') ||
        (themeMode == AppThemeMode.dark) ||
        (themeMode == AppThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
  }
}

/// 主題預設類別
class ThemePreset {
  final String name;
  final String displayName;
  final String description;
  final List<ThemeScheme> themes;
  final IconData icon;

  const ThemePreset({
    required this.name,
    required this.displayName,
    required this.description,
    required this.themes,
    required this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'description': description,
      'themes': themes.map((t) => t.name).toList(),
      'icon': icon.codePoint,
    };
  }

  factory ThemePreset.fromJson(Map<String, dynamic> json) {
    return ThemePreset(
      name: json['name'],
      displayName: json['displayName'],
      description: json['description'],
      themes: (json['themes'] as List)
          .map((name) => ThemeScheme.getByName(name))
          .toList(),
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    );
  }
}

/// 主題模式枚舉
enum AppThemeMode {
  light,
  dark,
  system,
}
