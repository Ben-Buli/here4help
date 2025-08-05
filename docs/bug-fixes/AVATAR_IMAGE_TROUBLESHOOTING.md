# 頭像圖片讀取問題診斷與解決方案

## 問題描述

當登入 `michael@test.com` 帳號時，無法正確讀取大頭貼圖片。

## 可能的原因

### 1. 圖片路徑問題
- 資料庫中的 `avatar_url` 可能是相對路徑
- Flutter 無法正確解析相對路徑
- 專案不在 MAMP 目錄下，路徑配置不正確

### 2. 環境配置問題
- 開發環境和生產環境的圖片路徑處理方式不同
- MAMP 配置與專案路徑不匹配

### 3. 圖片檔案問題
- 圖片檔案不存在或路徑錯誤
- 檔案權限問題

## 解決方案

### 1. 創建圖片處理工具 (`lib/utils/image_helper.dart`)

```dart
class ImageHelper {
  /// 處理用戶頭像圖片路徑
  static ImageProvider? getAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }

    // 如果是完整的 HTTP URL，直接使用 NetworkImage
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return NetworkImage(avatarUrl);
    }

    // 如果是本地資源路徑（以 assets/ 開頭）
    if (avatarUrl.startsWith('assets/')) {
      return AssetImage(avatarUrl);
    }

    // 如果是相對路徑，根據環境構建完整 URL
    String fullUrl = EnvironmentConfig.getFullImageUrl(avatarUrl);
    return NetworkImage(fullUrl);
  }
}
```

### 2. 環境配置工具 (`lib/config/environment_config.dart`)

```dart
class EnvironmentConfig {
  /// 圖片基礎 URL
  static String get imageBaseUrl {
    if (isDevelopment) {
      return 'http://localhost:8888/here4help';
    } else if (isProduction) {
      return 'https://hero4help.demofhs.com';
    }
  }

  /// 獲取完整的圖片 URL
  static String getFullImageUrl(String? relativePath) {
    // 處理相對路徑，構建完整 URL
  }
}
```

### 3. 調試工具 (`lib/utils/debug_helper.dart`)

```dart
class DebugHelper {
  /// 診斷用戶頭像路徑問題
  static void diagnoseAvatarPath(String? avatarUrl, String userEmail) {
    // 打印詳細的診斷信息
  }
}
```

## 使用方式

### 1. 在 UI 中使用新的圖片處理工具

```dart
CircleAvatar(
  radius: 30,
  backgroundImage: ImageHelper.getAvatarImage(user?.avatar_url),
  onBackgroundImageError: (exception, stackTrace) {
    debugPrint('頭像載入錯誤: $exception');
  },
  child: user?.avatar_url == null || user!.avatar_url.isEmpty
      ? const Icon(Icons.person)
      : null,
),
```

### 2. 調試模式

登入時會自動打印診斷信息：
```
🔍 診斷用戶頭像路徑問題
📧 用戶郵箱: michael@test.com
🖼️ 原始頭像路徑: [路徑]
🌍 當前環境: development
🔗 圖片基礎 URL: http://localhost:8888/here4help
```

## 檢查步驟

### 1. 檢查資料庫中的頭像路徑

```sql
SELECT id, name, email, avatar_url FROM users WHERE email = 'michael@test.com';
```

### 2. 檢查圖片檔案是否存在

- 如果路徑是 `assets/images/avatar/avatar-1.png`，確認檔案存在
- 如果路徑是相對路徑，確認在 MAMP 目錄下存在

### 3. 檢查網路請求

在瀏覽器中測試圖片 URL：
```
http://localhost:8888/here4help/[相對路徑]
```

### 4. 檢查 Flutter 控制台輸出

查看是否有圖片載入錯誤的日誌。

## 常見問題

### Q: 圖片路徑是 `avatar-1.png`，怎麼辦？
A: 系統會自動構建完整 URL：`http://localhost:8888/here4help/avatar-1.png`

### Q: 圖片路徑是 `assets/images/avatar/avatar-1.png`，怎麼辦？
A: 系統會識別為本地資源，直接使用 `AssetImage`

### Q: 圖片路徑是完整 URL，怎麼辦？
A: 系統會直接使用 `NetworkImage`

## 環境變數配置

可以在運行時指定環境：

```bash
# 開發環境
flutter run --dart-define=ENVIRONMENT=development

# 生產環境
flutter run --dart-define=ENVIRONMENT=production
```

## 下一步

1. 測試登入 `michael@test.com` 帳號
2. 查看控制台輸出的診斷信息
3. 根據診斷信息調整圖片路徑或配置
4. 如果仍有問題，檢查 MAMP 配置和檔案權限 