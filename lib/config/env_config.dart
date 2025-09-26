import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// 環境配置管理器
/// 使用 flutter_dotenv 來管理環境變數，替代 JSON 配置文件
class EnvConfig {
  static bool _isLoaded = false;

  /// 載入環境配置
  static Future<void> load({String? envFile}) async {
    if (_isLoaded) return;

    try {
      // 根據當前環境載入對應的 .env 文件
      envFile ??= _getEnvFileName();
      await dotenv.load(fileName: envFile);
      _isLoaded = true;

      if (kDebugMode) {
        debugPrint('✅ 環境配置載入成功: $envFile');
      }
    } catch (e) {
      // Web 平台使用 dart-define 或預設值
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('⚠️ Web 環境配置載入失敗，使用 dart-define 或預設值');
        }
        _isLoaded = true;
        return;
      } else {
        // 非 Web 平台嘗試載入根目錄的 .env
        try {
          await dotenv.load(fileName: '.env');
          _isLoaded = true;

          if (kDebugMode) {
            debugPrint('✅ 使用預設環境配置: .env');
          }
          return;
        } catch (fallbackError) {
          if (kDebugMode) {
            debugPrint('⚠️ 環境配置載入失敗，使用預設值');
          }
        }
      }

      // 如果所有載入都失敗，設置為已載入但使用空配置
      _isLoaded = true;

      if (kDebugMode) {
        debugPrint('⚠️ 無法載入任何環境配置文件，使用預設值');
        debugPrint('   嘗試的文件: $envFile');
        debugPrint('   錯誤: $e');
      }
    }
  }

  /// 根據建置模式決定環境文件名稱
  static String _getEnvFileName() {
    const String environment =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

    // Web 平台需要使用 assets/env/ 路徑
    const String prefix = kIsWeb ? 'assets/env/' : '';

    switch (environment) {
      case 'production':
        return '$prefix.env.production';
      case 'testflight':
        return '$prefix.env.testflight';
      case 'staging':
        return '$prefix.env.staging';
      case 'android_emulator':
        return '$prefix.env.android_emulator';
      case 'ios_simulator':
        return '$prefix.env.ios_simulator';
      case 'development':
      default:
        return '$prefix.env.development';
    }
  }

  /// 檢查是否已載入
  static bool get isLoaded => _isLoaded;

  /// 獲取環境變數值
  static String get(String key, {String defaultValue = ''}) {
    // Web 平台優先使用 dart-define
    if (kIsWeb) {
      const value = String.fromEnvironment('API_BASE_URL');
      if (key == 'API_BASE_URL' && value.isNotEmpty) {
        return value;
      }
      // 其他環境變數也可以用類似方式處理
    }

    if (!_isLoaded) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ Environment not loaded when accessing key: $key, using default: $defaultValue');
      }
      return defaultValue;
    }

    // 直接從 dotenv.env 獲取值
    final value = dotenv.env[key] ?? defaultValue;

    if (kDebugMode &&
        value == defaultValue &&
        defaultValue.isNotEmpty &&
        dotenv.env[key] == null) {
      debugPrint('⚠️ Using default value for $key: $defaultValue');
    }

    return value;
  }

  /// 獲取布林值環境變數
  static bool getBool(String key, {bool defaultValue = false}) {
    final value = get(key).toLowerCase();
    if (value.isEmpty) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes';
  }

  /// 獲取整數環境變數
  static int getInt(String key, {int defaultValue = 0}) {
    final value = get(key);
    if (value.isEmpty) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  // =============================================================================
  // API 配置
  // =============================================================================

  /// API Origin
  static String get apiOrigin =>
      get('API_ORIGIN', defaultValue: 'http://localhost:8888');

  /// API 前綴
  static String get apiPrefix =>
      get('API_PREFIX', defaultValue: '/here4help/backend/api');

  /// API 基礎 URL
  static String get apiBaseUrl => get('API_BASE_URL',
      defaultValue: 'http://localhost:8888/here4help/backend');

  /// 圖片基礎 URL
  static String get imageBaseUrl =>
      get('IMAGE_BASE_URL', defaultValue: 'http://127.0.0.1:8888/here4help');

  /// Socket URL
  static String get socketUrl =>
      get('SOCKET_URL', defaultValue: 'http://127.0.0.1:3001');

  // =============================================================================
  // OAuth 配置（僅公開資訊）
  // =============================================================================

  /// Google Client ID（公開資訊）
  static String get googleClientId => get('GOOGLE_CLIENT_ID');

  /// Facebook App ID（公開資訊）
  static String get facebookAppId => get('FACEBOOK_APP_ID');

  /// Apple Service ID
  static String get appleServiceId => get('APPLE_SERVICE_ID', defaultValue: '');

  /// Google 重導向 URI
  static String get googleRedirectUri => get('GOOGLE_REDIRECT_URI');

  /// Facebook 重導向 URI
  static String get facebookRedirectUri => get('FACEBOOK_REDIRECT_URI');

  /// Apple 重導向 URI
  static String get appleRedirectUri => get('APPLE_REDIRECT_URI');

  // =============================================================================
  // 功能開關
  // =============================================================================

  /// 第三方登入功能
  static bool get enableThirdPartyAuth =>
      getBool('FEATURE_THIRD_PARTY_AUTH', defaultValue: true);

  /// 聊天功能
  static bool get enableChat => getBool('FEATURE_CHAT', defaultValue: true);

  /// 任務功能
  static bool get enableTasks => getBool('FEATURE_TASKS', defaultValue: true);

  /// 支付功能
  static bool get enablePayments =>
      getBool('FEATURE_PAYMENTS', defaultValue: false);

  // =============================================================================
  // 應用程式配置
  // =============================================================================

  /// 應用環境
  static String get appEnvironment =>
      get('APP_ENVIRONMENT', defaultValue: 'development');

  /// 除錯模式
  static bool get isDebugMode => getBool('APP_DEBUG', defaultValue: true);

  /// 是否為開發環境
  static bool get isDevelopment => appEnvironment == 'development';

  /// 是否為測試環境
  static bool get isStaging => appEnvironment == 'staging';

  /// 是否為正式環境
  static bool get isProduction => appEnvironment == 'production';

  // =============================================================================
  // 工具方法
  // =============================================================================

  /// 獲取完整的 API URL
  static String getApiUrl(String endpoint) {
    return '$apiBaseUrl$apiPrefix$endpoint';
  }

  /// 獲取完整的圖片 URL
  static String getImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path; // 已經是完整 URL
    }
    return '$imageBaseUrl/$path';
  }

  /// 列印所有環境配置（僅在除錯模式）
  static void printConfig() {
    if (!isDebugMode) return;

    debugPrint('=== Environment Configuration (.env) ===');
    debugPrint('Loaded: $_isLoaded');
    debugPrint('Environment: $appEnvironment');
    debugPrint('Debug Mode: $isDebugMode');
    debugPrint('Platform: ${kIsWeb ? "Web" : "Native"}');
    debugPrint('API Configuration:');
    debugPrint('  - API Origin: $apiOrigin');
    debugPrint('  - API Base URL: $apiBaseUrl');
    debugPrint(
        '  - API Prefix: ${get("API_PREFIX", defaultValue: "/here4help/backend/api")}');
    debugPrint('  - Socket URL: $socketUrl');
    debugPrint('  - Image Base URL: $imageBaseUrl');
    debugPrint('Raw Environment Variables:');
    debugPrint('  - API_PREFIX raw: ${dotenv.env['API_PREFIX'] ?? "null"}');
    debugPrint('  - API_ORIGIN raw: ${dotenv.env['API_ORIGIN'] ?? "null"}');
    debugPrint('  - API_BASE_URL raw: ${dotenv.env['API_BASE_URL'] ?? "null"}');
    debugPrint('OAuth Configuration:');
    debugPrint(
        '  - Google Client ID: ${googleClientId.isEmpty ? "未配置" : "已配置 (${googleClientId.length > 10 ? "${googleClientId.substring(0, 10)}..." : googleClientId})"}');
    debugPrint(
        '  - Facebook App ID: ${facebookAppId.isEmpty ? "未配置" : "已配置 ($facebookAppId)"}');
    debugPrint(
        '  - Apple Service ID: ${appleServiceId.isEmpty ? "未配置" : "已配置"}');
    debugPrint('Features:');
    debugPrint('  - Third Party Auth: $enableThirdPartyAuth');
    debugPrint('  - Chat: $enableChat');
    debugPrint('  - Tasks: $enableTasks');
    debugPrint('  - Payments: $enablePayments');
    debugPrint('====================================');
  }
}
