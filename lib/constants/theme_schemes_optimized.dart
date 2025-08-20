import 'package:flutter/material.dart';
import 'dart:ui';

/// 優化後的主題色系配置
///
/// 整合了原有的主題管理功能，精簡了主題數量，
/// 統一了分類系統，提供了更好的維護性
class ThemeScheme {
  final String name;
  final String displayName;
  final String category;
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
  final Color outlineVariant;

  // 特殊效果
  final double? backgroundBlur;
  final double? surfaceBlur;
  final List<Color>? backgroundGradient;
  final AlignmentGeometry? gradientBegin;
  final AlignmentGeometry? gradientEnd;

  // UI 組件顏色
  final Color cardBackground;
  final Color cardBorder;
  final Color inputBackground;
  final Color inputBorder;
  final Color hintText;
  final Color disabledText;
  final Color divider;
  final Color overlay;
  final Color successBackground;
  final Color warningBackground;
  final Color errorBackground;

  // AppBar 顏色
  final Color? appBarTitleColor;
  final Color? appBarSubtitleColor;
  final Color backArrowColor;
  final Color backArrowColorInactive;

  const ThemeScheme({
    required this.name,
    required this.displayName,
    required this.category,
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
    required this.outlineVariant,
    this.backgroundBlur,
    this.surfaceBlur,
    this.backgroundGradient,
    this.gradientBegin,
    this.gradientEnd,
    required this.backArrowColor,
    required this.backArrowColorInactive,
    this.cardBackground = const Color(0xFFFFFFFF),
    this.cardBorder = const Color(0xFFE5E7EB),
    this.inputBackground = const Color(0xFFFFFFFF),
    this.inputBorder = const Color(0xFFD1D5DB),
    this.hintText = const Color(0xFF9CA3AF),
    this.disabledText = const Color(0xFF6B7280),
    this.divider = const Color(0xFFF3F4F6),
    this.overlay = const Color(0x80000000),
    this.successBackground = const Color(0xFFD1FAE5),
    this.warningBackground = const Color(0xFFFEF3C7),
    this.errorBackground = const Color(0xFFFEE2E2),
    this.appBarTitleColor,
    this.appBarSubtitleColor,
  });

  // ==================== 核心主題（精簡版）====================

  /// 主要風格 - 毛玻璃紫色系
  static const ThemeScheme mainStyle = ThemeScheme(
    name: 'main_style',
    displayName: 'Main Style - Glassmorphism Purple',
    category: 'business',
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFF7C3AED),
    accent: Color(0xFFA78BFA),
    background: Color(0xFFF8F7FF),
    surface: Color(0xFFF3F1FF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF2D3748),
    onSurface: Color(0xFF2D3748),
    error: Color(0xFFEF4444),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A8B5CF6),
    outlineVariant: Color(0xFF8B5CF6),
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// Meta 商業風格
  static const ThemeScheme metaBusinessStyle = ThemeScheme(
    name: 'meta_business_style',
    displayName: 'Meta Business Style',
    category: 'business',
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFFA78BFA),
    accent: Color(0xFF7C3AED),
    background: Color(0xFFF8F7FF),
    surface: Color.fromARGB(255, 255, 255, 255),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1C1E21),
    onSurface: Color(0xFF1C1E21),
    error: Color(0xFFFA383E),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF42B883),
    warning: Color(0xFFFF9500),
    shadow: Color(0x1A8B5CF6),
    outlineVariant: Color(0xFF8B5CF6),
    backgroundBlur: 10.0,
    surfaceBlur: 5.0,
    backgroundGradient: [
      Color(0xFFF3F1FF),
      Color(0xFFE9E5FF),
      Color(0xFFF8F7FF),
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Color(0xFF1C1E21),
    backArrowColorInactive: Color(0x4D1C1E21),
  );

  /// 商業漸層風格
  static const ThemeScheme businessGradient = ThemeScheme(
    name: 'business_gradient',
    displayName: 'Rainbow',
    category: 'business',
    primary: Color(0xFF6366F1),
    secondary: Color(0xFF8B5CF6),
    accent: Color(0xFFEC4899),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1F2937),
    onSurface: Color(0xFF1F2937),
    error: Color(0xFFEF4444),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A6366F1),
    outlineVariant: Color(0xFF6366F1),
    backgroundBlur: 8.0,
    surfaceBlur: 4.0,
    backgroundGradient: [
      Color(0xFFFFF1F2),
      Color(0xFFFFF7ED),
      Color(0xFFFFFBF0),
      Color(0xFFF0F9FF),
      Color(0xFFE0F2FE),
      Color(0xFFDBEAFE),
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x4D1F2937),
  );

  /// 莫蘭迪藍色系
  static const ThemeScheme morandiBlue = ThemeScheme(
    name: 'morandi_blue',
    displayName: 'Morandi Blue',
    category: 'morandi',
    primary: Color(0xFF6B7A85),
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
    outlineVariant: Color(0xFF6B7A85),
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 莫蘭迪綠色系
  static const ThemeScheme morandiGreen = ThemeScheme(
    name: 'morandi_green',
    displayName: 'Morandi Green - Matcha',
    category: 'morandi',
    primary: Color(0xFF6A8A6A),
    secondary: Color(0xFF9BB09B),
    accent: Color(0xFFB8C5B8),
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
    outlineVariant: Color(0xFF6A8A6A),
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 莫蘭迪檸檬黃色系
  static const ThemeScheme morandiLemon = ThemeScheme(
    name: 'morandi_lemon',
    displayName: 'Yellow',
    category: 'morandi',
    primary: Color(0xFFB4A864),
    secondary: Color(0xFFD4C8A8),
    accent: Color(0xFFE4DCC5),
    background: Color(0xFFFCFCF8),
    surface: Color(0xFFFCFCF8),
    onPrimary: Color(0xFFFCFCF8),
    onSecondary: Color(0xFF48472D),
    onBackground: Color(0xFF48472D),
    onSurface: Color(0xFF48472D),
    error: Color(0xFFB56576),
    onError: Color(0xFFFCFCF8),
    success: Color(0xFF8FBC8F),
    warning: Color(0xFF7B8A95),
    shadow: Color(0xFF7A7A5A),
    outlineVariant: Color(0xFFB4A864),
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 海灘日落主題
  static const ThemeScheme beachSunset = ThemeScheme(
    name: 'beach_sunset',
    displayName: 'Beach Sunset - Ocean Style',
    category: 'ocean',
    primary: Color(0xFF00BCD4),
    secondary: Color(0xFF26C6DA),
    accent: Color(0xFF4DD0E1),
    background: Color(0xFFE0F7FA),
    surface: Color(0xFFB2EBF2),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF006064),
    onSurface: Color(0xFF006064),
    error: Color(0xFFE53E3E),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF38A169),
    warning: Color(0xFFD69E2E),
    shadow: Color(0x1A00BCD4),
    outlineVariant: Color(0xFF00BCD4),
    backgroundGradient: [
      Color(0xFFFDFCF7),
      Color(0xFFF5F0E8),
      Color(0xFFE8D4C0),
      Color(0xFFD4B8A0),
      Color(0xFFC19B7A),
      Color(0xFFA67B5A),
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 海洋漸層主題
  static const ThemeScheme oceanGradient = ThemeScheme(
    name: 'ocean_gradient',
    displayName: 'Ocean Gradient',
    category: 'ocean',
    primary: Color(0xFF1182A4),
    secondary: Color(0xFF2FA7B4),
    accent: Color(0xFF00618D),
    background: Color(0xFFF0F8FF),
    surface: Color(0xFFE6F3FF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF004065),
    onSurface: Color(0xFF004065),
    error: Color(0xFFE53E3E),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF38A169),
    warning: Color(0xFFD69E2E),
    shadow: Color(0x1A1182A4),
    outlineVariant: Color(0xFF1182A4),
    backgroundGradient: [
      Color(0xFFE6E2D8),
      Color(0xFF7BC8D1),
      Color(0xFF5BA3C2),
      Color(0xFF4A8BA8),
      Color(0xFF3A6B8A),
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 奶茶色主題
  static const ThemeScheme milkTeaEarth = ThemeScheme(
    name: 'milk_tea_earth',
    displayName: 'Bubble Milk Tea',
    category: 'taiwan',
    primary: Color(0xFF8B6B5A),
    secondary: Color(0xFFA67B5A),
    accent: Color(0xFFC19B7A),
    background: Color(0xFFFDFCF7),
    surface: Color(0xFFF8F6F0),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF2D3748),
    onSurface: Color(0xFF2D3748),
    error: Color(0xFFE53E3E),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF38A169),
    warning: Color(0xFFD69E2E),
    shadow: Color(0x1A8B6B5A),
    outlineVariant: Color(0xFF8B6B5A),
    backgroundGradient: [
      Color(0xFFFDFCF7),
      Color(0xFFF5F0E8),
      Color(0xFFE8D4C0),
      Color(0xFFD4B8A0),
      Color(0xFFB89A7A),
      Color(0xFF8B6B5A),
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    appBarTitleColor: Colors.white,
    appBarSubtitleColor: Colors.white,
  );

  /// 台北 101 主題
  static const ThemeScheme taipei101 = ThemeScheme(
    name: 'taipei_101',
    displayName: 'Taipei 101',
    category: 'taiwan',
    primary: Color(0xFF4DA3FF),
    secondary: Color(0xFF40C4FF),
    accent: Color(0xFF82B1FF),
    background: Color(0xFFEFF5FF),
    surface: Color(0xFFF7FAFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF0D1B2A),
    onBackground: Color(0xFF273043),
    onSurface: Color(0xFF273043),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFF9C6F19),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFBFD4F2),
    backArrowColor: Color(0xFF273043),
    backArrowColorInactive: Color(0x80273043),
    appBarTitleColor: Colors.white,
    appBarSubtitleColor: Colors.white,
  );

  /// 彩虹驕傲主題
  static const ThemeScheme rainbowPride = ThemeScheme(
    name: 'rainbow_pride',
    displayName: 'Rainbow Pride',
    category: 'emotions',
    primary: Color(0xFF004DFF),
    secondary: Color(0xFF750787),
    accent: Color(0xFFFFED00),
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1F2937),
    onSurface: Color(0xFF1F2937),
    error: Color(0xFFE40303),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF008026),
    warning: Color(0xFFFF8C00),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFE5E7EB),
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x801F2937),
    backgroundGradient: [
      Color(0xFFE65C5C),
      Color(0xFFF2A64F),
      Color(0xFFF2E86A),
      Color(0xFF52AE6B),
      Color(0xFF4A79EA),
      Color(0xFFA262AD),
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// 毛玻璃模糊主題
  static const ThemeScheme glassmorphismBlur = ThemeScheme(
    name: 'glassmorphism_blur',
    displayName: 'Glassmorphism Blur',
    category: 'glassmorphism',
    primary: Color.fromARGB(255, 94, 94, 94),
    secondary: Color.fromARGB(223, 255, 255, 255),
    accent: Color(0xFF8B5CF6),
    background: Color(0xFFF8F7FF),
    surface: Color.fromARGB(255, 255, 255, 255),
    onPrimary: Color(0xFF2D3748),
    onSecondary: Color(0xFF2D3748),
    onBackground: Color(0xFF2D3748),
    onSurface: Color(0xFF2D3748),
    error: Color(0xFFEF4444),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A8B5CF6),
    outlineVariant: Color(0x80FFFFFF),
    backgroundBlur: 10.0,
    surfaceBlur: 5.0,
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  // ==================== 主題分類系統 ====================

  /// 主題分類枚舉
  static const Map<String, List<ThemeScheme>> themeCategories = {
    'business': [mainStyle, metaBusinessStyle, businessGradient],
    'morandi': [morandiBlue, morandiGreen, morandiLemon],
    'ocean': [beachSunset, oceanGradient],
    'taiwan': [milkTeaEarth, taipei101],
    'emotions': [rainbowPride],
    'glassmorphism': [glassmorphismBlur],
  };

  /// 所有可用主題（精簡版）
  static const List<ThemeScheme> allThemes = [
    mainStyle,
    metaBusinessStyle,
    businessGradient,
    morandiBlue,
    morandiGreen,
    morandiLemon,
    beachSunset,
    oceanGradient,
    milkTeaEarth,
    taipei101,
    rainbowPride,
    glassmorphismBlur,
  ];

  // ==================== 實用方法 ====================

  /// 根據名稱獲取主題
  static ThemeScheme getByName(String name) {
    return allThemes.firstWhere(
      (theme) => theme.name == name,
      orElse: () => mainStyle,
    );
  }

  /// 根據分類獲取主題
  static List<ThemeScheme> getByCategory(String category) {
    return themeCategories[category] ?? [];
  }

  /// 獲取所有分類
  static List<String> getAllCategories() {
    return themeCategories.keys.toList();
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
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: appBarTitleColor ?? onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: onSurface.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: shadow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
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
        outline: outlineVariant,
      ),
      useMaterial3: true,
    );
  }

  /// 創建帶有背景模糊效果的 Widget
  Widget createBlurredBackground({
    required Widget child,
    double? blurRadius,
    Color? backgroundColor,
  }) {
    final double blur = blurRadius ?? backgroundBlur ?? 0.0;
    final Color bgColor = backgroundColor ?? background;

    if (blur <= 0.0) {
      return Container(
        color: bgColor,
        child: child,
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        color: bgColor.withOpacity(0.8),
        child: child,
      ),
    );
  }

  /// 創建漸層背景 Widget
  Widget createGradientBackground({
    required Widget child,
    List<Color>? gradientColors,
    AlignmentGeometry? begin,
    AlignmentGeometry? end,
  }) {
    final List<Color> colors =
        gradientColors ?? backgroundGradient ?? [background];
    final AlignmentGeometry gradientBegin =
        begin ?? this.gradientBegin ?? Alignment.topCenter;
    final AlignmentGeometry gradientEnd =
        end ?? this.gradientEnd ?? Alignment.bottomCenter;

    if (colors.length == 1) {
      return Container(
        color: colors.first,
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: gradientBegin,
          end: gradientEnd,
        ),
      ),
      child: child,
    );
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'category': category,
      'primary': primary.value,
      'secondary': secondary.value,
      'accent': accent.value,
      'background': background.value,
      'surface': surface.value,
      'onPrimary': onPrimary.value,
      'onSecondary': onSecondary.value,
      'onBackground': onBackground.value,
      'onSurface': onSurface.value,
      'error': error.value,
      'onError': onError.value,
      'success': success.value,
      'warning': warning.value,
      'shadow': shadow.value,
      'outlineVariant': outlineVariant.value,
      'backgroundBlur': backgroundBlur,
      'surfaceBlur': surfaceBlur,
      'backgroundGradient': backgroundGradient?.map((c) => c.value).toList(),
      'gradientBegin': gradientBegin.toString(),
      'gradientEnd': gradientEnd.toString(),
      'backArrowColor': backArrowColor.value,
      'backArrowColorInactive': backArrowColorInactive.value,
    };
  }

  /// 從 JSON 格式創建主題
  static ThemeScheme? fromJson(Map<String, dynamic> json) {
    try {
      return ThemeScheme(
        name: json['name'] ?? '',
        displayName: json['displayName'] ?? '',
        category: json['category'] ?? '',
        primary: Color(json['primary'] ?? 0xFF000000),
        secondary: Color(json['secondary'] ?? 0xFF000000),
        accent: Color(json['accent'] ?? 0xFF000000),
        background: Color(json['background'] ?? 0xFF000000),
        surface: Color(json['surface'] ?? 0xFF000000),
        onPrimary: Color(json['onPrimary'] ?? 0xFF000000),
        onSecondary: Color(json['onSecondary'] ?? 0xFF000000),
        onBackground: Color(json['onBackground'] ?? 0xFF000000),
        onSurface: Color(json['onSurface'] ?? 0xFF000000),
        error: Color(json['error'] ?? 0xFF000000),
        onError: Color(json['onError'] ?? 0xFF000000),
        success: Color(json['success'] ?? 0xFF000000),
        warning: Color(json['warning'] ?? 0xFF000000),
        shadow: Color(json['shadow'] ?? 0xFF000000),
        outlineVariant: Color(json['outlineVariant'] ?? 0xFF000000),
        backgroundBlur: json['backgroundBlur']?.toDouble(),
        surfaceBlur: json['surfaceBlur']?.toDouble(),
        backgroundGradient: (json['backgroundGradient'] as List?)
            ?.map((c) => Color(c as int))
            .toList(),
        gradientBegin: _parseAlignment(json['gradientBegin']),
        gradientEnd: _parseAlignment(json['gradientEnd']),
        backArrowColor: Color(json['backArrowColor'] ?? 0xFF000000),
        backArrowColorInactive:
            Color(json['backArrowColorInactive'] ?? 0xFF000000),
      );
    } catch (e) {
      debugPrint('解析主題 JSON 失敗: $e');
      return null;
    }
  }

  /// 解析對齊方式
  static AlignmentGeometry? _parseAlignment(String? alignmentString) {
    if (alignmentString == null) return null;

    switch (alignmentString) {
      case 'Alignment.topLeft':
        return Alignment.topLeft;
      case 'Alignment.topCenter':
        return Alignment.topCenter;
      case 'Alignment.topRight':
        return Alignment.topRight;
      case 'Alignment.centerLeft':
        return Alignment.centerLeft;
      case 'Alignment.center':
        return Alignment.center;
      case 'Alignment.centerRight':
        return Alignment.centerRight;
      case 'Alignment.bottomLeft':
        return Alignment.bottomLeft;
      case 'Alignment.bottomCenter':
        return Alignment.bottomCenter;
      case 'Alignment.bottomRight':
        return Alignment.bottomRight;
      default:
        return Alignment.topCenter;
    }
  }
}
