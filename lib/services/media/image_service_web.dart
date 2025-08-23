import 'dart:typed_data';
import 'dart:html' as html;

/// Web platform specific image service
class PlatformImageService {
  /// Web 平台不支援檔案路徑讀取，拋出錯誤
  static Future<Uint8List> readImageBytes(String filePath) async {
    throw UnsupportedError(
        'File path reading is not supported on web platform');
  }

  /// Web 平台檔案存在性檢查不適用
  static bool fileExists(String filePath) {
    return false;
  }

  /// Web 平台檔案大小獲取不適用
  static int getFileSize(String filePath) {
    return 0;
  }

  /// 從 HTML File 對象讀取數據
  static Future<Uint8List> readFromHtmlFile(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);

    await reader.onLoad.first;

    final result = reader.result as List<int>;
    return Uint8List.fromList(result);
  }
}
