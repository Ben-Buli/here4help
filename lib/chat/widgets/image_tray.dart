import 'package:flutter/material.dart';
import '../models/image_tray_item.dart';

/// 圖片托盤 UI 組件
/// 顯示選中的圖片、上傳狀態和操作按鈕
class ImageTray extends StatelessWidget {
  final List<ImageTrayItem> items;
  final VoidCallback onAddImages;
  final Function(String) onRemoveImage;
  final Function(String) onRetryUpload;
  final bool isUploading;

  const ImageTray({
    super.key,
    required this.items,
    required this.onAddImages,
    required this.onRemoveImage,
    required this.onRetryUpload,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // 圖片列表
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildImageItem(context, items[index]);
              },
            ),
          ),
          // 添加按鈕（如果未滿9張）
          if (items.length < 9 && !isUploading) _buildAddButton(context),
        ],
      ),
    );
  }

  /// 構建單個圖片項目
  Widget _buildImageItem(BuildContext context, ImageTrayItem item) {
    return Container(
      width: 72,
      height: 72,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // 圖片縮圖
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(item.status),
                  width: 2,
                ),
              ),
              child: _buildImageContent(item),
            ),
          ),

          // 狀態指示器
          _buildStatusIndicator(context, item),

          // 移除按鈕
          if (!isUploading || item.status != UploadStatus.uploading)
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: () => onRemoveImage(item.localId),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 構建圖片內容
  Widget _buildImageContent(ImageTrayItem item) {
    if (item.thumbnailData != null) {
      return Image.memory(
        item.thumbnailData!,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
      );
    } else if (item.compressedData != null) {
      return Image.memory(
        item.compressedData!,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
      );
    } else {
      return const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      );
    }
  }

  /// 構建狀態指示器
  Widget _buildStatusIndicator(BuildContext context, ImageTrayItem item) {
    switch (item.status) {
      case UploadStatus.queued:
        return Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule,
              color: Colors.white,
              size: 12,
            ),
          ),
        );

      case UploadStatus.uploading:
        return const Positioned.fill(
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        );

      case UploadStatus.success:
        return Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 12,
            ),
          ),
        );

      case UploadStatus.failed:
        return Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onRetryUpload(item.localId),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        );
    }
  }

  /// 構建添加按鈕
  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: onAddImages,
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              '添加',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 獲取狀態顏色
  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.queued:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.success:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
    }
  }
}

/// 圖片托盤統計信息組件
class ImageTrayStats extends StatelessWidget {
  final List<ImageTrayItem> items;
  final bool isUploading;

  const ImageTrayStats({
    super.key,
    required this.items,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final queuedCount =
        items.where((item) => item.status == UploadStatus.queued).length;
    final uploadingCount =
        items.where((item) => item.status == UploadStatus.uploading).length;
    final successCount =
        items.where((item) => item.status == UploadStatus.success).length;
    final failedCount =
        items.where((item) => item.status == UploadStatus.failed).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library,
            size: 14,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            '${items.length}/9',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          if (queuedCount > 0) ...[
            const SizedBox(width: 8),
            _buildStatusChip('排隊', queuedCount, Colors.orange),
          ],
          if (uploadingCount > 0) ...[
            const SizedBox(width: 8),
            _buildStatusChip('上傳中', uploadingCount, Colors.blue),
          ],
          if (successCount > 0) ...[
            const SizedBox(width: 8),
            _buildStatusChip('成功', successCount, Colors.green),
          ],
          if (failedCount > 0) ...[
            const SizedBox(width: 8),
            _buildStatusChip('失敗', failedCount, Colors.red),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
