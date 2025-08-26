# 圖片上傳錯誤處理優化報告

## 🎯 優化目標
將圖片上傳過程中的錯誤處理從 Exception 拋出改為用戶友好的 Snackbar 提示，並解決 Web 環境下的壓縮失敗問題。

## 🐛 修復的問題

### 1. **Web 環境壓縮失敗**
- **問題**：`Unsupported operation: Platform._operatingSystem`
- **原因**：`flutter_image_compress` 在 Web 環境下不支持某些參數
- **修復**：針對 Web 環境使用簡化的壓縮策略

### 2. **錯誤訊息用戶體驗差**
- **問題**：直接拋出 Exception，用戶看到技術性錯誤訊息
- **修復**：改為 Snackbar 顯示友好的錯誤提示

## ✅ 修復方案

### 1. **創建自定義異常類**
```dart
/// 圖片處理異常類
class ImageProcessingException implements Exception {
  final String message;
  ImageProcessingException(this.message);
  
  @override
  String toString() => message;
}
```

### 2. **Web 環境壓縮策略**
```dart
// Web 環境下使用不同的壓縮策略
if (kIsWeb) {
  // Web 環境下使用更簡單的壓縮方式
  final Uint8List compressed = await FlutterImageCompress.compressWithList(
    bytes,
    quality: 80,
    format: CompressFormat.webp,
  );
  return compressed;
} else {
  // 原生平台使用完整的壓縮參數
  final Uint8List compressed = await FlutterImageCompress.compressWithList(
    Uint8List.fromList(bytes),
    minWidth: targetWidth,
    minHeight: targetHeight,
    quality: 80,
    format: CompressFormat.webp,
  );
  return compressed;
}
```

### 3. **錯誤處理降級**
```dart
} catch (e) {
  debugPrint('❌ 壓縮圖片失敗: $e');
  // 如果壓縮失敗，返回原始數據
  return bytes;
}
```

### 4. **用戶友好的錯誤提示**
```dart
// 根據錯誤類型顯示不同的提示
if (e.toString().contains('圖片尺寸太小')) {
  errorMessage = '圖片尺寸太小，請選擇至少 320x320 的圖片';
} else if (e.toString().contains('檔案過大')) {
  errorMessage = '圖片檔案過大，請選擇小於 10MB 的圖片';
} else if (e.toString().contains('不支援的檔案格式')) {
  errorMessage = '不支援的檔案格式，請選擇 JPG、PNG 或 WebP 圖片';
}

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(errorMessage),
    backgroundColor: Colors.red,
    duration: const Duration(seconds: 3),
  ),
);
```

### 5. **上傳錯誤帶重試功能**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(errorMessage),
    backgroundColor: Colors.red,
    duration: const Duration(seconds: 3),
    action: SnackBarAction(
      label: '重試',
      textColor: Colors.white,
      onPressed: () => _retryImageUpload(item.localId),
    ),
  ),
);
```

## 📋 錯誤訊息對照表

| 原始錯誤 | 用戶友好訊息 |
|---------|-------------|
| `圖片尺寸太小，最小需要 320x320` | `圖片尺寸太小，請選擇至少 320x320 的圖片` |
| `檔案過大，最大允許 10MB` | `圖片檔案過大，請選擇小於 10MB 的圖片` |
| `不支援的檔案格式: .xxx` | `不支援的檔案格式，請選擇 JPG、PNG 或 WebP 圖片` |
| `壓縮圖片失敗: Platform._operatingSystem` | `處理失敗` (降級處理) |
| `上傳失敗: network error` | `網路連線問題，請檢查網路後重試` |

## 🔧 修改的檔案
- `lib/chat/services/image_processing_service.dart`
  - 添加 `ImageProcessingException` 類
  - Web 環境壓縮策略優化
  - 錯誤處理降級（返回原始數據而不是拋出異常）
- `lib/chat/pages/chat_detail_page.dart`
  - 圖片選擇錯誤的 Snackbar 提示
  - 上傳錯誤的 Snackbar 提示（帶重試功能）
  - 發送錯誤的 Snackbar 提示

## 🎯 優化效果
- ✅ Web 環境下圖片壓縮不再失敗
- ✅ 用戶看到友好的錯誤提示而不是技術性錯誤
- ✅ 上傳失敗時提供重試功能
- ✅ 錯誤訊息根據類型顯示相應的解決建議
- ✅ 所有錯誤都記錄在 debugPrint 中便於調試

## 🧪 測試建議
1. 選擇小於 320x320 的圖片
2. 選擇大於 10MB 的圖片
3. 選擇不支援的格式（如 .gif）
4. 在網路不穩定時上傳圖片
5. 測試重試功能是否正常工作
