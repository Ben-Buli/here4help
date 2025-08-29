import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import '../models/image_tray_item.dart';

/// 圖片處理異常類
class ImageProcessingException implements Exception {
  final String message;
  ImageProcessingException(this.message);

  @override
  String toString() => message;
}

/// 圖片處理服務
/// 負責圖片選擇、驗證、壓縮和縮圖生成
class ImageProcessingService {
  static final ImageProcessingService _instance =
      ImageProcessingService._internal();
  factory ImageProcessingService() => _instance;
  ImageProcessingService._internal();

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // 配置常數
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxDimension = 2048; // 最大邊長
  static const int thumbnailSize = 256; // 縮圖尺寸
  static const int minDimension = 320; // 最小尺寸
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif'
  ];

  /// 選擇多張圖片（最多9張）- 簡化版本，一次選一張
  Future<List<ImageTrayItem>> pickMultipleImages({int maxImages = 9}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxDimension.toDouble(),
        maxHeight: maxDimension.toDouble(),
        imageQuality: 85,
      );

      if (image == null) return [];

      try {
        final item = await _processImage(image);
        return [item];
      } catch (e) {
        debugPrint('❌ 處理圖片失敗[image_processing_service]: ${image.name}, 錯誤: $e');

        // 如果是 ImageProcessingException，直接拋出讓上層處理
        if (e is ImageProcessingException) {
          rethrow;
        }
        // 其他錯誤創建失敗項目
        final failedItem = ImageTrayItem(
          localId: _uuid.v4(),
          originalFile: File(''), // Web 環境下使用空 File
          fileSize: await image.length(),
          status: UploadStatus.failed,
          errorMessage: '處理失敗',
        );
        return [failedItem];
      }
    } catch (e) {
      debugPrint('❌ 選擇圖片失敗[image_processing_service]: $e');
      throw ImageProcessingException('❌ 選擇圖片失敗[image_processing_service]: $e');
    }
  }

  /// 選擇單張圖片
  Future<ImageTrayItem?> pickSingleImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxDimension.toDouble(),
        maxHeight: maxDimension.toDouble(),
        imageQuality: 85,
      );

      if (image == null) return null;

      return await _processImage(image);
    } catch (e) {
      debugPrint('❌ 選擇圖片失敗[image_processing_service]: $e');
      throw Exception('選擇圖片失敗: $e');
    }
  }

  /// 處理單張圖片
  Future<ImageTrayItem> _processImage(XFile image) async {
    final localId = _uuid.v4();
    final fileSize = await image.length();

    // 基本驗證
    _validateFile(image.name, fileSize);

    // 讀取圖片數據 - Web 安全的方式
    final Uint8List bytes = await image.readAsBytes();

    // 獲取圖片尺寸
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final int width = frameInfo.image.width;
    final int height = frameInfo.image.height;

    // 驗證尺寸
    if (width < minDimension || height < minDimension) {
      debugPrint(
          '❌ 圖片尺寸驗證失敗: ${width}x$height < ${minDimension}x$minDimension');
      throw ImageProcessingException(
          '圖片尺寸太小，最小需要 ${minDimension}x$minDimension');
    }

    // 壓縮圖片（Web 環境下總是壓縮以確保有數據可用）
    Uint8List? compressedData;
    if (kIsWeb || _needsCompression(bytes, width, height)) {
      compressedData = await _compressImage(bytes, width, height);
    }

    // 生成縮圖
    final thumbnailData = await _generateThumbnail(bytes);

    // 創建 File 對象 - Web 安全的方式
    File? originalFile;
    try {
      if (!kIsWeb) {
        originalFile = File(image.path);
      }
    } catch (e) {
      debugPrint('⚠️ 無法創建 File 對象 (Web 環境): $e');
    }

    return ImageTrayItem(
      localId: localId,
      originalFile: originalFile ?? File(''), // Web 環境下使用空 File
      compressedData: compressedData,
      thumbnailData: thumbnailData,
      fileSize: fileSize,
      width: width,
      height: height,
      status: UploadStatus.queued,
    );
  }

  /// 驗證檔案
  void _validateFile(String fileName, int fileSize) {
    // 檢查檔案大小
    if (fileSize > maxFileSize) {
      debugPrint(
          '❌ 檔案大小驗證失敗: ${_formatBytes(fileSize)} > ${_formatBytes(maxFileSize)}');
      throw ImageProcessingException('檔案過大，最大允許 ${_formatBytes(maxFileSize)}');
    }

    // 檢查副檔名
    final extension = fileName.toLowerCase().split('.').last;
    if (!allowedExtensions.contains(extension)) {
      debugPrint('❌ 檔案格式驗證失敗: .$extension 不在允許列表中');
      throw ImageProcessingException('不支援的檔案格式，請選擇 JPG、PNG 或 WebP 圖片');
    }
  }

  /// 判斷是否需要壓縮
  bool _needsCompression(Uint8List bytes, int width, int height) {
    return bytes.length > 2 * 1024 * 1024 || // 大於 2MB
        width > maxDimension ||
        height > maxDimension;
  }

  /// 壓縮圖片
  Future<Uint8List> _compressImage(
      Uint8List bytes, int width, int height) async {
    try {
      // Web 環境下跳過壓縮，直接返回原始數據
      if (kIsWeb) {
        debugPrint('🌐 Web 環境：跳過圖片壓縮，直接使用原始數據');
        return bytes;
      }

      // 計算目標尺寸（僅原生平台）
      int targetWidth = width;
      int targetHeight = height;

      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          targetWidth = maxDimension;
          targetHeight = (height * maxDimension / width).round();
        } else {
          targetHeight = maxDimension;
          targetWidth = (width * maxDimension / height).round();
        }
      }

      // 原生平台使用完整的壓縮參數
      final Uint8List compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: 80,
        format: CompressFormat.webp,
      );
      return compressed;
    } catch (e) {
      debugPrint('❌ 壓縮圖片失敗: $e');
      // 如果壓縮失敗，返回原始數據
      return bytes;
    }
  }

  /// 生成縮圖
  Future<Uint8List> generateThumbnail(File imageFile) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();

      // Web 環境下跳過縮圖生成
      if (kIsWeb) {
        debugPrint('🌐 Web 環境：跳過縮圖生成，使用原始數據');
        return bytes.length > 512 * 1024 ? bytes.sublist(0, 512 * 1024) : bytes;
      }

      // 生成 256px 的縮圖（僅原生平台）
      final Uint8List thumbnail = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 256,
        minHeight: 256,
        quality: 70,
        format: CompressFormat.webp,
      );

      return thumbnail;
    } catch (e) {
      throw Exception('生成縮圖失敗: $e');
    }
  }

  /// 生成縮圖（內部使用）
  Future<Uint8List> _generateThumbnail(Uint8List bytes) async {
    try {
      if (kIsWeb) {
        // Web 環境下跳過縮圖生成，返回原始數據的一部分作為縮圖
        debugPrint('🌐 Web 環境：跳過縮圖生成，使用原始數據');
        return bytes.length > 512 * 1024 ? bytes.sublist(0, 512 * 1024) : bytes;
      } else {
        // 原生平台使用完整參數
        final Uint8List thumbnail = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: thumbnailSize,
          minHeight: thumbnailSize,
          quality: 70,
          format: CompressFormat.webp,
        );
        return thumbnail;
      }
    } catch (e) {
      debugPrint('❌ 生成縮圖失敗: $e');
      // 如果縮圖生成失敗，返回原始數據的一部分
      return bytes.length > 512 * 1024 ? bytes.sublist(0, 512 * 1024) : bytes;
    }
  }

  /// 進一步壓縮至指定最大大小（上傳保險，避免超過伺服器限制）
  Future<Uint8List> compressToMaxSize(
    Uint8List inputBytes, {
    int maxBytes = 5 * 1024 * 1024, // 5MB 與後端一致
    int minQuality = 50,
  }) async {
    try {
      if (inputBytes.length <= maxBytes) return inputBytes;

      // Web 環境下跳過進一步壓縮
      if (kIsWeb) {
        debugPrint('🌐 Web 環境：跳過進一步壓縮，直接返回原始數據');
        return inputBytes;
      }

      Uint8List current = inputBytes;
      int quality = 80;

      // 先嘗試逐步降低品質（僅原生平台）
      while (current.length > maxBytes && quality >= minQuality) {
        final Uint8List buf = await FlutterImageCompress.compressWithList(
          current,
          quality: quality,
          format: CompressFormat.webp,
        );
        current = buf;
        quality -= 10;
      }

      if (current.length <= maxBytes) return current;

      // 若仍超過，則再降解析度到 1280 邊長，並以中品質輸出
      final ui.Codec codec = await ui.instantiateImageCodec(current);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final int width = frameInfo.image.width;
      final int height = frameInfo.image.height;

      int targetWidth = width;
      int targetHeight = height;
      const int cap = 1280; // 解析度保險上限
      if (width > height) {
        if (width > cap) {
          targetWidth = cap;
          targetHeight = (height * cap / width).round();
        }
      } else {
        if (height > cap) {
          targetHeight = cap;
          targetWidth = (width * cap / height).round();
        }
      }

      final Uint8List buf2 = await FlutterImageCompress.compressWithList(
        current,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: (minQuality + 10),
        format: CompressFormat.webp,
      );
      current = buf2;

      return current;
    } catch (e) {
      // 若保險壓縮失敗，回退原資料，讓上層處理錯誤
      return inputBytes;
    }
  }

  /// 格式化位元組大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}
