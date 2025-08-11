import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/constants/theme_schemes.dart';

/// 主題配置管理器 - 提供更優化的主題配置系統
///
/// 這個類負責管理應用程序的主題配置，包括：
/// - 主題切換和持久化
/// - 主題模式管理（淺色/深色/系統）
/// - 主題預設管理
/// - 主題驗證和建議
///
/// 使用示例：
/// ```dart
/// final themeManager = ThemeConfigManager();
/// await themeManager.setTheme(ThemeScheme.morandiBlue);
/// await themeManager.setThemeMode(AppThemeMode.system);
/// ```
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
  ///
  /// 從 SharedPreferences 中載入保存的主題配置，包括：
  /// - 主題設定：載入上次選擇的主題
  /// - 主題模式：載入主題模式設置（淺色/深色/系統）
  /// - 主題預設：載入主題預設配置
  ///
  /// 如果載入失敗，會使用默認配置並記錄錯誤信息。
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
  ///
  /// 從 SharedPreferences 中載入保存的主題預設配置。
  /// 目前總是初始化默認預設配置，未來可以根據保存的 JSON 來恢復自定義配置。
  ///
  /// 如果載入失敗，會使用默認預設配置並記錄錯誤信息。
  Future<void> _loadThemePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetsJson = prefs.getString(_themePresetsKey);

      // 目前總是初始化預設配置，未來可以根據保存的 JSON 來恢復自定義配置
      if (presetsJson != null) {
        // TODO: 解析保存的預設配置
        debugPrint('發現保存的主題預設配置，但尚未實現解析功能');
      }

      _initializeDefaultPresets();
    } catch (e) {
      debugPrint('載入主題預設失敗: $e');
      _initializeDefaultPresets();
    }
  }

  /// 初始化預設主題配置
  ///
  /// 創建預設的主題集合，包括：
  /// - 莫蘭迪色系合集：包含5個莫蘭迪風格主題
  /// - 海洋風格合集：包含3個海洋風格主題
  /// - 商業風格合集：包含3個商業風格主題
  /// - 毛玻璃風格合集：包含2個毛玻璃風格主題
  ///
  /// 這些預設配置用於組織和管理相關的主題。
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
  ///
  /// 切換到指定的主題，並將設置保存到 SharedPreferences。
  /// 只有在主題名稱不同時才會進行切換和保存操作。
  ///
  /// 參數：
  /// - [theme]: 要切換到的主題
  ///
  /// 使用示例：
  /// ```dart
  /// await themeManager.setTheme(ThemeScheme.morandiBlue);
  /// ```
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
  ///
  /// 根據主題名稱切換到對應的主題。
  /// 如果主題名稱不存在，會使用默認主題。
  ///
  /// 參數：
  /// - [themeName]: 要切換到的主題名稱
  ///
  /// 使用示例：
  /// ```dart
  /// await themeManager.setThemeByName('morandi_blue');
  /// ```
  Future<void> setThemeByName(String themeName) async {
    final theme = ThemeScheme.getByName(themeName);
    await setTheme(theme);
  }

  /// 設定主題模式
  ///
  /// 設定主題模式（淺色/深色/系統），並將設置保存到 SharedPreferences。
  /// 只有在模式不同時才會進行切換和保存操作。
  ///
  /// 參數：
  /// - [mode]: 要設定的主題模式
  ///
  /// 使用示例：
  /// ```dart
  /// await themeManager.setThemeMode(AppThemeMode.system);
  /// ```
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
  ///
  /// 返回所有可用的主題列表，包括內建主題和自定義主題。
  /// 目前只返回內建主題，未來可以擴展支持自定義主題。
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
  ///
  /// 根據主題名稱將主題分類到不同的組別：
  /// - `Morandi`: 莫蘭迪風格主題組
  /// - `Ocean`: 海洋風格主題組
  /// - `Business`: 商業風格主題組
  /// - `Glassmorphism`: 毛玻璃風格主題組
  /// - `Other`: 其他主題組
  ///
  /// 參數：
  /// - [theme]: 要分類的主題
  ///
  /// 返回主題組名稱。
  String _getThemeGroup(ThemeScheme theme) {
    // 移除 _dark 後綴來判斷原始主題類型
    String baseName = theme.name.replaceAll('_dark', '');

    if (baseName.startsWith('morandi_')) {
      return 'Morandi';
    } else if (baseName.contains('ocean') ||
        baseName.contains('beach') ||
        baseName.contains('sandy')) {
      return 'Ocean';
    } else if (baseName.contains('milk_tea') ||
        baseName.contains('minimalist') ||
        baseName == 'taipei_2019_pantone' ||
        baseName == 'taipei_101') {
      // 將 Milk Tea 與 Minimalist 歸類到 Taiwan 分類
      return 'Taiwan';
    } else if (baseName.contains('business') ||
        baseName.contains('meta') ||
        baseName.contains('glassmorphism') ||
        baseName.contains('main_style')) {
      // 將 Glass、Blue Grey、Main 也併入 Business 分類
      return 'Business';
    } else if (baseName.contains('rainbow_pride') ||
        baseName.contains('trans') ||
        baseName.contains('lesbian_theme') ||
        baseName.contains('non_binary_theme') ||
        baseName.contains('bear_gay_flat') ||
        baseName.contains('pride_s_curve')) {
      return 'LGBTQ+';
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
  ///
  /// 這個方法會根據當前的主題模式設置返回實際生效的主題：
  /// - [AppThemeMode.light]: 返回淺色主題
  /// - [AppThemeMode.dark]: 返回深色主題
  /// - [AppThemeMode.system]: 根據系統設置返回對應主題
  ///
  /// 如果當前主題已經是目標模式，則直接返回；否則會自動生成對應模式的主題。
  ThemeScheme get effectiveTheme {
    // 根據 Theme Mode 決定是否使用 Dark Mode
    switch (_themeMode) {
      case AppThemeMode.light:
        // Light Mode：確保使用 Light 主題
        return _getLightTheme();
      case AppThemeMode.dark:
        // Dark Mode：使用 Dark 主題
        return _getDarkTheme();
      case AppThemeMode.system:
        // System Mode：根據系統設置決定
        final Brightness brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark
            ? _getDarkTheme()
            : _getLightTheme();
    }
  }

  /// 獲取 Light 主題
  ///
  /// 如果當前主題是 Dark 主題，則返回對應的 Light 主題；
  /// 否則直接返回當前主題。
  ///
  /// 返回 Light 主題。
  ThemeScheme _getLightTheme() {
    if (_currentTheme.name.endsWith('_dark')) {
      // 如果當前是 Dark 主題，找到對應的 Light 主題
      String lightThemeName = _currentTheme.name.replaceAll('_dark', '');
      return ThemeScheme.getByName(lightThemeName);
    }
    return _currentTheme;
  }

  /// 獲取 Dark 主題
  ///
  /// 如果當前主題是 Light 主題，則生成對應的 Dark 主題；
  /// 否則直接返回當前主題。
  ///
  /// 返回 Dark 主題。
  ThemeScheme _getDarkTheme() {
    if (!_currentTheme.name.endsWith('_dark')) {
      // 如果當前是 Light 主題，生成對應的 Dark 主題
      return _currentTheme.toDarkMode();
    }
    return _currentTheme;
  }

  /// 驗證主題配置
  ///
  /// 檢查主題配置是否有效，包括：
  /// - 必要屬性檢查（名稱、顯示名稱）
  /// - 顏色對比度檢查（符合 WCAG AA 標準）
  ///
  /// 返回 `true` 表示主題配置有效，`false` 表示無效。
  ///
  /// 使用示例：
  /// ```dart
  /// if (themeManager.validateTheme(theme)) {
  ///   await themeManager.setTheme(theme);
  /// } else {
  ///   print('主題配置無效');
  /// }
  /// ```
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
  ///
  /// 根據 WCAG 2.1 標準檢查背景色和前景色的對比度。
  /// 使用相對亮度計算對比度比率，確保符合可訪問性標準。
  ///
  /// 參數：
  /// - [background]: 背景顏色
  /// - [foreground]: 前景顏色（通常是文字顏色）
  ///
  /// 返回 `true` 表示對比度符合標準（≥3.0），`false` 表示不符合。
  ///
  /// 參考：https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
  bool _checkColorContrast(Color background, Color foreground) {
    // 計算相對亮度
    final double luminance1 = background.computeLuminance();
    final double luminance2 = foreground.computeLuminance();

    // 確保較亮的顏色在分子位置
    final double lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final double darker = luminance1 > luminance2 ? luminance2 : luminance1;

    // 計算對比度比率 (WCAG 2.1 標準)
    final double contrast = (lighter + 0.05) / (darker + 0.05);

    // WCAG AA 標準：正常文字需要 4.5:1，大文字需要 3:1
    return contrast >= 3.0;
  }

  /// 獲取主題建議
  List<ThemeScheme> getThemeSuggestions() {
    final currentStyle = _getThemeStyle(effectiveTheme);
    return ThemeScheme.allThemes
        .where((theme) => _getThemeStyle(theme) == currentStyle)
        .toList();
  }

  /// 獲取主題風格
  ///
  /// 根據主題名稱判斷主題所屬的風格類型：
  /// - `morandi`: 莫蘭迪風格主題
  /// - `ocean`: 海洋風格主題
  /// - `glassmorphism`: 毛玻璃風格主題
  /// - `business`: 商業風格主題
  /// - `default`: 默認風格主題
  ///
  /// 參數：
  /// - [theme]: 要檢查的主題
  ///
  /// 返回主題風格字符串。
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
  ///
  /// 根據當前主題風格返回適合的 AppBar 文字顏色：
  /// - 海洋主題：白色文字
  /// - 莫蘭迪主題：白色文字
  /// - Glassmorphism 主題：主題主要色
  /// - 商業主題：根據具體主題返回深色或主要色文字
  /// - 其他主題：主題主要色
  ///
  /// 這個方法確保 AppBar 文字在不同主題下都有良好的可讀性。
  Color get appBarTextColor {
    final theme = effectiveTheme;
    if (theme.appBarTitleColor != null) return theme.appBarTitleColor!;
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

  /// AppBar 次標題顏色（若未定義則以標題色 80% 不透明度推導）
  Color get appBarSubtitleColor {
    final theme = effectiveTheme;
    if (theme.appBarSubtitleColor != null) return theme.appBarSubtitleColor!;
    return appBarTextColor.withOpacity(0.8);
  }

  /// 獲取 AppBar 背景漸層
  ///
  /// 根據當前主題風格返回適合的 AppBar 背景漸層：
  /// - 海洋主題：海藍色漸層
  /// - 莫蘭迪主題：主題主要色漸層
  /// - Glassmorphism 主題：純白色背景
  /// - 商業主題：白色半透明毛玻璃效果
  /// - 其他主題：主題主要色和次要色漸層
  ///
  /// 返回的漸層顏色列表可以直接用於 LinearGradient 的 colors 屬性。
  List<Color> get appBarGradient {
    final theme = effectiveTheme;
    final style = _getThemeStyle(effectiveTheme);
    switch (style) {
      case 'ocean':
        return [
          const Color(0xFF3B82F6).withValues(alpha: 0.9), // 海藍色
          const Color(0xFF60A5FA).withValues(alpha: 0.8), // 中藍色
        ];
      case 'morandi':
        return [
          theme.primary, // 莫蘭迪主題使用主要色
          theme.primary.withValues(alpha: 0.8), // 稍微透明的版本
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
            Colors.white.withValues(alpha: 1), // 白色半透明
            Colors.white.withValues(alpha: 0.2), // 更透明的白色
          ];
        }
        // 彩虹主題使用白色半透明模糊毛玻璃背景
        if (theme.name == 'business_gradient' ||
            theme.name == 'business_gradient_dark') {
          return [
            Colors.white.withValues(alpha: 0.3), // 白色半透明
            Colors.white.withValues(alpha: 0.2), // 更透明的白色
          ];
        }
        // 其他商業主題使用白色半透明模糊毛玻璃風格
        return [
          Colors.white.withValues(alpha: 1), // 白色半透明
          Colors.white.withValues(alpha: 0.2), // 更透明的白色
        ];
      default:
        // Beach 主題使用碧綠色背景
        if (theme.name == 'beach_sunset' || theme.name == 'beach_sunset_dark') {
          return [
            const Color(0xFF00BCD4).withValues(alpha: 0.9), // 碧綠色
            const Color(0xFF26C6DA).withValues(alpha: 0.8), // 淺碧綠色
          ];
        }
        // LGBTQ+ 分類：AppBar 與 BottomNav 一致（交由 AppScaffold 用 navigationBarBackground 顏色渲染）
        // 這裡回傳空陣列代表不使用漸層
        if (theme.name.contains('rainbow_pride') ||
            theme.name.contains('trans') ||
            theme.name.contains('lesbian_theme') ||
            theme.name.contains('non_binary_theme') ||
            theme.name.contains('bear_gay_flat')) {
          return [];
        }
        return [
          theme.primary.withValues(alpha: 0.8),
          theme.secondary.withValues(alpha: 0.6),
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
        return Colors.white.withValues(alpha: 0.2); // 半透明白色
    }
  }

  /// 獲取導航欄背景色
  Color get navigationBarBackground {
    final theme = effectiveTheme;
    final style = _getThemeStyle(effectiveTheme);
    switch (style) {
      case 'ocean':
        return const Color(0xFF3B82F6).withValues(alpha: 0.9); // 海藍色半透明
      case 'morandi':
        return theme.primary.withValues(alpha: 0.9); // 莫蘭迪主題使用主要色半透明
      case 'glassmorphism':
        return Colors.white; // Glassmorphism 主題使用純白色，不透明
      case 'business':
        return Colors.white.withValues(alpha: 0.3); // Business 主題使用半透明白色
      default:
        // LGBTQ+ 類主題：白色液態玻璃
        if (theme.name.contains('rainbow_pride') ||
            theme.name.contains('trans') ||
            theme.name.contains('lesbian_theme') ||
            theme.name.contains('non_binary_theme') ||
            theme.name.contains('bear_gay_flat')) {
          return Colors.white.withValues(alpha: 0.3);
        }
        // Beach 主題使用碧綠色半透明背景
        if (theme.name == 'beach_sunset' || theme.name == 'beach_sunset_dark') {
          return const Color(0xFF00BCD4).withValues(alpha: 0.3); // 碧綠色半透明
        }
        return Colors.white.withValues(alpha: 0.2); // 標準主題使用半透明白色
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
        return Colors.white.withValues(alpha: 0.7); // 半透明白色
      case 'morandi':
        return Colors.white.withValues(alpha: 0.6); // 莫蘭迪主題使用半透明白色（在深色背景上）
      case 'glassmorphism':
      case 'business':
      default:
        return theme.onSurface.withValues(alpha: 0.7); // 半透明深色
    }
  }

  /// 獲取輸入框文字顏色 - 確保在 Dark Mode 下使用亮色文字
  ///
  /// 根據當前主題模式返回適合的輸入框文字顏色：
  /// - Dark Mode：白色文字
  /// - Light Mode：主題文字顏色
  ///
  /// 這個方法確保輸入框文字在不同主題模式下都有良好的可讀性。
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
  ///
  /// 根據當前主題模式返回適合的輸入框提示文字顏色：
  /// - Dark Mode：半透明白色文字
  /// - Light Mode：半透明主題文字顏色
  ///
  /// 這個方法確保輸入框提示文字在不同主題模式下都有良好的可讀性。
  Color get inputHintTextColor {
    final theme = effectiveTheme;
    // 在 Dark Mode 下使用亮色提示文字，在 Light Mode 下使用暗色提示文字
    if (_isDarkMode(theme)) {
      return Colors.white.withValues(alpha: 0.7); // Dark Mode 使用半透明白色
    } else {
      return theme.onSurface.withValues(alpha: 0.7); // Light Mode 使用半透明主題文字顏色
    }
  }

  /// 檢查是否為 Dark Mode 主題
  ///
  /// 根據主題名稱和當前主題模式設置判斷是否為 Dark Mode：
  /// - 如果主題名稱以 '_dark' 結尾，返回 true
  /// - 如果主題模式設置為 dark，返回 true
  /// - 如果主題模式設置為 system 且系統為深色模式，返回 true
  /// - 其他情況返回 false
  ///
  /// 參數：
  /// - [theme]: 要檢查的主題
  ///
  /// 返回 `true` 表示為 Dark Mode，`false` 表示為 Light Mode。
  bool _isDarkMode(ThemeScheme theme) {
    // 檢查主題名稱是否包含 dark 後綴
    if (theme.name.endsWith('_dark')) {
      return true;
    }

    // 檢查主題模式設置
    switch (_themeMode) {
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.light:
        return false;
      case AppThemeMode.system:
        // 根據系統設置決定
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  /// 檢查當前主題是否為指定主題
  bool isCurrentTheme(ThemeScheme theme) {
    return _currentTheme.name == theme.name;
  }

  /// 檢查當前主題是否為指定主題名稱
  bool isCurrentThemeByName(String themeName) {
    return _currentTheme.name == themeName;
  }

  /// 獲取當前主題的詳細信息
  ///
  /// 返回包含當前主題詳細信息的 Map，包括：
  /// - `name`: 主題名稱
  /// - `displayName`: 主題顯示名稱
  /// - `isDarkMode`: 是否為深色模式
  /// - `themeMode`: 主題模式顯示名稱
  /// - `style`: 主題風格類型
  ///
  /// 使用示例：
  /// ```dart
  /// final info = themeManager.getCurrentThemeInfo();
  /// print('當前主題：${info['displayName']}');
  /// print('是否深色模式：${info['isDarkMode']}');
  /// ```
  Map<String, dynamic> getCurrentThemeInfo() {
    final theme = effectiveTheme;
    return {
      'name': theme.name,
      'displayName': theme.displayName,
      'isDarkMode': _isDarkMode(theme),
      'themeMode': _themeMode.displayName,
      'style': _getThemeStyle(theme),
    };
  }

  /// 獲取主題切換歷史（簡單實現）
  List<String> getThemeHistory() {
    // TODO: 實現主題切換歷史記錄
    return [_currentTheme.name];
  }

  /// 檢查主題是否為預設主題
  bool isDefaultTheme(ThemeScheme theme) {
    return theme.name == ThemeScheme.morandiBlue.name;
  }

  /// 獲取推薦主題列表
  ///
  /// 根據當前主題風格推薦相似的主題，最多返回3個推薦主題。
  ///
  /// 推薦策略：
  /// 1. 優先推薦與當前主題相同風格的其他主題
  /// 2. 如果推薦不足3個，則添加其他風格的主題
  /// 3. 排除當前正在使用的主題
  ///
  /// 返回的主題列表按推薦優先級排序。
  List<ThemeScheme> getRecommendedThemes() {
    final currentStyle = _getThemeStyle(effectiveTheme);
    final recommendations = <ThemeScheme>[];

    // 根據當前主題風格推薦相似主題
    for (final theme in ThemeScheme.allThemes) {
      if (_getThemeStyle(theme) == currentStyle &&
          theme.name != effectiveTheme.name) {
        recommendations.add(theme);
      }
    }

    // 如果推薦不足，添加其他風格的主題
    if (recommendations.length < 3) {
      for (final theme in ThemeScheme.allThemes) {
        if (!recommendations.contains(theme) &&
            theme.name != effectiveTheme.name) {
          recommendations.add(theme);
          if (recommendations.length >= 3) break;
        }
      }
    }

    return recommendations.take(3).toList();
  }
}

/// 主題預設類別
///
/// 代表一組相關的主題集合，用於組織和管理主題。
/// 每個預設包含多個相關的主題，並提供描述和圖標。
///
/// 使用示例：
/// ```dart
/// final preset = ThemePreset(
///   name: 'morandi_collection',
///   displayName: '莫蘭迪色系合集',
///   description: '優雅的莫蘭迪色系主題集合',
///   themes: [ThemeScheme.morandiBlue, ThemeScheme.morandiGreen],
///   icon: Icons.palette,
/// );
/// ```
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

  /// 獲取主題數量
  int get themeCount => themes.length;

  /// 檢查是否包含指定主題
  bool containsTheme(ThemeScheme theme) {
    return themes.any((t) => t.name == theme.name);
  }

  /// 檢查是否包含指定主題名稱
  bool containsThemeByName(String themeName) {
    return themes.any((t) => t.name == themeName);
  }

  /// 獲取主題名稱列表
  List<String> get themeNames => themes.map((t) => t.name).toList();

  /// 檢查是否為空
  bool get isEmpty => themes.isEmpty;

  /// 檢查是否不為空
  bool get isNotEmpty => themes.isNotEmpty;

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

  @override
  String toString() {
    return 'ThemePreset(name: $name, displayName: $displayName, themeCount: $themeCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemePreset &&
        other.name == name &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => name.hashCode ^ displayName.hashCode;
}

/// 主題模式枚舉
///
/// 定義了應用程序支持的主題模式：
/// - [light]: 淺色模式，始終使用淺色主題
/// - [dark]: 深色模式，始終使用深色主題
/// - [system]: 系統模式，根據系統設置自動切換
///
/// 使用示例：
/// ```dart
/// await themeManager.setThemeMode(AppThemeMode.system);
/// print(AppThemeMode.system.displayName); // 輸出：跟隨系統
/// ```
enum AppThemeMode {
  light,
  dark,
  system;

  /// 獲取顯示名稱
  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return '淺色模式';
      case AppThemeMode.dark:
        return '深色模式';
      case AppThemeMode.system:
        return '跟隨系統';
    }
  }

  /// 獲取英文顯示名稱
  String get displayNameEn {
    switch (this) {
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.system:
        return 'System';
    }
  }

  /// 獲取圖標
  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_system_daydream;
    }
  }
}
