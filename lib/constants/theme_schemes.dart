import 'package:flutter/material.dart';
import 'dart:ui';

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
  final Color outlineVariant; // 新增 outlineVariant 屬性
  final double? backgroundBlur; // 背景模糊強度
  final double? surfaceBlur; // 表面模糊強度
  final List<Color>? backgroundGradient; // 背景漸層色彩
  final AlignmentGeometry? gradientBegin; // 漸層起始位置
  final AlignmentGeometry? gradientEnd; // 漸層結束位置
  // 新增 backArrowColor 與 backArrowColorInactive
  final Color backArrowColor;
  final Color backArrowColorInactive;

  // 新增 task_create_page.dart 需要的顏色屬性
  final Color cardBackground; // 卡片背景色
  final Color cardBorder; // 卡片邊框色
  final Color inputBackground; // 輸入框背景色
  final Color inputBorder; // 輸入框邊框色
  final Color hintText; // 提示文字顏色
  final Color disabledText; // 禁用文字顏色
  final Color divider; // 分割線顏色
  final Color overlay; // 遮罩顏色
  final Color successBackground; // 成功背景色
  final Color warningBackground; // 警告背景色
  final Color errorBackground; // 錯誤背景色

  // 新增 AppBar 標題與次標題顏色（可選）。若未提供，將在 ThemeConfigManager 中自動推導
  final Color? appBarTitleColor;
  final Color? appBarSubtitleColor;

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
    required this.outlineVariant, // 新增 outlineVariant 參數
    this.backgroundBlur,
    this.surfaceBlur,
    this.backgroundGradient,
    this.gradientBegin,
    this.gradientEnd,
    required this.backArrowColor,
    required this.backArrowColorInactive,
    this.cardBackground = const Color(0xFFFFFFFF), // 白色
    this.cardBorder = const Color(0xFFE5E7EB), // 淺灰色
    this.inputBackground = const Color(0xFFFFFFFF), // 白色
    this.inputBorder = const Color(0xFFD1D5DB), // 中灰色
    this.hintText = const Color(0xFF9CA3AF), // 深灰色
    this.disabledText = const Color(0xFF6B7280), // 中深灰色
    this.divider = const Color(0xFFF3F4F6), // 極淺灰色
    this.overlay = const Color(0x80000000), // 半透明黑色
    this.successBackground = const Color(0xFFD1FAE5), // 淺綠色
    this.warningBackground = const Color(0xFFFEF3C7), // 淺橙色
    this.errorBackground = const Color(0xFFFEE2E2), // 淺紅色
    this.appBarTitleColor,
    this.appBarSubtitleColor,
  });

  /// 主要風格 - 毛玻璃紫色系 (Main Style)
  static const ThemeScheme mainStyle = ThemeScheme(
    name: 'main_style',
    displayName: 'Main Style - Glassmorphism Purple',
    primary: Color(0xFF8B5CF6), // 主要紫色
    secondary: Color(0xFF7C3AED), // 深紫色
    accent: Color(0xFFA78BFA), // 淺紫色
    background: Color(0xFFF8F7FF), // 淺紫背景
    surface: Color(0xFFF3F1FF), // 毛玻璃表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF2D3748), // 深色文字
    onSurface: Color(0xFF2D3748), // 深色文字
    error: Color(0xFFEF4444), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF10B981), // 綠色成功
    warning: Color(0xFFF59E0B), // 橙色警告
    shadow: Color(0x1A8B5CF6), // 紫色陰影
    outlineVariant: Color(0xFF8B5CF6), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    cardBackground: Color(0xFFFFFFFF), // 白色卡片背景
    cardBorder: Color(0xFFE5E7EB), // 淺灰色邊框
    inputBackground: Color(0xFFFFFFFF), // 白色輸入框背景
    inputBorder: Color(0xFFD1D5DB), // 中灰色輸入框邊框
    hintText: Color(0xFF9CA3AF), // 深灰色提示文字
    disabledText: Color(0xFF6B7280), // 中深灰色禁用文字
    divider: Color(0xFFF3F4F6), // 極淺灰色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// Meta 商業網站風格 (Meta Business Style) - 淡紫色主題
  static const ThemeScheme metaBusinessStyle = ThemeScheme(
    name: 'meta_business_style',
    displayName: 'Meta Business Style',
    primary: Color(0xFF8B5CF6), // 淡紫色 (主要色)
    secondary: Color(0xFFA78BFA), // 淺紫色 (次要色)
    accent: Color(0xFF7C3AED), // 深紫色 (強調色)
    background: Color(0xFFF8F7FF), // 淺紫背景
    surface: Color.fromARGB(255, 255, 255, 255), // 半透明白色表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF1C1E21), // 深灰文字
    onSurface: Color(0xFF1C1E21), // 深灰文字
    error: Color(0xFFFA383E), // 錯誤紅
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF42B883), // 成功綠
    warning: Color(0xFFFF9500), // 警告橙
    shadow: Color(0x1A8B5CF6), // 紫色陰影
    outlineVariant: Color(0xFF8B5CF6), // 新增 outlineVariant
    backgroundBlur: 10.0, // 背景模糊效果
    surfaceBlur: 5.0, // 表面模糊效果
    backgroundGradient: [
      Color(0xFFF3F1FF), // 淺紫色 (左上角)
      Color(0xFFE9E5FF), // 更淺紫色 (右上角)
      Color(0xFFF8F7FF), // 淺紫背景
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Color(0xFF1C1E21),
    backArrowColorInactive: Color(0x4D1C1E21),
    cardBackground: Color(0xFFFFFFFF), // 白色卡片背景
    cardBorder: Color(0xFFE5E7EB), // 淺灰色邊框
    inputBackground: Color(0xFFFFFFFF), // 白色輸入框背景
    inputBorder: Color(0xFFD1D5DB), // 中灰色輸入框邊框
    hintText: Color(0xFF9CA3AF), // 深灰色提示文字
    disabledText: Color(0xFF6B7280), // 中深灰色禁用文字
    divider: Color(0xFFF3F4F6), // 極淺灰色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// 商業漸層風格 (Business Gradient) - 淺粉紅到淺黃色到淺藍色
  static const ThemeScheme businessGradient = ThemeScheme(
    name: 'business_gradient',
    displayName: 'Rainbow',
    primary: Color(0xFF6366F1), // 靛藍色 (主要色)
    secondary: Color(0xFF8B5CF6), // 紫色 (次要色)
    accent: Color(0xFFEC4899), // 粉紅色 (強調色)
    background: Color(0xFFFFFFFF), // 純白背景
    surface: Color(0xFFFFFFFF), // 純白表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF1F2937), // 深灰文字
    onSurface: Color(0xFF1F2937), // 深灰文字
    error: Color(0xFFEF4444), // 錯誤紅
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF10B981), // 成功綠
    warning: Color(0xFFF59E0B), // 警告橙
    shadow: Color(0x1A6366F1), // 靛藍色陰影
    outlineVariant: Color(0xFF6366F1), // 新增 outlineVariant
    backgroundBlur: 8.0, // 背景模糊效果
    surfaceBlur: 4.0, // 表面模糊效果
    backgroundGradient: [
      Color(0xFFFFF1F2), // 淺粉紅色 (左上角 - 明亮)
      Color(0xFFFFF7ED), // 淺橙色
      Color(0xFFFFFBF0), // 淺黃色
      Color(0xFFF0F9FF), // 淺藍色
      Color(0xFFE0F2FE), // 中淺藍色
      Color(0xFFDBEAFE), // 深淺藍色 (右下角 - 暗色)
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x4D1F2937),
    cardBackground: Color(0xFFFFFFFF), // 白色卡片背景
    cardBorder: Color(0xFFE5E7EB), // 淺灰色邊框
    inputBackground: Color(0xFFFFFFFF), // 白色輸入框背景
    inputBorder: Color(0xFFD1D5DB), // 中灰色輸入框邊框
    hintText: Color(0xFF9CA3AF), // 深灰色提示文字
    disabledText: Color(0xFF6B7280), // 中深灰色禁用文字
    divider: Color(0xFFF3F4F6), // 極淺灰色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// 莫蘭迪藍色系
  static const ThemeScheme morandiBlue = ThemeScheme(
    name: 'morandi_blue',
    displayName: 'Morandi Blue',
    primary: Color(0xFF6B7A85), // 調整為更深的藍灰色，適合作為背景
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
    outlineVariant: Color(0xFF6B7A85), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    cardBackground: Color(0xFFF8FAFC), // 淺藍色卡片背景
    cardBorder: Color(0xFFE2E8F0), // 淺藍灰色邊框
    inputBackground: Color(0xFFF8FAFC), // 淺藍色輸入框背景
    inputBorder: Color(0xFFCBD5E1), // 中藍灰色輸入框邊框
    hintText: Color(0xFF64748B), // 深藍灰色提示文字
    disabledText: Color(0xFF475569), // 中深藍灰色禁用文字
    divider: Color(0xFFF1F5F9), // 極淺藍灰色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// 莫蘭迪綠色系 - 抹茶綠
  static const ThemeScheme morandiGreen = ThemeScheme(
    name: 'morandi_green',
    displayName: 'Morandi Green - Matcha',
    primary: Color(0xFF6A8A6A), // 調整為更深的抹茶綠，適合作為背景
    secondary: Color(0xFF9BB09B), // 淺抹茶綠
    accent: Color(0xFFB8C5B8), // 極淺抹茶綠
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
    outlineVariant: Color(0xFF6A8A6A), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    cardBackground: Color(0xFFF8FCF8), // 淺綠色卡片背景
    cardBorder: Color(0xFFE2F0E2), // 淺綠色邊框
    inputBackground: Color(0xFFF8FCF8), // 淺綠色輸入框背景
    inputBorder: Color(0xFFCBD5CB), // 中綠色輸入框邊框
    hintText: Color(0xFF647864), // 深綠色提示文字
    disabledText: Color(0xFF475547), // 中深綠色禁用文字
    divider: Color(0xFFF1F5F1), // 極淺綠色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// 莫蘭迪紫色系
  static const ThemeScheme morandiPurple = ThemeScheme(
    name: 'morandi_purple',
    displayName: 'Morandi Purple',
    primary: Color(0xFF8B7A85), // 調整為更深的紫色，適合作為背景
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
    outlineVariant: Color(0xFF8B7A85), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    cardBackground: Color(0xFFFCF8FC), // 淺紫色卡片背景
    cardBorder: Color(0xFFF0E8F0), // 淺紫色邊框
    inputBackground: Color(0xFFFCF8FC), // 淺紫色輸入框背景
    inputBorder: Color(0xFFE5D5E5), // 中紫色輸入框邊框
    hintText: Color(0xFF786478), // 深紫色提示文字
    disabledText: Color(0xFF574857), // 中深紫色禁用文字
    divider: Color(0xFFF5F1F5), // 極淺紫色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// 莫蘭迪粉色系
  static const ThemeScheme morandiPink = ThemeScheme(
    name: 'morandi_pink',
    displayName: 'Morandi Pink',
    primary: Color(0xFFA55566), // 調整為更深的粉色，適合作為背景
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
    outlineVariant: Color(0xFFA55566), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    cardBackground: Color(0xFFFCF8FA), // 淺粉色卡片背景
    cardBorder: Color(0xFFF0E8EA), // 淺粉色邊框
    inputBackground: Color(0xFFFCF8FA), // 淺粉色輸入框背景
    inputBorder: Color(0xFFE5D5D9), // 中粉色輸入框邊框
    hintText: Color(0xFF78646B), // 深粉色提示文字
    disabledText: Color(0xFF574857), // 中深粉色禁用文字
    divider: Color(0xFFF5F1F3), // 極淺粉色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// 莫蘭迪橙色系
  static const ThemeScheme morandiOrange = ThemeScheme(
    name: 'morandi_orange',
    displayName: 'Morandi Orange',
    primary: Color(0xFFC49564), // 調整為更深的橙色，適合作為背景
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
    outlineVariant: Color(0xFFC49564), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    cardBackground: Color(0xFFFCFAF8), // 淺橙色卡片背景
    cardBorder: Color(0xFFF0EAE0), // 淺橙色邊框
    inputBackground: Color(0xFFFCFAF8), // 淺橙色輸入框背景
    inputBorder: Color(0xFFE5D5C5), // 中橙色輸入框邊框
    hintText: Color(0xFF78645A), // 深橙色提示文字
    disabledText: Color(0xFF574857), // 中深橙色禁用文字
    divider: Color(0xFFF5F1ED), // 極淺橙色分割線
    overlay: Color(0x80000000), // 半透明黑色遮罩
    successBackground: Color(0xFFD1FAE5), // 淺綠色成功背景
    warningBackground: Color(0xFFFEF3C7), // 淺橙色警告背景
    errorBackground: Color(0xFFFEE2E2), // 淺紅色錯誤背景
  );

  /// 莫蘭迪檸檬黃色系
  static const ThemeScheme morandiLemon = ThemeScheme(
    name: 'morandi_lemon',
    displayName: 'Yellow',
    primary: Color(0xFFB4A864), // 調整為更深的檸檬黃，適合作為背景
    secondary: Color(0xFFD4C8A8), // 更低飽和度的淺檸檬黃
    accent: Color(0xFFE4DCC5), // 更低飽和度的極淺檸檬黃
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
    outlineVariant: Color(0xFFB4A864), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 海灘日落主題 - Ocean 風格
  static const ThemeScheme beachSunset = ThemeScheme(
    name: 'beach_sunset',
    displayName: 'Beach Sunset - Ocean Style',
    primary: Color(0xFF00BCD4), // 碧綠色 (Cyan)
    secondary: Color(0xFF26C6DA), // 淺碧綠色
    accent: Color(0xFF4DD0E1), // 更淺碧綠色
    background: Color(0xFFE0F7FA), // 淺碧綠背景
    surface: Color(0xFFB2EBF2), // 淺碧綠表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF006064), // 深碧綠文字
    onSurface: Color(0xFF006064), // 深碧綠文字
    error: Color(0xFFE53E3E), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF38A169), // 綠色成功
    warning: Color(0xFFD69E2E), // 橙色警告
    shadow: Color(0x1A00BCD4), // 碧綠色陰影
    outlineVariant: Color(0xFF00BCD4), // 新增 outlineVariant
    backgroundGradient: [
      Color(0xFFFDFCF7), // 極淺米色 (左上角 - 明亮)
      Color(0xFFF5F0E8), // 淺米色
      Color(0xFFE8D4C0), // 淺沙色
      Color(0xFFD4B8A0), // 中等沙色
      Color(0xFFC19B7A), // 深沙色
      Color(0xFFA67B5A), // 最深沙色 (右下角 - 暗色)
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 海洋漸層主題 - 基於 Pacific Ocean 色卡 (海洋漸層)
  static const ThemeScheme oceanGradient = ThemeScheme(
    name: 'ocean_gradient',
    displayName: 'Ocean Gradient',
    primary: Color(0xFF1182A4), // 基於 Pacific Ocean 色卡的第三色
    secondary: Color(0xFF2FA7B4), // 基於 Pacific Ocean 色卡的第四色
    accent: Color(0xFF00618D), // 基於 Pacific Ocean 色卡的第二色
    background: Color(0xFFF0F8FF), // 淺藍背景
    surface: Color(0xFFE6F3FF), // 淺藍表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF004065), // 基於 Pacific Ocean 色卡的第一色作為文字
    onSurface: Color(0xFF004065), // 基於 Pacific Ocean 色卡的第一色作為文字
    error: Color(0xFFE53E3E), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF38A169), // 綠色成功
    warning: Color(0xFFD69E2E), // 橙色警告
    shadow: Color(0x1A1182A4), // 主要色陰影
    outlineVariant: Color(0xFF1182A4), // 新增 outlineVariant
    backgroundGradient: [
      Color(0xFFE6E2D8), // 更淡的淺沙色 (左上角 - 最明亮)
      Color(0xFF7BC8D1), // 更淡的淺青藍色
      Color(0xFF5BA3C2), // 更淡的中藍色
      Color(0xFF4A8BA8), // 更淡的深藍色
      Color(0xFF3A6B8A), // 更淡的最深藍色 (右下角 - 最暗)
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 沙灘足跡主題 - 基於第三張色卡 (沙灘足跡)
  static const ThemeScheme sandyFootprints = ThemeScheme(
    name: 'sandy_footprints',
    displayName: 'Sandy Footprints',
    primary: Color(0xFF20B2AA), // 海綠色
    secondary: Color(0xFF48CAE4), // 淺青色
    accent: Color(0xFF90E0EF), // 淺藍色
    background: Color(0xFFFDFCF7), // 米白色背景
    surface: Color(0xFFF8F6F0), // 淺米色表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF2D3748), // 深色文字
    onSurface: Color(0xFF2D3748), // 深色文字
    error: Color(0xFFE53E3E), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF38A169), // 綠色成功
    warning: Color(0xFFD69E2E), // 橙色警告
    shadow: Color(0x1A20B2AA), // 海綠色陰影
    outlineVariant: Color(0xFF20B2AA), // 新增 outlineVariant
    backgroundGradient: [
      Color(0xFFFDFCF7), // 米白色 (左上角 - 明亮)
      Color(0xFFF5F0E8), // 淺米色
      Color(0xFFE8D4C0), // 淺沙色
      Color(0xFFD4B8A0), // 中等沙色
      Color(0xFFC19B7A), // 深沙色
      Color(0xFFA67B5A), // 最深沙色 (右下角 - 暗色)
    ],
    gradientBegin: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// Pantone 奶茶色主題 - 基於 Pantone 482C/481C/480C 色卡
  static const ThemeScheme milkTeaEarth = ThemeScheme(
    name: 'milk_tea_earth',
    displayName: 'Pantone Milk Tea',
    primary: Color(0xFF8B6B5A), // Pantone 480C - 最深棕色
    secondary: Color(0xFFA67B5A), // Pantone 481C - 中等棕色
    accent: Color(0xFFC19B7A), // Pantone 482C - 最淺米色
    background: Color(0xFFFDFCF7), // 淺奶油背景
    surface: Color(0xFFF8F6F0), // 淺米色表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF2D3748), // 深色文字
    onSurface: Color(0xFF2D3748), // 深色文字
    error: Color(0xFFE53E3E), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF38A169), // 綠色成功
    warning: Color(0xFFD69E2E), // 橙色警告
    shadow: Color(0x1A8B6B5A), // 棕色陰影
    outlineVariant: Color(0xFF8B6B5A), // 新增 outlineVariant
    backgroundGradient: [
      Color(0xFFFDFCF7), // 極淺奶油色 (左上角 - 明亮)
      Color(0xFFF5F0E8), // 淺米色
      Color(0xFFE8D4C0), // 中等米色
      Color(0xFFD4B8A0), // 深米色
      Color(0xFFB89A7A), // 深棕色
      Color(0xFF8B6B5A), // 最深棕色 (右下角 - 暗色)
    ],
    gradientBegin: Alignment(-1.0, -1.0), // 45度漸層 - 左上角
    gradientEnd: Alignment(1.0, 1.0), // 45度漸層 - 右下角
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    appBarTitleColor: Colors.white,
    appBarSubtitleColor: Colors.white,
  );

  /// 簡約靜物主題 - 基於簡約靜物色卡
  static const ThemeScheme minimalistStill = ThemeScheme(
    name: 'minimalist_still',
    displayName: 'Old Street',
    primary: Color(0xFF5A6B7A), // 深藍灰色
    secondary: Color(0xFF6B7A8A), // 中藍灰色
    accent: Color(0xFF87CEEB), // 天空藍
    background: Color(0xFFF5F5F0), // 淺米色背景
    surface: Color(0xFFF8F8F3), // 淺米色表面
    onPrimary: Color(0xFFFFFFFF), // 白色文字
    onSecondary: Color(0xFFFFFFFF), // 白色文字
    onBackground: Color(0xFF2D3748), // 深色文字
    onSurface: Color(0xFF2D3748), // 深色文字
    error: Color(0xFFE53E3E), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF38A169), // 綠色成功
    warning: Color(0xFFD69E2E), // 橙色警告
    shadow: Color(0x1A5A6B7A), // 藍灰色陰影
    outlineVariant: Color(0xFF5A6B7A), // 新增 outlineVariant
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
    appBarTitleColor: Colors.white,
    appBarSubtitleColor: Colors.white,
  );

  /// 毛玻璃模糊主題 - 支援背景模糊效果
  static const ThemeScheme glassmorphismBlur = ThemeScheme(
    name: 'glassmorphism_blur',
    displayName: 'Glassmorphism Blur',
    primary: Color.fromARGB(255, 94, 94, 94), // 半透明白色
    secondary: Color.fromARGB(223, 255, 255, 255), // 半透明白色
    accent: Color(0xFF8B5CF6), // 紫色強調
    background: Color(0xFFF8F7FF), // 淺紫背景
    surface: Color.fromARGB(255, 255, 255, 255), // 半透明白色表面
    onPrimary: Color(0xFF2D3748), // 深色文字
    onSecondary: Color(0xFF2D3748), // 深色文字
    onBackground: Color(0xFF2D3748), // 深色文字
    onSurface: Color(0xFF2D3748), // 深色文字
    error: Color(0xFFEF4444), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF10B981), // 綠色成功
    warning: Color(0xFFF59E0B), // 橙色警告
    shadow: Color(0x1A8B5CF6), // 紫色陰影
    outlineVariant: Color(0x80FFFFFF), // 新增 outlineVariant
    backgroundBlur: 10.0, // 背景模糊 10px
    surfaceBlur: 5.0, // 表面模糊 5px
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// Taiwan - Taipei（取自：Timeless Gray / Vibrant Pink / Revitalizing Green）
  /// 不使用漸層，採用溫潤米白背景與高可讀性前景
  static const ThemeScheme taipei = ThemeScheme(
    name: 'taipei_2019_pantone',
    displayName: 'Taipei',
    primary: Color(0xFF9FB65A), // Revitalizing Green 作為主要互動色
    secondary: Color(0xFFE58FB0), // Vibrant Pink 作為次要強調
    accent: Color(0xFFB6C77A), // 綠色的較亮版本
    background: Color(0xFFF7F5F2), // 溫潤米白背景
    surface: Color(0xFFFAF8F5), // 卡片/面板
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF3B3B3B), // Timeless Gray 系列深灰
    onSurface: Color(0xFF3B3B3B),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFF9C6F19),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFCEC8C0),
    backArrowColor: Color(0xFF3B3B3B),
    backArrowColorInactive: Color(0x803B3B3B),
    cardBackground: Color(0xFFFAF8F5),
    cardBorder: Color(0xFFE6E0D7),
    inputBackground: Color(0xFFFAF8F5),
    inputBorder: Color(0xFFDCD4CA),
    hintText: Color(0xFF7A746C),
    disabledText: Color(0xFF9D968D),
    divider: Color(0xFFEFEAE3),
    overlay: Color(0x33000000),
    successBackground: Color(0xFFDDE7D8),
    warningBackground: Color(0xFFF3E8D5),
    errorBackground: Color(0xFFF4DADA),
    appBarTitleColor: Colors.white,
    appBarSubtitleColor: Colors.white,
  );

  /// Taiwan - Taipei 101：夜晚藍天 + 冷白燈飾 + 建築深藍灰
  static const ThemeScheme taipei101 = ThemeScheme(
    name: 'taipei_101',
    displayName: 'Taipei 101',
    primary: Color(0xFF4DA3FF), // 亮藍（街區冷白燈偏藍）
    secondary: Color(0xFF40C4FF), // 天色偏亮藍
    accent: Color(0xFF82B1FF),
    background: Color(0xFFEFF5FF), // 微藍的冷白背景
    surface: Color(0xFFF7FAFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF0D1B2A),
    onBackground: Color(0xFF273043), // 建築與夜色的深藍灰
    onSurface: Color(0xFF273043),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFF9C6F19),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFBFD4F2),
    backArrowColor: Color(0xFF273043),
    backArrowColorInactive: Color(0x80273043),
    cardBackground: Color(0xFFF7FAFF),
    cardBorder: Color(0xFFD6E6FF),
    inputBackground: Color(0xFFF7FAFF),
    inputBorder: Color(0xFFC9DBF4),
    hintText: Color(0xFF6B7A90),
    disabledText: Color(0xFF90A4B8),
    divider: Color(0xFFE3EEFF),
    overlay: Color(0x33000000),
    successBackground: Color(0xFFD7F0E0),
    warningBackground: Color(0xFFF3EBD6),
    errorBackground: Color(0xFFF6DADA),
    appBarTitleColor: Colors.white,
    appBarSubtitleColor: Colors.white,
  );

  /// LGBTQ+ - 彩虹驕傲六色主題（Red/Orange/Yellow/Green/Blue/Violet）
  static const ThemeScheme rainbowPride = ThemeScheme(
    name: 'rainbow_pride',
    displayName: 'Rainbow Pride',
    primary: Color(0xFF004DFF), // Blue 作為主要互動色（穩定、可讀）
    secondary: Color(0xFF750787), // Violet 作為次要色
    accent: Color(0xFFFFED00), // Yellow 作為點綴
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1F2937),
    onSurface: Color(0xFF1F2937),
    error: Color(0xFFE40303), // Red（依旗幟紅）
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF008026), // Green
    warning: Color(0xFFFF8C00), // Orange
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFE5E7EB),
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x801F2937),
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E7EB),
    inputBackground: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFD1D5DB),
    hintText: Color(0xFF6B7280),
    disabledText: Color(0xFF9CA3AF),
    divider: Color(0xFFF3F4F6),
    overlay: Color(0x33000000),
    successBackground: Color(0xFFE6F4EA),
    warningBackground: Color(0xFFFFF4E5),
    errorBackground: Color(0xFFFDE8E8),
    // 45° 背景漸層（降低飽和度的一階柔和版）
    backgroundGradient: [
      Color(0xFFE65C5C), // softer + darker red
      Color(0xFFF2A64F), // softer + darker orange
      Color(0xFFF2E86A), // softer + darker yellow
      Color(0xFF52AE6B), // softer + darker green
      Color(0xFF4A79EA), // softer + darker blue
      Color(0xFFA262AD), // softer + darker violet
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// LGBTQ+ - Trans（Light Blue / White / Pink 漸層）
  static const ThemeScheme trans = ThemeScheme(
    name: 'trans',
    displayName: 'Trans',
    primary: Color(0xFF55CDFC), // Light Blue
    secondary: Color(0xFFF7A8B8), // Pink
    accent: Color(0xFFFFFFFF), // White（作為點綴）
    background: Color(0xFFFDFDFE),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF0F172A),
    onSecondary: Color(0xFF0F172A),
    onBackground: Color(0xFF111827),
    onSurface: Color(0xFF111827),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFE5E7EB),
    backArrowColor: Color(0xFF111827),
    backArrowColorInactive: Color(0x80111827),
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E7EB),
    inputBackground: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFD1D5DB),
    hintText: Color(0xFF6B7280),
    disabledText: Color(0xFF9CA3AF),
    divider: Color(0xFFF3F4F6),
    overlay: Color(0x33000000),
    successBackground: Color(0xFFE7F7ED),
    warningBackground: Color(0xFFFFF4E5),
    errorBackground: Color(0xFFFDE8E8),
    backgroundGradient: [
      Color(0xFF9ED5F0), // darker light blue
      Color(0xFFFFFFFF), // white
      Color(0xFFE8B5C2), // darker pink
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// LGBTQ+ - Lesbian（以旗幟橘/粉/洋紅為基礎，UI 取高對比組合）
  static const ThemeScheme lesbianTheme = ThemeScheme(
    name: 'lesbian_theme',
    displayName: 'Lesbian',
    // 經典旗幟色系：深洋紅/粉紫/橘，採 UI 高對比
    primary: Color(0xFFA30262), // 深洋紅
    secondary: Color(0xFFD362A4), // 粉紫
    accent: Color(0xFFFF9A56), // 橘
    background: Color(0xFFFEF7F9),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF1F2937),
    onBackground: Color(0xFF1F2937),
    onSurface: Color(0xFF1F2937),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFF1D2E5),
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x801F2937),
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E7EB),
    inputBackground: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFD1D5DB),
    hintText: Color(0xFF6B7280),
    disabledText: Color(0xFF9CA3AF),
    divider: Color(0xFFF3F4F6),
    overlay: Color(0x33000000),
    successBackground: Color(0xFFE6F4EA),
    warningBackground: Color(0xFFFFF4E5),
    errorBackground: Color(0xFFFDE8E8),
    backgroundGradient: [
      Color(0xFFC05890), // darker magenta
      Color(0xFFD496B6), // darker pink purple
      Color(0xFFF2B67F), // darker orange
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// LGBTQ+ - Non-binary（黃/白/紫/黑，UI 取紫為 primary、黃為 secondary）
  static const ThemeScheme nonBinaryTheme = ThemeScheme(
    name: 'non_binary_theme',
    displayName: 'Non-binary',
    primary: Color(0xFF9B59D0), // 紫
    secondary: Color(0xFFFFF433), // 黃
    accent: Color(0xFF111111), // 黑
    background: Color(0xFFFBFBFD),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF111827),
    onBackground: Color(0xFF111827),
    onSurface: Color(0xFF111827),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFE5E7EB),
    backArrowColor: Color(0xFF111827),
    backArrowColorInactive: Color(0x80111827),
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E7EB),
    inputBackground: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFD1D5DB),
    hintText: Color(0xFF6B7280),
    disabledText: Color(0xFF9CA3AF),
    divider: Color(0xFFF3F4F6),
    overlay: Color(0x33000000),
    successBackground: Color(0xFFE7F7ED),
    warningBackground: Color(0xFFFFF4E5),
    errorBackground: Color(0xFFFDE8E8),
    backgroundGradient: [
      Color(0xFFF0EA94), // darker yellow
      Color(0xFFFFFFFF), // white
      Color(0xFFB487D3), // darker purple
      Color(0xFF4A4A4A), // darker gray-black
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// LGBTQ+ - Bear Gay（棕/橙/黃/棕褐/白/灰/黑，UI 取溫暖棕橙）
  static const ThemeScheme bearGayFlat = ThemeScheme(
    name: 'bear_gay_flat',
    displayName: 'Bears',
    primary: Color(0xFFE0812C), // 橙
    secondary: Color(0xFF5C3A21), // 深棕
    accent: Color(0xFFF3C55A), // 黃
    background: Color(0xFFFAF5EF), // 淺棕褐背景
    surface: Color(0xFFFEFCFA),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF2D2520),
    onSurface: Color(0xFF2D2520),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFF9C6F19),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFE6D8C8),
    backArrowColor: Color(0xFF2D2520),
    backArrowColorInactive: Color(0x802D2520),
    cardBackground: Color(0xFFFEFCFA),
    cardBorder: Color(0xFFEADCCB),
    inputBackground: Color(0xFFFEFCFA),
    inputBorder: Color(0xFFE1D3C2),
    hintText: Color(0xFF7A6E63),
    disabledText: Color(0xFFA39588),
    divider: Color(0xFFF0E5D8),
    overlay: Color(0x33000000),
    successBackground: Color(0xFFE7F2E5),
    warningBackground: Color(0xFFF7ECD9),
    errorBackground: Color(0xFFF6DEDE),
    backgroundGradient: [
      Color(0xFF8B6D55), // darker brown
      Color(0xFFE5A561), // darker soft orange
      Color(0xFFEAD18F), // darker soft yellow
      Color(0xFFFFFFFF), // white stripe
      Color(0xFFB5B5B5), // darker gray stripe
      Color(0xFF4D4D4D), // darker gray-black
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// LGBTQ+ - Pride S-Curve（S 曲線彩虹背景，UI 元素採藍主色以維持可讀性）
  static const ThemeScheme prideSCurve = ThemeScheme(
    name: 'pride_s_curve',
    displayName: 'Pride S-Curve',
    primary: Color(0xFF4A79EA), // 較穩定的藍色作為互動主色
    secondary: Color(0xFFA262AD), // 紫作為次色
    accent: Color(0xFFF2A64F), // 橙作為點綴
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1F2937),
    onSurface: Color(0xFF1F2937),
    error: Color(0xFFE65C5C),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF52AE6B),
    warning: Color(0xFFF2A64F),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFE5E7EB),
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x801F2937),
    // 使用 S 曲線繪製，不設 linear 背景漸層
    appBarTitleColor: Colors.white,
    appBarSubtitleColor: Colors.white,
  );

  /// Ocean - Sunset Beach（夕陽粉橘 + 藍紫）
  static const ThemeScheme sunsetBeach = ThemeScheme(
    name: 'sunset_beach',
    displayName: 'Sunset Beach',
    primary: Color(0xFFFF8A65),
    secondary: Color(0xFF7E57C2),
    accent: Color(0xFFFFB3C1),
    background: Color(0xFFFFF7F2),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF2C3E50),
    onSurface: Color(0xFF2C3E50),
    error: Color(0xFFE65C5C),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFF2A64F),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFE6D7CC),
    backArrowColor: Color(0xFF2C3E50),
    backArrowColorInactive: Color(0x802C3E50),
    backgroundGradient: [
      Color(0xFFFFB08A),
      Color(0xFFFFC4D2),
      Color(0xFF9E84FF),
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// Ocean - Clownfish（小丑魚：橘/白/黑條紋）
  static const ThemeScheme clownfish = ThemeScheme(
    name: 'clownfish',
    displayName: 'Clownfish',
    primary: Color(0xFFFF7F2A),
    secondary: Color(0xFFFFFFFF),
    accent: Color(0xFF111111),
    background: Color(0xFFFFFBF6),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF111111),
    onBackground: Color(0xFF1F2937),
    onSurface: Color(0xFF1F2937),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFEDE3D7),
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x801F2937),
    backgroundGradient: [
      Color(0xFFFF8C3A),
      Color(0xFFFFFFFF),
      Color(0xFF333333),
      Color(0xFFFFFFFF),
      Color(0xFFFF8C3A),
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// Ocean - Patrick Star（粉紅 + 青綠 + 紫色點綴）
  static const ThemeScheme patrickStar = ThemeScheme(
    name: 'patrick_star',
    displayName: 'Patrick Star',
    primary: Color(0xFFF78DA7),
    secondary: Color(0xFF8ED081),
    accent: Color(0xFF9460D6),
    background: Color(0xFFFFF3F6),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF0F172A),
    onBackground: Color(0xFF1F2937),
    onSurface: Color(0xFF1F2937),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFF59E0B),
    shadow: Color(0x1A000000),
    outlineVariant: Color(0xFFEAD5E0),
    backArrowColor: Color(0xFF1F2937),
    backArrowColorInactive: Color(0x801F2937),
    backgroundGradient: [
      Color(0xFFF9A9BC),
      Color(0xFFBEE8B6),
      Color(0xFFB695E6),
    ],
    gradientBegin: Alignment(-1.0, -1.0),
    gradientEnd: Alignment(1.0, 1.0),
  );

  /// 毛玻璃藍灰色主題 - Blue Grey 色系
  static const ThemeScheme glassmorphismBlueGrey = ThemeScheme(
    name: 'glassmorphism_blue_grey',
    displayName: 'Glassmorphism Blue Grey',
    primary: Color(0x805C7C8A), // 半透明藍灰色
    secondary: Color(0x807B8A95), // 半透明中藍灰色
    accent: Color(0xFF546E7A), // 深藍灰色強調
    background: Color(0xFFF5F7FA), // 淺藍灰背景
    surface: Color(0x80CFD8DC), // 半透明淺藍灰表面
    onPrimary: Color(0xFF2D3748), // 深色文字
    onSecondary: Color(0xFF2D3748), // 深色文字
    onBackground: Color(0xFF37474F), // 深藍灰色文字
    onSurface: Color(0xFF37474F), // 深藍灰色文字
    error: Color(0xFFEF4444), // 紅色錯誤
    onError: Color(0xFFFFFFFF), // 白色文字
    success: Color(0xFF10B981), // 綠色成功
    warning: Color(0xFFF59E0B), // 橙色警告
    shadow: Color(0x1A546E7A), // 藍灰色陰影
    outlineVariant: Color(0x805C7C8A), // 新增 outlineVariant
    backgroundBlur: 12.0, // 背景模糊 12px
    surfaceBlur: 6.0, // 表面模糊 6px
    backArrowColor: Colors.white,
    backArrowColorInactive: Color(0x4DFFFFFF),
  );

  /// 所有可用主題
  static const List<ThemeScheme> allThemes = [
    mainStyle,
    metaBusinessStyle,
    businessGradient,
    morandiBlue,
    morandiGreen,
    morandiPurple,
    morandiPink,
    morandiOrange,
    morandiLemon,
    beachSunset,
    oceanGradient,
    sandyFootprints,
    milkTeaEarth,
    minimalistStill,
    glassmorphismBlur,
    glassmorphismBlueGrey,
    taipei,
    taipei101,
    rainbowPride,
    trans,
    lesbianTheme,
    nonBinaryTheme,
    bearGayFlat,
    prideSCurve,
    sunsetBeach,
    clownfish,
    patrickStar,
  ];

  /// 根據名稱獲取主題
  static ThemeScheme getByName(String name) {
    return allThemes.firstWhere(
      (theme) => theme.name == name,
      orElse: () => mainStyle, // 預設使用主要風格
    );
  }

  /// 轉換為 Material ThemeData
  ThemeData toThemeData() {
    // 為特定主題（如 taipei_101）提供可選的裝飾背景（此處以無漸層為原則，背景圖樣可由 AppScaffold 另行覆蓋）
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 2),
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
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withOpacity(0.9), // 提高透明度到 0.9，讓文字更清晰
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          color: onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500, // 增加字重讓文字更明顯
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

  /// 創建帶有表面模糊效果的 Widget
  Widget createBlurredSurface({
    required Widget child,
    double? blurRadius,
    Color? surfaceColor,
  }) {
    final double blur = blurRadius ?? surfaceBlur ?? 0.0;
    final Color surfaceCol = surfaceColor ?? surface;

    if (blur <= 0.0) {
      return Container(
        color: surfaceCol,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          color: surfaceCol.withOpacity(0.8),
          child: child,
        ),
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

  /// 創建帶有漸層和模糊效果的背景 Widget
  Widget createGradientBlurredBackground({
    required Widget child,
    List<Color>? gradientColors,
    AlignmentGeometry? begin,
    AlignmentGeometry? end,
    double? blurRadius,
  }) {
    final double blur = blurRadius ?? backgroundBlur ?? 0.0;

    if (blur <= 0.0) {
      return createGradientBackground(
        child: child,
        gradientColors: gradientColors,
        begin: begin,
        end: end,
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: createGradientBackground(
        child: child,
        gradientColors: gradientColors,
        begin: begin,
        end: end,
      ),
    );
  }

  /// 創建帶有模糊效果的下拉選單背景
  Widget createBlurredDropdownBackground({
    required Widget child,
    double? blurRadius,
    Color? backgroundColor,
  }) {
    final double blur = blurRadius ?? 5.0; // 預設 5px 模糊
    final Color bgColor = backgroundColor ?? Colors.white.withOpacity(0.75);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          color: bgColor,
          child: child,
        ),
      ),
    );
  }

  /// 生成 Dark Mode 版本的主題
  ThemeScheme toDarkMode() {
    // 為 Rainbow 主題創建特殊的 Dark Mode 漸層
    List<Color>? darkBackgroundGradient;
    if (name == 'business_gradient') {
      darkBackgroundGradient = _createRainbowDarkGradient();
    } else {
      darkBackgroundGradient =
          backgroundGradient?.map((c) => _convertToDarkColor(c)).toList();
    }

    return ThemeScheme(
      name: '${name}_dark',
      displayName: '$displayName (Dark)',
      primary: _convertToDarkColor(primary),
      secondary: _convertToDarkColor(secondary),
      accent: _convertToDarkColor(accent),
      background: _convertToDarkBackground(background),
      surface: _convertToDarkSurface(surface),
      onPrimary: _convertToDarkOnColor(onPrimary),
      onSecondary: _convertToDarkOnColor(onSecondary),
      onBackground: _convertToDarkOnBackground(onBackground),
      onSurface: _convertToDarkOnSurface(onSurface),
      error: _convertToDarkError(error),
      onError: _convertToDarkOnColor(onError),
      success: _convertToDarkSuccess(success),
      warning: _convertToDarkWarning(warning),
      shadow: _convertToDarkShadow(shadow),
      outlineVariant:
          _convertToDarkOutlineVariant(outlineVariant), // 新增 outlineVariant
      backgroundBlur: backgroundBlur,
      surfaceBlur: surfaceBlur,
      backgroundGradient: darkBackgroundGradient,
      gradientBegin: gradientBegin,
      gradientEnd: gradientEnd,
      backArrowColor: backArrowColor,
      backArrowColorInactive: backArrowColorInactive,
    );
  }

  /// 轉換主要顏色為 Dark Mode
  Color _convertToDarkColor(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 降低亮度，提高飽和度
    double newLightness = (hsl.lightness * 0.6).clamp(0.1, 0.9);
    double newSaturation = (hsl.saturation * 1.2).clamp(0.0, 1.0);

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      newSaturation,
      newLightness,
    ).toColor();
  }

  /// 轉換背景色為 Dark Mode
  Color _convertToDarkBackground(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 大幅降低亮度，保持低飽和度
    double newLightness = (hsl.lightness * 0.15).clamp(0.05, 0.25);
    double newSaturation = (hsl.saturation * 0.3).clamp(0.0, 0.5);

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      newSaturation,
      newLightness,
    ).toColor();
  }

  /// 轉換表面色為 Dark Mode
  Color _convertToDarkSurface(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 適度降低亮度，保持中等飽和度
    double newLightness = (hsl.lightness * 0.25).clamp(0.1, 0.35);
    double newSaturation = (hsl.saturation * 0.5).clamp(0.0, 0.7);

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      newSaturation,
      newLightness,
    ).toColor();
  }

  /// 轉換文字顏色為 Dark Mode
  Color _convertToDarkOnColor(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 確保所有文字都是亮色系，提高對比度
    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      hsl.saturation * 0.1, // 進一步降低飽和度，避免過於鮮豔
      0.98, // 極高亮度，確保文字清晰可見
    ).toColor();
  }

  /// 轉換背景文字顏色為 Dark Mode
  Color _convertToDarkOnBackground(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 轉為亮色系文字，提高對比度
    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      hsl.saturation * 0.1, // 進一步降低飽和度，避免過於鮮豔
      0.95, // 極高亮度，確保文字清晰可見
    ).toColor();
  }

  /// 轉換表面文字顏色為 Dark Mode
  Color _convertToDarkOnSurface(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 轉為亮色系文字，提高對比度
    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      hsl.saturation * 0.1, // 進一步降低飽和度，避免過於鮮豔
      0.92, // 高亮度，確保文字清晰可見
    ).toColor();
  }

  /// 轉換錯誤色為 Dark Mode
  Color _convertToDarkError(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 保持錯誤色的鮮明度，但調整亮度
    double newLightness = (hsl.lightness * 0.7).clamp(0.3, 0.8);

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      hsl.saturation,
      newLightness,
    ).toColor();
  }

  /// 轉換成功色為 Dark Mode
  Color _convertToDarkSuccess(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 保持成功色的鮮明度，但調整亮度
    double newLightness = (hsl.lightness * 0.7).clamp(0.3, 0.8);

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      hsl.saturation,
      newLightness,
    ).toColor();
  }

  /// 轉換警告色為 Dark Mode
  Color _convertToDarkWarning(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 保持警告色的鮮明度，但調整亮度
    double newLightness = (hsl.lightness * 0.7).clamp(0.3, 0.8);

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      hsl.saturation,
      newLightness,
    ).toColor();
  }

  /// 轉換陰影色為 Dark Mode
  Color _convertToDarkShadow(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 陰影在 Dark Mode 中應該更明顯
    double newLightness = (hsl.lightness * 0.3).clamp(0.0, 0.2);
    double newSaturation = (hsl.saturation * 0.5).clamp(0.0, 0.3);

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      newSaturation,
      newLightness,
    ).toColor();
  }

  /// 轉換 outlineVariant 為 Dark Mode
  Color _convertToDarkOutlineVariant(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 確保 outlineVariant 在 Dark Mode 中也是亮色系
    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      hsl.saturation * 0.1, // 進一步降低飽和度，避免過於鮮豔
      0.98, // 極高亮度，確保文字清晰可見
    ).toColor();
  }

  /// 創建 Rainbow 主題的 Dark Mode 漸層
  List<Color> _createRainbowDarkGradient() {
    // 基於原始彩虹漸層顏色創建低飽和度偏暗版本
    return [
      _convertRainbowColorToDark(const Color(0xFFFFF1F2)), // 淺粉紅色 → 深粉紅色
      _convertRainbowColorToDark(const Color(0xFFFFF7ED)), // 淺橙色 → 深橙色
      _convertRainbowColorToDark(const Color(0xFFFFFBF0)), // 淺黃色 → 深黃色
      _convertRainbowColorToDark(const Color(0xFFF0F9FF)), // 淺藍色 → 深藍色
      _convertRainbowColorToDark(const Color(0xFFE0F2FE)), // 中淺藍色 → 中深藍色
      _convertRainbowColorToDark(const Color(0xFFDBEAFE)), // 深淺藍色 → 深藍色
    ];
  }

  /// 將彩虹主題的顏色轉換為 Dark Mode 版本
  Color _convertRainbowColorToDark(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);

    // 大幅降低亮度，適度降低飽和度，保持色相
    double newLightness = (hsl.lightness * 0.2).clamp(0.08, 0.25); // 更暗
    double newSaturation = (hsl.saturation * 0.6).clamp(0.1, 0.8); // 適度降低飽和度

    return HSLColor.fromAHSL(
      hsl.alpha,
      hsl.hue,
      newSaturation,
      newLightness,
    ).toColor();
  }

  /// 轉換為 JSON 格式
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
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
      'outlineVariant': outlineVariant.value, // 新增 outlineVariant
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
        outlineVariant:
            Color(json['outlineVariant'] ?? 0xFF000000), // 新增 outlineVariant
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
