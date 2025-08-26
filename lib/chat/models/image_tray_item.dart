import 'dart:io';
import 'dart:typed_data';

/// 圖片上傳狀態
enum UploadStatus {
  queued, // 排隊中
  uploading, // 上傳中
  success, // 成功
  failed, // 失敗
}

/// 圖片托盤項目
class ImageTrayItem {
  final String localId;
  final File originalFile;
  final Uint8List? compressedData;
  final Uint8List? thumbnailData;
  final String? errorMessage;
  final UploadStatus status;
  final int? width;
  final int? height;
  final int fileSize;
  final String? uploadedUrl;
  final String? uploadedMessageId;

  ImageTrayItem({
    required this.localId,
    required this.originalFile,
    this.compressedData,
    this.thumbnailData,
    this.errorMessage,
    this.status = UploadStatus.queued,
    this.width,
    this.height,
    required this.fileSize,
    this.uploadedUrl,
    this.uploadedMessageId,
  });

  /// 創建副本並更新指定字段
  ImageTrayItem copyWith({
    Uint8List? compressedData,
    Uint8List? thumbnailData,
    String? errorMessage,
    UploadStatus? status,
    String? uploadedUrl,
    String? uploadedMessageId,
  }) {
    return ImageTrayItem(
      localId: localId,
      originalFile: originalFile,
      compressedData: compressedData ?? this.compressedData,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
      width: width,
      height: height,
      fileSize: fileSize,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
      uploadedMessageId: uploadedMessageId ?? this.uploadedMessageId,
    );
  }

  /// 是否為有效的圖片項目
  bool get isValid => thumbnailData != null;

  /// 是否可以上傳
  bool get canUpload =>
      status == UploadStatus.queued || status == UploadStatus.failed;

  /// 是否正在上傳
  bool get isUploading => status == UploadStatus.uploading;

  /// 是否上傳成功
  bool get isUploaded => status == UploadStatus.success;

  /// 是否上傳失敗
  bool get isFailed => status == UploadStatus.failed;

  /// 格式化文件大小
  String get formattedSize {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  @override
  String toString() {
    return 'ImageTrayItem(localId: $localId, status: $status, size: $formattedSize, error: $errorMessage)';
  }
}
