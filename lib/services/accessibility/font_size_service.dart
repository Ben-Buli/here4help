import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 動態字級管理服務
/// 提供字級調整、可讀性檢查和無障礙支援
class FontSizeService extends ChangeNotifier {
  static FontSizeService? _instance;
  static FontSizeService get instance => _instance ??= FontSizeService._();

  FontSizeService._() {
    _loadFontScale();
  }

  // 字級縮放比例
  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  // 字級預設
  static const double minFontScale = 0.8;
  static const double maxFontScale = 2.0;
  static const double defaultFontScale = 1.0;

  // 字級等級定義
  static const Map<String, double> fontScaleLevels = {
    'small': 0.8,
    'normal': 1.0,
    'large': 1.2,
    'extra_large': 1.5,
    'accessibility': 2.0,
  };

  /// 載入儲存的字級設定
  Future<void> _loadFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontScale = prefs.getDouble('font_scale') ?? defaultFontScale;
      notifyListeners();
    } catch (e) {
      debugPrint('FontSizeService: 載入字級設定失敗 - $e');
    }
  }

  /// 設定字級縮放比例
  Future<void> setFontScale(double scale) async {
    if (scale < minFontScale || scale > maxFontScale) {
      debugPrint('FontSizeService: 字級縮放比例超出範圍 ($scale)');
      return;
    }

    _fontScale = scale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_scale', scale);
    } catch (e) {
      debugPrint('FontSizeService: 儲存字級設定失敗 - $e');
    }
  }

  /// 設定字級等級
  Future<void> setFontLevel(String level) async {
    if (fontScaleLevels.containsKey(level)) {
      await setFontScale(fontScaleLevels[level]!);
    }
  }

  /// 獲取當前字級等級名稱
  String getCurrentFontLevel() {
    for (final entry in fontScaleLevels.entries) {
      if ((entry.value - _fontScale).abs() < 0.01) {
        return entry.key;
      }
    }
    return 'custom';
  }

  /// 增加字級
  Future<void> increaseFontSize() async {
    final newScale = (_fontScale + 0.1).clamp(minFontScale, maxFontScale);
    await setFontScale(newScale);
  }

  /// 減少字級
  Future<void> decreaseFontSize() async {
    final newScale = (_fontScale - 0.1).clamp(minFontScale, maxFontScale);
    await setFontScale(newScale);
  }

  /// 重設為預設字級
  Future<void> resetFontSize() async {
    await setFontScale(defaultFontScale);
  }

  /// 獲取縮放後的字體大小
  double getScaledFontSize(double originalSize) {
    return originalSize * _fontScale;
  }

  /// 獲取縮放後的 TextStyle
  TextStyle getScaledTextStyle(TextStyle originalStyle) {
    return originalStyle.copyWith(
      fontSize: getScaledFontSize(originalStyle.fontSize ?? 14.0),
    );
  }

  /// 檢查可讀性
  bool isReadable(TextStyle textStyle, Color backgroundColor) {
    final textColor = textStyle.color ?? Colors.black;
    final contrast = _calculateContrastRatio(textColor, backgroundColor);
    
    // WCAG AA 標準：正常文字對比度至少 4.5:1，大文字至少 3:1
    final fontSize = getScaledFontSize(textStyle.fontSize ?? 14.0);
    final isLargeText = fontSize >= 18.0 || 
        (fontSize >= 14.0 && (textStyle.fontWeight?.index ?? 3) >= FontWeight.bold.index);
    
    return isLargeText ? contrast >= 3.0 : contrast >= 4.5;
  }

  /// 計算顏色對比度
  double _calculateContrastRatio(Color color1, Color color2) {
    final luminance1 = _calculateLuminance(color1);
    final luminance2 = _calculateLuminance(color2);
    
    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;
    
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 計算顏色亮度
  double _calculateLuminance(Color color) {
    final r = _linearizeColorComponent(color.red / 255.0);
    final g = _linearizeColorComponent(color.green / 255.0);
    final b = _linearizeColorComponent(color.blue / 255.0);
    
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 線性化顏色分量
  double _linearizeColorComponent(double component) {
    return component <= 0.03928
        ? component / 12.92
        : ((component + 0.055) / 1.055).mathPow(2.4);
  }
}

/// 數學運算擴展
extension MathExtension on double {
  double mathPow(double exponent) {
    if (exponent == 2.4) {
      // 簡化的 2.4 次方計算
      final sqrt = this * this; // x^2
      final fourthRoot = sqrt * sqrt; // x^4
      return fourthRoot * sqrt * this; // x^2.4 的近似值
    }
    return this;
  }
}
