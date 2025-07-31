import 'package:flutter/material.dart';

/// 莫蘭迪藍色系配色方案
class AppColors {
  // 主要色彩
  static const Color primary = Color(0xFF7B8A95); // 莫蘭迪深灰藍
  static const Color secondary = Color(0xFF9BA8B4); // 莫蘭迪中灰藍
  static const Color accent = Color(0xFFB8C5D1); // 莫蘭迪灰藍

  // 背景色彩
  static const Color background = Color(0xFFF8FAFC); // 莫蘭迪淺灰藍
  static const Color surface = Color(0xFFF8FAFC); // 莫蘭迪淺灰藍

  // 文字色彩
  static const Color onPrimary = Color(0xFFF8FAFC); // 淺色文字
  static const Color onSecondary = Color(0xFF2D3748); // 深色文字
  static const Color onBackground = Color(0xFF2D3748); // 深色文字
  static const Color onSurface = Color(0xFF2D3748); // 深色文字

  // 狀態色彩
  static const Color error = Color(0xFFB56576); // 莫蘭迪粉紅
  static const Color onError = Color(0xFFF8FAFC); // 淺色文字
  static const Color success = Color(0xFF8FBC8F); // 莫蘭迪綠
  static const Color warning = Color(0xFFD4A574); // 莫蘭迪橙

  // 陰影色彩
  static const Color shadow = Color(0xFF5A6B7A); // 深灰藍陰影

  // 透明度變體
  static Color primaryWithOpacity(double opacity) =>
      primary.withOpacity(opacity);
  static Color secondaryWithOpacity(double opacity) =>
      secondary.withOpacity(opacity);
  static Color backgroundWithOpacity(double opacity) =>
      background.withOpacity(opacity);
}
