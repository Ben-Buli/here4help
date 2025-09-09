import 'dart:typed_data';

/// 圖片上傳狀態枚舉
enum ImageUploadState {
  uploading, // 上傳中
  success, // 上傳成功
  failed, // 上傳失敗
  cancelled, // 已取消
}

/// 圖片上傳狀態管理
class ImageUploadStatus {
  final String localId;
  final String messageId;
  final Uint8List imageData;
  final String fileName;
  final ImageUploadState state;
  final double progress;
  final String? errorMessage;
  final String? uploadedUrl;
  final String? tempFilePath; // 暫存的檔案路徑（用於清理）
  final int retryCount; // 重試次數

  ImageUploadStatus({
    required this.localId,
    required this.messageId,
    required this.imageData,
    required this.fileName,
    required this.state,
    this.progress = 0.0,
    this.errorMessage,
    this.uploadedUrl,
    this.tempFilePath,
    this.retryCount = 0,
  });

  /// 創建上傳中狀態
  factory ImageUploadStatus.uploading({
    required String localId,
    required String messageId,
    required Uint8List imageData,
    required String fileName,
    double progress = 0.0,
  }) {
    return ImageUploadStatus(
      localId: localId,
      messageId: messageId,
      imageData: imageData,
      fileName: fileName,
      state: ImageUploadState.uploading,
      progress: progress,
    );
  }

  /// 創建成功狀態
  factory ImageUploadStatus.success({
    required String localId,
    required String messageId,
    required Uint8List imageData,
    required String fileName,
    required String uploadedUrl,
  }) {
    return ImageUploadStatus(
      localId: localId,
      messageId: messageId,
      imageData: imageData,
      fileName: fileName,
      state: ImageUploadState.success,
      progress: 1.0,
      uploadedUrl: uploadedUrl,
    );
  }

  /// 創建失敗狀態
  factory ImageUploadStatus.failed({
    required String localId,
    required String messageId,
    required Uint8List imageData,
    required String fileName,
    required String errorMessage,
  }) {
    return ImageUploadStatus(
      localId: localId,
      messageId: messageId,
      imageData: imageData,
      fileName: fileName,
      state: ImageUploadState.failed,
      progress: 0.0,
      errorMessage: errorMessage,
    );
  }

  /// 創建取消狀態
  factory ImageUploadStatus.cancelled({
    required String localId,
    required String messageId,
    required Uint8List imageData,
    required String fileName,
  }) {
    return ImageUploadStatus(
      localId: localId,
      messageId: messageId,
      imageData: imageData,
      fileName: fileName,
      state: ImageUploadState.cancelled,
      progress: 0.0,
    );
  }

  /// 複製並更新狀態
  ImageUploadStatus copyWith({
    ImageUploadState? state,
    double? progress,
    String? errorMessage,
    String? uploadedUrl,
    String? tempFilePath,
    int? retryCount,
  }) {
    return ImageUploadStatus(
      localId: localId,
      messageId: messageId,
      imageData: imageData,
      fileName: fileName,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
