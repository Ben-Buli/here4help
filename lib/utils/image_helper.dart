import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import 'path_mapper.dart';

class ImageHelper {
  /// 處理用戶頭像圖片路徑
  static ImageProvider getAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      debugPrint('⚠️ avatarUrl 為空，返回默認頭像');
      return getDefaultAvatar();
    }

    // 調試路徑映射（僅在調試模式下）
    if (kDebugMode) {
      PathMapper.debugPathMapping(avatarUrl);
    }

    // 如果是完整的 HTTP URL，直接使用 NetworkImage
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return NetworkImage(avatarUrl);
    }

    // 如果是本地資源路徑（以 assets/ 開頭），直接使用 AssetImage
    if (avatarUrl.startsWith('assets/')) {
      return AssetImage(avatarUrl);
    }

    // 使用 PathMapper 處理其他路徑
    String mappedUrl = PathMapper.mapDatabasePathToUrl(avatarUrl);

    // 如果映射後仍然是 assets 路徑，使用 AssetImage
    if (mappedUrl.startsWith('assets/')) {
      return AssetImage(mappedUrl);
    }

    // 否則使用 NetworkImage
    return NetworkImage(mappedUrl);
  }

  /// 檢查圖片是否為本地資源
  static bool isLocalAsset(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;
    return imagePath.startsWith('assets/');
  }

  /// 檢查圖片是否為網路圖片
  static bool isNetworkImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;
    return imagePath.startsWith('http://') || imagePath.startsWith('https://');
  }

  /// 獲取預設頭像
  static ImageProvider getDefaultAvatar() {
    return const AssetImage('assets/images/avatar/default.png');
  }

  /// 處理圖片錯誤的回調
  static void handleImageError(
      BuildContext context, Object error, StackTrace? stackTrace) {
    debugPrint('圖片載入錯誤: $error');
    // 可以在這裡添加錯誤處理邏輯，比如顯示預設圖片
  }
}
