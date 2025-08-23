# 跨平台圖片上傳服務

## 概述

`CrossPlatformImageService` 是一個統一的圖片處理服務，解決了 Flutter Web 和移動平台在圖片上傳方面的兼容性問題。

## 主要特性

### ✅ 跨平台兼容
- **Web 平台**: 使用 `Uint8List` 處理圖片數據
- **iOS/Android**: 支援檔案路徑和位元組數據
- **統一 API**: 所有平台使用相同的接口

### ✅ 內建驗證
- 檔案大小限制
- 檔案格式驗證
- 圖片尺寸限制
- 檔案名稱安全檢查

### ✅ 預設配置
- **頭像**: 5MB, JPEG/PNG/WebP, 1024x1024
- **聊天附件**: 10MB, JPEG/PNG/GIF/WebP
- **學生證**: 10MB, JPEG/PNG, 4096x4096

## 使用方法

### 1. 基本圖片選擇

```dart
final imageService = CrossPlatformImageService();

// 從相機選擇
final cameraImage = await imageService.pickFromCamera(
  config: ImageValidationConfig.avatar,
);

// 從相簿選擇
final galleryImage = await imageService.pickFromGallery(
  config: ImageValidationConfig.chat,
);
```

### 2. 圖片上傳

```dart
if (image != null) {
  final result = await imageService.uploadImage(
    image: image,
    uploadUrl: 'https://api.example.com/upload',
    token: 'your-auth-token',
    fieldName: 'avatar',
    additionalFields: {
      'user_id': '123',
      'context': 'profile',
    },
  );
  
  if (result['success'] == true) {
    print('上傳成功: ${result['data']['url']}');
  }
}
```

### 3. 圖片預覽

```dart
// 創建 ImageProvider 用於 Widget 顯示
Widget buildImagePreview(ImageResult image) {
  return Image(
    image: imageService.createImageProvider(image),
    width: 200,
    height: 200,
    fit: BoxFit.cover,
  );
}
```

### 4. 自定義驗證配置

```dart
const customConfig = ImageValidationConfig(
  maxSizeBytes: 2 * 1024 * 1024, // 2MB
  allowedTypes: ['image/jpeg', 'image/png'],
  maxWidth: 800,
  maxHeight: 600,
);

final image = await imageService.pickFromGallery(config: customConfig);
```

## API 整合範例

### ProfileApi 整合

```dart
class ProfileApi {
  static Future<Map<String, dynamic>> uploadAvatar(ImageResult image) async {
    final imageService = CrossPlatformImageService();
    return await imageService.uploadImage(
      image: image,
      uploadUrl: '${AppConfig.apiBaseUrl}/api/account/avatar.php',
      token: await AuthService.getToken(),
      fieldName: 'avatar',
    );
  }
}
```

### ChatService 整合

```dart
class ChatService {
  Future<Map<String, dynamic>> pickAndUploadFromGallery(String roomId) async {
    final imageService = CrossPlatformImageService();
    final image = await imageService.pickFromGallery(
      config: ImageValidationConfig.chat,
    );
    
    if (image == null) throw Exception('未選擇圖片');
    
    return await imageService.uploadImage(
      image: image,
      uploadUrl: AppConfig.chatUploadAttachmentUrl,
      token: await AuthService.getToken(),
      fieldName: 'file',
      additionalFields: {'room_id': roomId},
    );
  }
}
```

## 錯誤處理

```dart
try {
  final image = await imageService.pickFromGallery();
  if (image != null) {
    await imageService.uploadImage(/* ... */);
  }
} catch (e) {
  if (e.toString().contains('圖片大小超過限制')) {
    // 處理檔案過大
  } else if (e.toString().contains('不支援的圖片格式')) {
    // 處理格式錯誤
  } else {
    // 處理其他錯誤
  }
}
```

## 後端兼容性

### 檔案大小限制
- 頭像: 5MB
- 聊天附件: 10MB  
- 學生證: 10MB

### 支援格式
- JPEG/JPG
- PNG
- GIF (聊天附件)
- WebP (頭像、聊天附件)

### 後端驗證
後端使用 `MediaValidator.php` 進行二次驗證：
- MIME 類型檢查
- 檔案大小限制
- 圖片尺寸驗證
- 安全性掃描

## 遷移指南

### 舊代碼 (不跨平台)
```dart
// ❌ 不支援 Web
final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
if (image != null) {
  final request = http.MultipartRequest('POST', uri);
  request.files.add(await http.MultipartFile.fromPath('file', image.path));
}
```

### 新代碼 (跨平台)
```dart
// ✅ 支援所有平台
final imageService = CrossPlatformImageService();
final image = await imageService.pickFromGallery();
if (image != null) {
  await imageService.uploadImage(
    image: image,
    uploadUrl: uploadUrl,
    token: token,
    fieldName: 'file',
  );
}
```

## 注意事項

1. **Web 平台限制**: 不支援檔案路徑操作，統一使用位元組數據
2. **記憶體管理**: 大圖片會佔用較多記憶體，建議適當壓縮
3. **網路超時**: 大檔案上傳可能需要調整超時設定
4. **權限處理**: 相機和相簿訪問需要適當的權限配置

## 相關文件

- [後端 MediaValidator.php](../../backend/utils/MediaValidator.php)
- [頭像上傳 API](../../backend/api/account/avatar.php)
- [聊天附件 API](../../backend/api/chat/upload_attachment.php)
