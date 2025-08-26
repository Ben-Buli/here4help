import 'dart:convert';
import 'package:here4help/chat/models/image_tray_item.dart';

/// 暫存圖片訊息狀態
enum PendingImageStatus {
  uploading, // 上傳中
  success, // 成功
  failed, // 失敗
}

/// 暫存圖片訊息
class PendingImageMessage {
  final String localId;
  final String? thumbnailUrl; // 縮圖 URL 或 base64
  final PendingImageStatus status;
  final double uploadProgress; // 上傳進度 0.0 - 1.0
  final String? errorMessage;
  final String? uploadedUrl; // 最終上傳的 URL
  final String? messageId; // 最終的訊息 ID
  final DateTime createdAt;

  PendingImageMessage({
    required this.localId,
    this.thumbnailUrl,
    this.status = PendingImageStatus.uploading,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.uploadedUrl,
    this.messageId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 從 ImageTrayItem 創建暫存訊息
  factory PendingImageMessage.fromImageTrayItem(ImageTrayItem item) {
    return PendingImageMessage(
      localId: item.localId,
      thumbnailUrl: item.thumbnailData != null
          ? 'data:image/webp;base64,${base64Encode(item.thumbnailData!)}'
          : null,
      status: PendingImageStatus.uploading,
      uploadProgress: 0.0,
    );
  }

  /// 創建副本並更新指定字段
  PendingImageMessage copyWith({
    String? thumbnailUrl,
    PendingImageStatus? status,
    double? uploadProgress,
    String? errorMessage,
    String? uploadedUrl,
    String? messageId,
  }) {
    return PendingImageMessage(
      localId: localId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
      messageId: messageId ?? this.messageId,
      createdAt: createdAt,
    );
  }

  /// 是否正在上傳
  bool get isUploading => status == PendingImageStatus.uploading;

  /// 是否上傳成功
  bool get isSuccess => status == PendingImageStatus.success;

  /// 是否上傳失敗
  bool get isFailed => status == PendingImageStatus.failed;

  /// 格式化進度百分比
  String get progressText => '${(uploadProgress * 100).toInt()}%';

  @override
  String toString() {
    return 'PendingImageMessage(localId: $localId, status: $status, progress: $progressText)';
  }
}
