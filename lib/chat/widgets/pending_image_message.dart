import 'package:flutter/material.dart';
import 'package:here4help/chat/models/pending_image_message.dart';
import 'package:here4help/utils/error_message_mapper.dart';

/// 暫存圖片訊息氣泡
class PendingImageMessageBubble extends StatelessWidget {
  final PendingImageMessage message;
  final bool isFromMe;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const PendingImageMessageBubble({
    super.key,
    required this.message,
    required this.isFromMe,
    this.onRetry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.35),
              child: Text(
                'U',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // 圖片背景
                    if (message.thumbnailUrl != null)
                      Image.network(
                        message.thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: 250,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 250,
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      )
                    else
                      Container(
                        width: 250,
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 40),
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
          // 我方訊息：不顯示我方頭像
        ],
      ),
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    switch (message.status) {
      case PendingImageStatus.uploading:
        return _buildUploadingOverlay(context);
      case PendingImageStatus.success:
        return _buildSuccessOverlay(context);
      case PendingImageStatus.failed:
        return _buildFailedOverlay(context);
    }
  }

  Widget _buildUploadingOverlay(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 進度圓圈
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            value: message.uploadProgress,
            strokeWidth: 3,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        // 進度文字
        Text(
          message.progressText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '上傳中...',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessOverlay(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.8),
      ),
      child: const Center(
        child: Icon(
          Icons.check_circle,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildFailedOverlay(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            getImageUploadErrorMessage(message.errorMessage ?? '上傳失敗'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // 操作按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重試'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              if (onRetry != null && onDelete != null) const SizedBox(width: 8),
              if (onDelete != null)
                ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('刪除'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
