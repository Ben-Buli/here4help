import 'package:flutter/material.dart';
import '../models/image_upload_status.dart';

/// 上傳中的圖片訊息 Widget
class UploadingImageMessage extends StatelessWidget {
  final ImageUploadStatus uploadStatus;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  const UploadingImageMessage({
    super.key,
    required this.uploadStatus,
    this.onCancel,
    this.onRetry,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // 圖片背景
                    Image.memory(
                      uploadStatus.imageData,
                      fit: BoxFit.cover,
                      width: 250,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 250,
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, size: 40),
                      ),
                    ),

                    // 遮罩層
                    Container(
                      width: 250,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                      ),
                      child: _buildOverlayContent(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 用戶頭像（發送者）
          CircleAvatar(
            radius: 16,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.35),
            child: Text(
              'Me',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 構建遮罩內容
  Widget _buildOverlayContent(BuildContext context) {
    switch (uploadStatus.state) {
      case ImageUploadState.uploading:
        return _buildUploadingOverlay(context);
      case ImageUploadState.failed:
        return _buildFailedOverlay(context);
      case ImageUploadState.cancelled:
        return _buildCancelledOverlay(context);
      case ImageUploadState.success:
        return _buildSuccessOverlay(context);
    }
  }

  /// 上傳中遮罩
  Widget _buildUploadingOverlay(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 圓形進度條
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: uploadStatus.progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              // 取消按鈕
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${(uploadStatus.progress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Uploading...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 失敗遮罩
  Widget _buildFailedOverlay(BuildContext context) {
    return Container(
      width: 250,
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload Failed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (uploadStatus.errorMessage != null)
            Flexible(
              child: Text(
                uploadStatus.errorMessage!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (uploadStatus.retryCount > 0)
            Text(
              'Retry ${uploadStatus.retryCount}',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 重試按鈕
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Retry', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(55, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
              const SizedBox(width: 6),
              // 移除按鈕
              ElevatedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete, size: 14),
                label: const Text('Remove', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(55, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 取消遮罩
  Widget _buildCancelledOverlay(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cancel_outlined,
            color: Colors.orange,
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Cancelled',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 成功遮罩
  Widget _buildSuccessOverlay(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Uploaded',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
