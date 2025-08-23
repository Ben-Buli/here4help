import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'avatar_url_manager.dart';

class ImageHelper {
  /// 處理用戶頭像圖片路徑
  static ImageProvider getAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      debugPrint('⚠️ avatarUrl 為空，返回預設頭像');
      return getDefaultAvatar();
    }

    // 調試頭像路徑解析（僅在調試模式下）
    if (kDebugMode) {
      AvatarUrlManager.debugAvatarPath(avatarUrl);
    }

    // 使用 AvatarUrlManager 解析頭像路徑
    final resolvedUrl = AvatarUrlManager.resolveAvatarUrl(avatarUrl);

    // 根據路徑類型返回對應的 ImageProvider
    if (AvatarUrlManager.isLocalAsset(resolvedUrl)) {
      return AssetImage(resolvedUrl);
    } else if (AvatarUrlManager.isNetworkImage(resolvedUrl)) {
      return NetworkImage(resolvedUrl);
    } else {
      // 回退到預設頭像
      return getDefaultAvatar();
    }
  }

  /// 檢查圖片是否為本地資源
  static bool isLocalAsset(String? imagePath) {
    return AvatarUrlManager.isLocalAsset(imagePath);
  }

  /// 檢查圖片是否為網路圖片
  static bool isNetworkImage(String? imagePath) {
    return AvatarUrlManager.isNetworkImage(imagePath);
  }

  /// 獲取預設頭像
  static ImageProvider getDefaultAvatar() {
    final defaultPath = AvatarUrlManager.getDefaultAvatarPath();
    return AssetImage(defaultPath);
  }

  /// 處理圖片錯誤的回調
  static void handleImageError(
      BuildContext context, Object error, StackTrace? stackTrace) {
    debugPrint('圖片載入錯誤: $error');
    // 可以在這裡添加錯誤處理邏輯，比如顯示預設圖片
  }
}
