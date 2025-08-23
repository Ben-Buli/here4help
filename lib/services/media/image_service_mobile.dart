import 'dart:io';
import 'dart:typed_data';

/// Mobile platform (iOS/Android) specific image service
class PlatformImageService {
  /// 從檔案路徑讀取圖片數據
  static Future<Uint8List> readImageBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }

  /// 檢查檔案是否存在
  static bool fileExists(String filePath) {
    return File(filePath).existsSync();
  }

  /// 獲取檔案大小
  static int getFileSize(String filePath) {
    return File(filePath).lengthSync();
  }
}
