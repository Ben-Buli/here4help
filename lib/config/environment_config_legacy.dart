/// EnvironmentConfig 向後相容性包裝器
/// 這個文件提供 EnvironmentConfig 的所有原有功能，但內部使用新的 EnvConfig 系統
///
/// 用於無縫遷移，不需要修改現有的程式碼

import 'package:here4help/config/env_config.dart';

/// EnvironmentConfig 舊接口的向後相容實現
/// 內部使用新的 EnvConfig 系統
class EnvironmentConfig {
  /// 初始化配置（向後相容）
  static Future<void> initialize() async {
    await EnvConfig.load();
  }

  /// 當前環境
  static String get environment => EnvConfig.appEnvironment;

  /// 除錯模式
  static bool get debugMode => EnvConfig.isDebugMode;

  // =============================================================================
  // API 配置（向後相容）
  // =============================================================================

  /// API Origin
  static String get apiOrigin => EnvConfig.apiOrigin;

  /// API 前綴
  static String get apiPrefix =>
      EnvConfig.get('API_PREFIX', defaultValue: '/here4help/backend/api');

  /// API 基礎 URL
  static String get apiBaseUrl => EnvConfig.apiBaseUrl;

  /// Socket URL
  static String get socketUrl => EnvConfig.socketUrl;

  /// 圖片基礎 URL
  static String get imageBaseUrl => EnvConfig.imageBaseUrl;

  // =============================================================================
  // OAuth 配置（向後相容）
  // =============================================================================

  /// Google Client ID
  static String get googleClientId => EnvConfig.googleClientId;

  /// Google Android Client ID
  static String get googleAndroidClientId =>
      EnvConfig.get('GOOGLE_ANDROID_CLIENT_ID');

  /// Google iOS Client ID
  static String get googleIosClientId => EnvConfig.get('GOOGLE_IOS_CLIENT_ID');

  /// Google Web Client Secret
  static String get googleWebClientSecret =>
      EnvConfig.get('GOOGLE_WEB_CLIENT_SECRET');

  /// Facebook App ID
  static String get facebookAppId => EnvConfig.facebookAppId;

  /// Facebook App Secret
  static String get facebookAppSecret => EnvConfig.get('FACEBOOK_APP_SECRET');

  /// Apple Service ID
  static String get appleServiceId => EnvConfig.appleServiceId;

  /// Apple Key ID
  static String get appleKeyId => EnvConfig.get('APPLE_KEY_ID');

  /// Apple Team ID
  static String get appleTeamId => EnvConfig.get('APPLE_TEAM_ID');

  // =============================================================================
  // OAuth Redirect URIs（向後相容）
  // =============================================================================

  /// Google Redirect URI
  static String get googleRedirectUri => EnvConfig.googleRedirectUri;

  /// Facebook Redirect URI
  static String get facebookRedirectUri => EnvConfig.facebookRedirectUri;

  /// Apple Redirect URI
  static String get appleRedirectUri => EnvConfig.appleRedirectUri;

  // =============================================================================
  // 環境檢測（向後相容）
  // =============================================================================

  /// 是否為開發環境
  static bool get isDevelopment => EnvConfig.isDevelopment;

  /// 是否為正式環境
  static bool get isProduction => EnvConfig.isProduction;

  // =============================================================================
  // 工具方法（向後相容）
  // =============================================================================

  /// 獲取完整的圖片 URL
  static String getFullImageUrl(String path) {
    return EnvConfig.getImageUrl(path);
  }

  /// 列印環境資訊
  static void printEnvironmentInfo() {
    EnvConfig.printConfig();
  }

  /// API URL 組裝
  static String api(String path) {
    return EnvConfig.getApiUrl(path);
  }
}
