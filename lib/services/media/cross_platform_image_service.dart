import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'dart:convert';

/// 圖片選擇結果
class ImageResult {
  final Uint8List bytes;
  final String name;
  final String mimeType;
  final int size;

  ImageResult({
    required this.bytes,
    required this.name,
    required this.mimeType,
    required this.size,
  });
}

/// 圖片驗證配置
class ImageValidationConfig {
  final int maxSizeBytes;
  final List<String> allowedTypes;
  final int? maxWidth;
  final int? maxHeight;

  const ImageValidationConfig({
    this.maxSizeBytes = 5 * 1024 * 1024, // 5MB
    this.allowedTypes = const [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp'
    ],
    this.maxWidth,
    this.maxHeight,
  });

  /// 頭像配置
  static const avatar = ImageValidationConfig(
    maxSizeBytes: 5 * 1024 * 1024, // 5MB
    allowedTypes: ['image/jpeg', 'image/png', 'image/webp'],
    maxWidth: 1024,
    maxHeight: 1024,
  );

  /// 聊天附件配置
  static const chat = ImageValidationConfig(
    maxSizeBytes: 10 * 1024 * 1024, // 10MB
    allowedTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
  );

  /// 學生證配置
  static const studentId = ImageValidationConfig(
    maxSizeBytes: 10 * 1024 * 1024, // 10MB
    allowedTypes: ['image/jpeg', 'image/png'],
    maxWidth: 4096,
    maxHeight: 4096,
  );
}

/// 跨平台圖片服務
/// 統一處理 Web、iOS、Android 的圖片選擇、預覽和上傳
class CrossPlatformImageService {
  static final CrossPlatformImageService _instance =
      CrossPlatformImageService._internal();
  factory CrossPlatformImageService() => _instance;
  CrossPlatformImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// 從相機選擇圖片
  Future<ImageResult?> pickFromCamera({
    ImageValidationConfig config = ImageValidationConfig.avatar,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: config.maxWidth?.toDouble(),
        maxHeight: config.maxHeight?.toDouble(),
        imageQuality: 85,
      );

      if (image == null) return null;

      return await _processXFile(image, config);
    } catch (e) {
      throw Exception('選擇相機圖片失敗: $e');
    }
  }

  /// 從相簿選擇圖片
  Future<ImageResult?> pickFromGallery({
    ImageValidationConfig config = ImageValidationConfig.avatar,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: config.maxWidth?.toDouble(),
        maxHeight: config.maxHeight?.toDouble(),
        imageQuality: 85,
      );

      if (image == null) return null;

      return await _processXFile(image, config);
    } catch (e) {
      throw Exception('選擇相簿圖片失敗: $e');
    }
  }

  /// 處理 XFile 並驗證
  Future<ImageResult> _processXFile(
      XFile file, ImageValidationConfig config) async {
    // 獲取圖片數據
    final bytes = await file.readAsBytes();
    final name = file.name;
    final mimeType = file.mimeType ?? _getMimeTypeFromExtension(name);

    // 驗證圖片
    _validateImage(bytes, name, mimeType, config);

    return ImageResult(
      bytes: bytes,
      name: name,
      mimeType: mimeType,
      size: bytes.length,
    );
  }

  /// 驗證圖片
  void _validateImage(Uint8List bytes, String name, String mimeType,
      ImageValidationConfig config) {
    // 檢查檔案大小
    if (bytes.length > config.maxSizeBytes) {
      throw Exception('圖片大小超過限制 (${_formatBytes(config.maxSizeBytes)})');
    }

    // 檢查檔案類型
    if (!config.allowedTypes.contains(mimeType)) {
      throw Exception('不支援的圖片格式: $mimeType');
    }

    // 檢查檔案名稱
    if (!_isValidFileName(name)) {
      throw Exception('檔案名稱包含非法字元');
    }
  }

  /// 上傳圖片到指定 API
  Future<Map<String, dynamic>> uploadImage({
    required ImageResult image,
    required String uploadUrl,
    required String token,
    required String fieldName,
    Map<String, String>? additionalFields,
  }) async {
    try {
      final uri = Uri.parse(uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      // 添加認證 header
      request.headers['Authorization'] = 'Bearer $token';

      // 添加額外欄位
      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }

      // 添加圖片檔案
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          image.bytes,
          filename: image.name,
          contentType: _parseMediaType(image.mimeType),
        ),
      );

      // 發送請求
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Upload failed');
      }
    } catch (e) {
      throw Exception('上傳失敗: $e');
    }
  }

  /// 創建圖片預覽 Widget 的 ImageProvider
  ImageProvider createImageProvider(ImageResult image) {
    return MemoryImage(image.bytes);
  }

  /// 根據副檔名推測 MIME 類型
  String _getMimeTypeFromExtension(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  /// 解析 MediaType
  http_parser.MediaType _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    return http_parser.MediaType(parts[0], parts[1]);
  }

  /// 格式化檔案大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 檢查檔案名稱是否有效
  bool _isValidFileName(String fileName) {
    // 檢查非法字元
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    if (invalidChars.hasMatch(fileName)) return false;

    // 檢查長度
    if (fileName.length > 255) return false;

    // 檢查是否為空或只有空格
    if (fileName.trim().isEmpty) return false;

    return true;
  }
}
