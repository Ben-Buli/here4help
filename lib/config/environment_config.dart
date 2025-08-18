import 'package:flutter/foundation.dart';

class EnvironmentConfig {
  /// 當前環境
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// 是否為開發環境
  static bool get isDevelopment => _environment == 'development';

  /// 是否為生產環境
  static bool get isProduction => _environment == 'production';

  /// 是否為測試環境
  static bool get isTest => _environment == 'test';

  /// 獲取當前環境名稱
  static String get environment => _environment;

  /// 圖片基礎 URL
  static String get imageBaseUrl {
    if (isDevelopment) {
      return const String.fromEnvironment('IMAGE_BASE_URL_DEV',
          defaultValue: 'http://localhost:8888/here4help');
    } else if (isProduction) {
      return const String.fromEnvironment('IMAGE_BASE_URL_PROD',
          defaultValue: 'https://hero4help.demofhs.com');
    } else {
      return const String.fromEnvironment('IMAGE_BASE_URL_DEV',
          defaultValue: 'http://localhost:8888/here4help');
    }
  }

  /// 獲取完整的圖片 URL
  static String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return '';
    }

    // 如果已經是完整 URL，直接返回
    if (relativePath.startsWith('http://') ||
        relativePath.startsWith('https://')) {
      return relativePath;
    }

    // 如果是本地資源，直接返回
    if (relativePath.startsWith('assets/')) {
      return relativePath;
    }

    // 移除開頭的斜線
    if (relativePath.startsWith('/')) {
      relativePath = relativePath.substring(1);
    }

    return '$imageBaseUrl/$relativePath';
  }

  /// 調試信息
  static void printEnvironmentInfo() {
    if (kDebugMode) {
      print('🌍 當前環境: $_environment');
      print('🔗 圖片基礎 URL: $imageBaseUrl');
      print('📱 是否為開發環境: $isDevelopment');
    }
  }
}
