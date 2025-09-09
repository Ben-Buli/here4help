import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import '../models/image_tray_item.dart';
import '../services/image_processing_service.dart';
import '../services/chat_service.dart';
import '../../services/media/cross_platform_image_service.dart';
import 'package:here4help/utils/error_message_mapper.dart';

/// 圖片上傳管理器
/// 負責管理圖片上傳的生命週期，包括排隊、批量處理和狀態更新
class ImageUploadManager {
  final ImageProcessingService _processingService = ImageProcessingService();
  final ChatService _chatService = ChatService();
  final String _roomId;
  final Uuid _uuid = const Uuid();

  final List<ImageTrayItem> _uploadQueue = [];
  bool _isUploading = false;

  // 狀態更新回調
  Function(List<ImageTrayItem>)? onItemsUpdated;
  Function(ImageTrayItem, String)? onItemError;
  Function(ImageTrayItem)? onItemSuccess;
  Function(String, double)? onProgressUpdate; // 新增：進度更新回調

  ImageUploadManager(this._roomId);

  /// 獲取當前托盤項目
  List<ImageTrayItem> get items => List.unmodifiable(_uploadQueue);

  /// 是否正在上傳
  bool get isUploading => _isUploading;

  /// 是否有項目
  bool get hasItems => _uploadQueue.isNotEmpty;

  /// 可上傳的項目數量
  int get uploadableCount =>
      _uploadQueue.where((item) => item.canUpload).length;

  /// 添加圖片到托盤（支援 Web 環境）
  Future<List<ImageTrayItem>> addImages(List<File> imageFiles) async {
    try {
      // 檢查數量限制
      final remainingSlots = 9 - _uploadQueue.length;
      if (remainingSlots <= 0) {
        throw Exception('托盤已滿，最多只能添加 9 張圖片');
      }

      final filesToProcess = imageFiles.take(remainingSlots).toList();
      final List<ImageTrayItem> newItems = [];

      for (final file in filesToProcess) {
        try {
          // 使用 ImageProcessingService 來處理圖片（Web 兼容）
          ImageTrayItem item;
          if (kIsWeb) {
            // Web 環境：不能直接讀取 File，拋出錯誤提示使用正確的方法
            throw Exception(
                'Web 環境不支援直接處理 File 物件，請使用 CrossPlatformImageService');
          } else {
            // 原生環境：直接處理檔案
            item = await _processImageFile(file);
          }

          newItems.add(item);
          _uploadQueue.add(item);
        } catch (e) {
          debugPrint(
              '❌ 處理圖片失敗[image_upload_manager]: ${kIsWeb ? 'web_file' : file.path}, 錯誤: $e');
          final errorMessage = getImageUploadErrorMessage(e.toString());

          // 創建失敗項目
          int fileSize = 0;
          try {
            fileSize = await file.length();
          } catch (_) {
            fileSize = 0;
          }

          final failedItem = ImageTrayItem(
            localId: DateTime.now().millisecondsSinceEpoch.toString(),
            originalFile: kIsWeb ? File('') : file,
            fileSize: fileSize,
            status: UploadStatus.failed,
            errorMessage: errorMessage,
          );
          newItems.add(failedItem);
          _uploadQueue.add(failedItem);
        }
      }

      _notifyItemsUpdated();
      return newItems;
    } catch (e) {
      final errorMessage = getImageUploadErrorMessage(e.toString());
      debugPrint('❌ 添加圖片失敗[image_upload_manager]: $errorMessage');
      throw Exception(errorMessage);
    }
  }

  /// 添加圖片到托盤（從 ImageResult 物件，Web 兼容）
  Future<List<ImageTrayItem>> addImagesFromResults(
      List<ImageResult> imageResults) async {
    try {
      // 檢查數量限制
      final remainingSlots = 9 - _uploadQueue.length;
      if (remainingSlots <= 0) {
        throw Exception('托盤已滿，最多只能添加 9 張圖片');
      }

      final resultsToProcess = imageResults.take(remainingSlots).toList();
      final List<ImageTrayItem> newItems = [];

      for (final imageResult in resultsToProcess) {
        try {
          final item = await _processImageResult(imageResult);
          newItems.add(item);
          _uploadQueue.add(item);
        } catch (e) {
          debugPrint(
              '❌ 處理圖片失敗[image_upload_manager]: ${imageResult.name}, 錯誤: $e');
          final errorMessage = getImageUploadErrorMessage(e.toString());

          // 創建失敗項目
          final failedItem = ImageTrayItem(
            localId: DateTime.now().millisecondsSinceEpoch.toString(),
            originalFile: File(''), // Web 環境使用空 File
            fileSize: imageResult.size,
            status: UploadStatus.failed,
            errorMessage: errorMessage,
          );

          newItems.add(failedItem);
          _uploadQueue.add(failedItem);
        }
      }

      _notifyItemsUpdated();
      return newItems;
    } catch (e) {
      final errorMessage = getImageUploadErrorMessage(e.toString());
      debugPrint('❌ 添加圖片失敗[image_upload_manager]: $errorMessage');
      throw Exception(errorMessage);
    }
  }

  /// 從托盤移除圖片
  void removeImage(String localId) {
    _uploadQueue.removeWhere((item) => item.localId == localId);
    _notifyItemsUpdated();
  }

  /// 清空托盤
  void clearAll() {
    _uploadQueue.clear();
    _notifyItemsUpdated();
  }

  /// 開始批量上傳
  Future<List<String>> startBatchUpload() async {
    if (_isUploading) {
      throw Exception('正在上傳中，請稍候');
    }

    final uploadableItems =
        _uploadQueue.where((item) => item.canUpload).toList();
    if (uploadableItems.isEmpty) {
      return [];
    }

    _isUploading = true;
    final List<String> uploadedMessageIds = [];

    try {
      for (final item in uploadableItems) {
        try {
          // 更新狀態為上傳中
          _updateItemStatus(item.localId, UploadStatus.uploading);

          // 上傳圖片
          final result = await _uploadImage(item);

          if (result['success'] == true) {
            // 更新狀態為成功
            final updatedItem = _updateItemStatus(
              item.localId,
              UploadStatus.success,
              uploadedUrl: result['url'],
              uploadedMessageId: result['message_id']?.toString(),
            );

            uploadedMessageIds.add(result['message_id']?.toString() ?? '');
            onItemSuccess?.call(updatedItem);
          } else {
            // 上傳失敗
            final errorMsg = result['message'] ?? '上傳失敗';
            final updatedItem = _updateItemStatus(
              item.localId,
              UploadStatus.failed,
              errorMessage: errorMsg,
            );
            onItemError?.call(updatedItem, errorMsg);
          }
        } catch (e) {
          debugPrint('❌ 上傳圖片失敗: ${item.localId}, 錯誤: $e');
          final updatedItem = _updateItemStatus(
            item.localId,
            UploadStatus.failed,
            errorMessage: '上傳失敗: $e',
          );
          onItemError?.call(updatedItem, e.toString());
        }
      }

      return uploadedMessageIds;
    } finally {
      _isUploading = false;
    }
  }

  /// 上傳單張圖片
  Future<Map<String, dynamic>> _uploadImage(ImageTrayItem item) async {
    try {
      // 更新進度：開始上傳
      onProgressUpdate?.call(item.localId, 0.1);

      // 準備上傳數據
      Uint8List uploadData;

      if (item.compressedData != null) {
        // 使用壓縮後的數據
        uploadData = item.compressedData!;
      } else {
        // Web 環境下無法讀取 originalFile，應該總是有 compressedData 或 thumbnailData
        if (item.thumbnailData != null) {
          uploadData = item.thumbnailData!;
        } else {
          throw Exception('Web 環境下缺少圖片數據');
        }
      }

      // 更新進度：數據準備完成
      onProgressUpdate?.call(item.localId, 0.3);

      // 進一步壓縮以確保不超過後端限制（5MB）
      uploadData = await _processingService.compressToMaxSize(uploadData);

      // 更新進度：壓縮完成
      onProgressUpdate?.call(item.localId, 0.5);

      // 創建 ImageResult 對象
      String fileName = 'image_${item.localId}.webp';
      if (!kIsWeb && item.originalFile.path.isNotEmpty) {
        fileName = item.originalFile.path.split('/').last;
      }

      final imageResult = ImageResult(
        bytes: uploadData,
        name: fileName,
        mimeType: 'image/webp', // 統一使用 webp 格式
        size: uploadData.length,
      );

      // 更新進度：準備上傳
      onProgressUpdate?.call(item.localId, 0.7);

      // 上傳到後端
      final uploadResult = await _chatService.uploadAttachment(
        roomId: _roomId,
        image: imageResult,
      );

      // 更新進度：上傳完成
      onProgressUpdate?.call(item.localId, 0.9);

      if (uploadResult['success'] == true) {
        final uploadedUrl =
            uploadResult['data']?['url'] ?? uploadResult['data']?['path'];

        // 更新進度：發送訊息
        onProgressUpdate?.call(item.localId, 0.95);

        // 發送圖片訊息
        final messageResult = await _chatService.sendMessage(
          roomId: _roomId,
          message: uploadedUrl ?? '',
          kind: 'image',
        );

        // 更新進度：完成
        onProgressUpdate?.call(item.localId, 1.0);

        return {
          'success': true,
          'url': uploadedUrl,
          'message_id': messageResult['message_id'],
        };
      } else {
        return {
          'success': false,
          'message': uploadResult['message'] ?? '上傳失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// 重試上傳
  Future<void> retryUpload(ImageTrayItem item) async {
    if (item.status != UploadStatus.failed) {
      return;
    }

    try {
      // 重置狀態
      _updateItemStatus(item.localId, UploadStatus.uploading);

      // 重新上傳
      final result = await _uploadImage(item);

      if (result['success'] == true) {
        final updatedItem = _updateItemStatus(
          item.localId,
          UploadStatus.success,
          uploadedUrl: result['url'],
          uploadedMessageId: result['message_id']?.toString(),
        );
        onItemSuccess?.call(updatedItem);
      } else {
        final errorMsg = result['message'] ?? '重試失敗';
        final updatedItem = _updateItemStatus(
          item.localId,
          UploadStatus.failed,
          errorMessage: errorMsg,
        );
        onItemError?.call(updatedItem, errorMsg);
      }
    } catch (e) {
      final updatedItem = _updateItemStatus(
        item.localId,
        UploadStatus.failed,
        errorMessage: '重試失敗: $e',
      );
      onItemError?.call(updatedItem, e.toString());
    }
  }

  /// 更新項目狀態
  ImageTrayItem _updateItemStatus(
    String localId,
    UploadStatus status, {
    String? errorMessage,
    String? uploadedUrl,
    String? uploadedMessageId,
  }) {
    final index = _uploadQueue.indexWhere((item) => item.localId == localId);
    if (index != -1) {
      final updatedItem = _uploadQueue[index].copyWith(
        status: status,
        errorMessage: errorMessage,
        uploadedUrl: uploadedUrl,
        uploadedMessageId: uploadedMessageId,
      );
      _uploadQueue[index] = updatedItem;
      _notifyItemsUpdated();
      return updatedItem;
    }
    throw Exception('找不到指定的項目: $localId');
  }

  /// 通知項目更新
  void _notifyItemsUpdated() {
    onItemsUpdated?.call(List.unmodifiable(_uploadQueue));
  }

  /// 處理 ImageResult 物件（Web 兼容）
  Future<ImageTrayItem> _processImageResult(ImageResult imageResult) async {
    final localId = _uuid.v4();
    final bytes = imageResult.bytes;
    final fileName = imageResult.name;
    final fileSize = imageResult.size;

    // 基本驗證
    _validateFile(fileName, fileSize);

    // 獲取圖片尺寸
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final int width = frameInfo.image.width;
    final int height = frameInfo.image.height;

    // 驗證尺寸
    if (width < 320 || height < 320) {
      throw Exception('圖片尺寸太小，最小需要 320x320');
    }

    // 壓縮圖片（Web 和原生環境都支援）
    Uint8List? compressedData;
    try {
      if (kIsWeb) {
        compressedData = await _compressImageWeb(bytes);
      } else {
        compressedData = await _compressImage(bytes, width, height);
      }
      debugPrint('✅ 圖片壓縮完成，大小: ${compressedData?.length ?? 0} bytes');
    } catch (e) {
      debugPrint('❌ 壓縮失敗，使用原始數據: $e');
      compressedData = bytes;
    }

    // 生成縮圖
    Uint8List? thumbnailData;
    try {
      if (kIsWeb) {
        thumbnailData = await _generateThumbnailWeb(bytes);
      } else {
        thumbnailData = await _generateThumbnail(bytes);
      }
      debugPrint('✅ 縮圖生成完成，大小: ${thumbnailData?.length ?? 0} bytes');
    } catch (e) {
      debugPrint('❌ 縮圖生成失敗，使用壓縮數據: $e');
      thumbnailData = compressedData;
    }

    // 確保至少有一種數據可用
    if ((thumbnailData == null || thumbnailData.isEmpty) &&
        (compressedData == null || compressedData.isEmpty)) {
      debugPrint('⚠️ 警告：縮圖和壓縮數據都不可用，使用原始數據');
      thumbnailData = bytes;
      compressedData = bytes;
    }

    return ImageTrayItem(
      localId: localId,
      originalFile: File(''), // Web 環境下使用空 File
      compressedData: compressedData,
      thumbnailData: thumbnailData,
      fileSize: fileSize,
      width: width,
      height: height,
      status: UploadStatus.queued,
    );
  }

  /// 處理單個圖片檔案
  Future<ImageTrayItem> _processImageFile(File file) async {
    final localId = _uuid.v4();
    final fileSize = await file.length();
    final fileName = file.path.split('/').last;

    // 基本驗證
    _validateFile(fileName, fileSize);

    // 讀取圖片數據
    final Uint8List bytes = await file.readAsBytes();

    // 獲取圖片尺寸
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final int width = frameInfo.image.width;
    final int height = frameInfo.image.height;

    // 驗證尺寸
    if (width < 320 || height < 320) {
      throw Exception('圖片尺寸太小，最小需要 320x320');
    }

    // 壓縮圖片（如果需要）
    Uint8List? compressedData;
    if (_needsCompression(bytes, width, height)) {
      compressedData = await _compressImage(bytes, width, height);
    }

    // 生成縮圖
    final thumbnailData = await _generateThumbnail(bytes);

    return ImageTrayItem(
      localId: localId,
      originalFile: file,
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
    if (fileSize > 10 * 1024 * 1024) {
      throw Exception('檔案過大，最大允許 10MB');
    }

    // 檢查副檔名
    final extension = fileName.toLowerCase().split('.').last;
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];
    if (!allowedExtensions.contains(extension)) {
      throw Exception('不支援的檔案格式: .$extension');
    }
  }

  /// 判斷是否需要壓縮
  bool _needsCompression(Uint8List bytes, int width, int height) {
    return bytes.length > 2 * 1024 * 1024 || // 大於 2MB
        width > 2048 ||
        height > 2048;
  }

  /// 壓縮圖片
  Future<Uint8List> _compressImage(
      Uint8List bytes, int width, int height) async {
    try {
      // Web 環境下跳過壓縮
      if (kIsWeb) {
        debugPrint('🌐 Web 環境：跳過圖片壓縮，直接使用原始數據');
        return bytes;
      }

      // 計算目標尺寸（僅原生平台）
      int targetWidth = width;
      int targetHeight = height;

      if (width > 2048 || height > 2048) {
        if (width > height) {
          targetWidth = 2048;
          targetHeight = (height * 2048 / width).round();
        } else {
          targetHeight = 2048;
          targetWidth = (width * 2048 / height).round();
        }
      }

      // 壓縮圖片（僅原生平台）
      final Uint8List compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: 80,
        format: CompressFormat.webp,
      );

      return compressed;
    } catch (e) {
      throw Exception('壓縮圖片失敗: $e');
    }
  }

  /// 壓縮圖片（Web 環境）
  Future<Uint8List> _compressImageWeb(Uint8List bytes) async {
    // Web 環境下跳過壓縮，直接返回原始數據
    debugPrint('🌐 Web 環境：跳過圖片壓縮，直接使用原始數據');
    return bytes;
  }

  /// 生成縮圖（Web 環境）
  Future<Uint8List> _generateThumbnailWeb(Uint8List bytes) async {
    // Web 環境下跳過縮圖生成，返回原始數據的一部分作為縮圖
    debugPrint('🌐 Web 環境：跳過縮圖生成，使用原始數據');
    return bytes.length > 512 * 1024 ? bytes.sublist(0, 512 * 1024) : bytes;
  }

  /// 生成縮圖
  Future<Uint8List> _generateThumbnail(Uint8List bytes) async {
    try {
      // Web 環境下跳過縮圖生成
      if (kIsWeb) {
        debugPrint('🌐 Web 環境：跳過縮圖生成，使用原始數據');
        return bytes.length > 512 * 1024 ? bytes.sublist(0, 512 * 1024) : bytes;
      }

      // 生成縮圖（僅原生平台）
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

  /// 清理資源
  void dispose() {
    _uploadQueue.clear();
    onItemsUpdated = null;
    onItemError = null;
    onItemSuccess = null;
  }
}
