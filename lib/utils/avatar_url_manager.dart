import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';

/// 頭像路徑類型
enum AvatarPathType {
  /// Flutter 本地資源 (backend/uploads/avatars/avatar-1.png)
  localAsset,

  /// 後端上傳的頭像 (/backend/uploads/avatars/compressed_avatar_2_1755973715.png)
  backendUpload,

  /// 完整的 HTTP URL
  httpUrl,

  /// 無效或空路徑
  invalid,
}

/// 頭像 URL 管理器
/// 統一處理不同來源的頭像路徑格式
class AvatarUrlManager {
  /// 獲取當前環境的基礎 URL
  static String get _baseUrl => AppConfig.apiBaseUrl;

  /// 判斷頭像路徑類型
  static AvatarPathType getPathType(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return AvatarPathType.invalid;
    }

    // HTTP/HTTPS URL
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return AvatarPathType.httpUrl;
    }

    // Flutter 本地資源
    if (avatarUrl.startsWith('assets/')) {
      return AvatarPathType.localAsset;
    }

    // 後端上傳的頭像
    if (avatarUrl.startsWith('/backend/uploads/avatars/') ||
        avatarUrl.startsWith('backend/uploads/avatars/')) {
      return AvatarPathType.backendUpload;
    }

    return AvatarPathType.invalid;
  }

  /// 將頭像路徑轉換為可訪問的 URL
  static String resolveAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return getDefaultAvatarPath();
    }

    final pathType = getPathType(avatarUrl);

    switch (pathType) {
      case AvatarPathType.localAsset:
        // Flutter 本地資源，直接返回
        return avatarUrl;

      case AvatarPathType.httpUrl:
        // 完整 URL，直接返回
        return avatarUrl;

      case AvatarPathType.backendUpload:
        // 後端上傳的頭像，轉換為完整 URL
        String cleanPath = avatarUrl;
        if (cleanPath.startsWith('/')) {
          cleanPath = cleanPath.substring(1);
        }
        return '$_baseUrl/$cleanPath';

      case AvatarPathType.invalid:
        // 無效路徑，返回預設頭像
        return getDefaultAvatarPath();
    }
  }

  /// 獲取預設頭像路徑
  static String getDefaultAvatarPath() {
    return 'backend/uploads/avatars/avatar-1.png';
  }

  /// 獲取隨機預設頭像路徑（用於測試）
  static String getRandomDefaultAvatar() {
    final avatars = [
      'backend/uploads/avatars/avatar-1.png',
      'backend/uploads/avatars/avatar-2.png',
      'backend/uploads/avatars/avatar-3.png',
      'backend/uploads/avatars/avatar-4.png',
      'backend/uploads/avatars/avatar-5.png',
    ];

    final now = DateTime.now();
    final index = now.millisecond % avatars.length;
    return avatars[index];
  }

  /// 檢查頭像是否為本地資源
  static bool isLocalAsset(String? avatarUrl) {
    return getPathType(avatarUrl) == AvatarPathType.localAsset;
  }

  /// 檢查頭像是否為後端上傳
  static bool isBackendUpload(String? avatarUrl) {
    return getPathType(avatarUrl) == AvatarPathType.backendUpload;
  }

  /// 檢查頭像是否為網路圖片
  static bool isNetworkImage(String? avatarUrl) {
    final pathType = getPathType(avatarUrl);
    return pathType == AvatarPathType.httpUrl ||
        pathType == AvatarPathType.backendUpload;
  }

  /// 格式化頭像 URL 用於儲存到資料庫
  /// 將完整 URL 轉換為相對路徑格式
  static String formatForDatabase(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return '';
    }

    // 如果是本地資源，直接返回
    if (isLocalAsset(avatarUrl)) {
      return avatarUrl;
    }

    // 如果是完整的後端 URL，轉換為相對路徑
    if (avatarUrl.startsWith(_baseUrl)) {
      return avatarUrl.substring(_baseUrl.length);
    }

    // 如果已經是相對路徑，直接返回
    if (avatarUrl.startsWith('/backend/uploads/avatars/') ||
        avatarUrl.startsWith('backend/uploads/avatars/')) {
      return avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl';
    }

    // 其他情況直接返回
    return avatarUrl;
  }

  /// 調試信息：打印頭像路徑解析結果
  static void debugAvatarPath(String? avatarUrl) {
    if (!kDebugMode) return;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      debugPrint('🖼️ Avatar: null/empty -> 使用預設頭像');
      return;
    }

    final pathType = getPathType(avatarUrl);
    final resolvedUrl = resolveAvatarUrl(avatarUrl);

    // debugPrint('🖼️ Avatar 路徑解析:');
    // debugPrint('   原始路徑: $avatarUrl');
    // debugPrint('   路徑類型: ${pathType.name}');
    // debugPrint('   解析結果: $resolvedUrl');
    // debugPrint('   是否本地資源: ${isLocalAsset(avatarUrl)}');
    // debugPrint('   是否網路圖片: ${isNetworkImage(avatarUrl)}');
  }

  /// 遷移舊格式頭像路徑
  /// 用於處理從舊系統遷移過來的頭像路徑
  static String migrateOldAvatarPath(String? oldPath) {
    if (oldPath == null || oldPath.isEmpty) {
      return getDefaultAvatarPath();
    }

    // 如果是舊的測試頭像路徑，轉換為新的後端路徑
    if (oldPath.contains('test_images/avatar/')) {
      final fileName = oldPath.split('/').last;
      return 'backend/uploads/avatars/$fileName';
    }

    // 如果是舊的上傳路徑格式，保持不變
    if (oldPath.startsWith('/uploads/') || oldPath.startsWith('uploads/')) {
      return oldPath.replaceFirst(RegExp(r'^/?uploads/'), '/backend/uploads/');
    }

    // 其他情況使用現有邏輯
    return resolveAvatarUrl(oldPath);
  }
}
