# 頭像 URL 管理系統

## 概述

新的頭像 URL 管理系統統一處理不同來源的頭像路徑格式，解決了舊系統中路徑格式不一致的問題。

## 支援的頭像格式

### 1. Flutter 本地資源
```
assets/images/avatar/avatar-1.png
assets/images/avatar/avatar-4.png
assets/images/avatar/default.png
```

### 2. 後端上傳的頭像
```
/backend/uploads/avatars/compressed_avatar_2_1755973715.png
backend/uploads/avatars/avatar_123_1234567890.jpg
/backend/uploads/avatars/compressed_avatar_5_1755973800.webp
```

### 3. 完整的 HTTP URL
```
https://example.com/avatar.jpg
http://localhost:8888/here4help/backend/uploads/avatars/avatar.png
```

## 核心組件

### AvatarUrlManager
統一的頭像 URL 管理器，提供以下功能：

- **路徑類型判斷**: `getPathType()`
- **URL 解析**: `resolveAvatarUrl()`
- **資料庫格式化**: `formatForDatabase()`
- **舊路徑遷移**: `migrateOldAvatarPath()`

### ImageHelper
更新後的圖片助手，使用 `AvatarUrlManager` 處理頭像：

- **統一圖片載入**: `getAvatarImage()`
- **類型檢查**: `isLocalAsset()`, `isNetworkImage()`
- **預設頭像**: `getDefaultAvatar()`

## 使用方式

### 基本使用
```dart
// 獲取頭像 ImageProvider
final imageProvider = ImageHelper.getAvatarImage(user.avatarUrl);

// 在 Widget 中使用
Image(
  image: imageProvider,
  width: 100,
  height: 100,
  fit: BoxFit.cover,
)
```

### 路徑解析
```dart
// 解析任意格式的頭像路徑
final resolvedUrl = AvatarUrlManager.resolveAvatarUrl(avatarUrl);

// 檢查路徑類型
final pathType = AvatarUrlManager.getPathType(avatarUrl);
```

### 資料庫儲存
```dart
// 格式化 URL 用於資料庫儲存
final dbFormat = AvatarUrlManager.formatForDatabase(fullUrl);
```

## 路徑轉換邏輯

### 本地資源 → 直接使用
```
assets/images/avatar/avatar-1.png
↓
AssetImage('assets/images/avatar/avatar-1.png')
```

### 後端上傳 → 轉換為完整 URL
```
/backend/uploads/avatars/avatar.jpg
↓
http://localhost:8888/here4help/backend/uploads/avatars/avatar.jpg
↓
NetworkImage('http://localhost:8888/here4help/backend/uploads/avatars/avatar.jpg')
```

### HTTP URL → 直接使用
```
https://example.com/avatar.jpg
↓
NetworkImage('https://example.com/avatar.jpg')
```

### 無效路徑 → 預設頭像
```
null, '', 'invalid/path'
↓
assets/images/avatar/default.png
↓
AssetImage('assets/images/avatar/default.png')
```

## 環境配置

### 開發環境 (Debug)
- 基礎 URL: `http://localhost:8888/here4help`
- 啟用調試日誌

### 生產環境 (Release)
- 基礎 URL: 從 `AppConfig.apiBaseUrl` 獲取
- 關閉調試日誌

## 遷移指南

### 從舊系統遷移
```dart
// 舊的測試圖片路徑
'test_images/avatar/avatar-1.png'
↓
'assets/images/avatar/avatar-1.png'

// 舊的上傳路徑
'uploads/avatars/old_avatar.jpg'
↓
'/backend/uploads/avatars/old_avatar.jpg'
```

### 資料庫更新
如果需要批量更新資料庫中的頭像路徑：

```sql
-- 更新舊的測試圖片路徑
UPDATE users 
SET avatar_url = REPLACE(avatar_url, 'test_images/avatar/', 'assets/images/avatar/') 
WHERE avatar_url LIKE 'test_images/avatar/%';

-- 更新舊的上傳路徑
UPDATE users 
SET avatar_url = CONCAT('/backend', avatar_url) 
WHERE avatar_url LIKE 'uploads/avatars/%';
```

## 測試

使用 `AvatarUrlTest.runAllTests()` 執行完整測試：

```dart
import 'package:here4help/utils/avatar_url_test.dart';

// 在調試模式下執行測試
AvatarUrlTest.runAllTests();
```

## 注意事項

1. **路徑一致性**: 所有頭像路徑都通過 `AvatarUrlManager` 處理
2. **環境適應**: 自動根據 Debug/Release 模式選擇基礎 URL
3. **向後兼容**: 支援舊格式路徑的自動遷移
4. **錯誤處理**: 無效路徑自動回退到預設頭像
5. **性能優化**: 路徑解析結果可以快取以提高性能

## 相關文件

- `lib/utils/avatar_url_manager.dart` - 核心管理器
- `lib/utils/image_helper.dart` - 圖片助手
- `lib/utils/avatar_url_test.dart` - 測試工具
- `lib/widgets/avatar_upload_widget.dart` - 頭像上傳組件
- `backend/api/account/avatar.php` - 後端頭像 API
