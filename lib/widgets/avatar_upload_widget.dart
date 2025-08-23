import 'package:flutter/material.dart';
import 'package:here4help/services/api/profile_api.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/services/media/cross_platform_image_service.dart';

class AvatarUploadWidget extends StatefulWidget {
  final String? currentAvatarUrl;
  final Function(String? newAvatarUrl)? onAvatarChanged;
  final double size;
  final bool enabled;
  final String? userName;

  const AvatarUploadWidget({
    super.key,
    this.currentAvatarUrl,
    this.onAvatarChanged,
    this.size = 120,
    this.enabled = true,
    this.userName,
  });

  @override
  State<AvatarUploadWidget> createState() => _AvatarUploadWidgetState();
}

class _AvatarUploadWidgetState extends State<AvatarUploadWidget> {
  bool _isUploading = false;
  String? _currentAvatarUrl;
  ImageResult? _selectedImage;
  final _imageService = CrossPlatformImageService();

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.currentAvatarUrl;
  }

  @override
  void didUpdateWidget(AvatarUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAvatarUrl != oldWidget.currentAvatarUrl) {
      setState(() {
        _currentAvatarUrl = widget.currentAvatarUrl;
      });
    }
  }

  /// 顯示選擇頭像來源的對話框
  Future<void> _showImageSourceDialog() async {
    if (!widget.enabled) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Avatar'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteAvatar();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 從相機選擇頭像
  Future<void> _pickFromCamera() async {
    try {
      final image = await _imageService.pickFromCamera(
        config: ImageValidationConfig.avatar,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        await _uploadAvatar(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('選擇相機圖片失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 從相簿選擇頭像
  Future<void> _pickFromGallery() async {
    try {
      final image = await _imageService.pickFromGallery(
        config: ImageValidationConfig.avatar,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        await _uploadAvatar(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('選擇相簿圖片失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 上傳頭像
  Future<void> _uploadAvatar(ImageResult image) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final result = await ProfileApi.uploadAvatar(image);

      if (result['success'] == true) {
        final newAvatarUrl = result['data']['avatar_url'] as String?;

        setState(() {
          _currentAvatarUrl = newAvatarUrl;
          _selectedImage = null; // 清除選中的圖片
        });

        if (widget.onAvatarChanged != null) {
          widget.onAvatarChanged!(newAvatarUrl);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('頭像上傳成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('頭像上傳失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  /// 刪除頭像
  Future<void> _deleteAvatar() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final result = await ProfileApi.deleteAvatar();

      if (result['success'] == true) {
        setState(() {
          _currentAvatarUrl = null;
        });

        if (widget.onAvatarChanged != null) {
          widget.onAvatarChanged!(null);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Delete failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete avatar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? _showImageSourceDialog : null,
      child: Stack(
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _buildAvatarContent(),
            ),
          ),
          if (widget.enabled)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    _isUploading ? Icons.hourglass_empty : Icons.camera_alt,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 16,
                  ),
                ),
              ),
            ),
          if (_isUploading)
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 建立頭像內容
  Widget _buildAvatarContent() {
    // 優先顯示選中的圖片（預覽）
    if (_selectedImage != null) {
      return Image(
        image: _imageService.createImageProvider(_selectedImage!),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      );
    }

    // 使用 ImageHelper 處理現有頭像圖片
    if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      final imageProvider = ImageHelper.getAvatarImage(_currentAvatarUrl);
      return Image(
        image: imageProvider,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // 錯誤處理：使用 ImageHelper 的錯誤處理
          ImageHelper.handleImageError(context, error, stackTrace);
          return _buildDefaultAvatar();
        },
      );
    }

    return _buildDefaultAvatar();
  }

  /// 計算頭像的初始字母
  String _computeInitials(String name) {
    if (name.isEmpty) return "?"; // 預防空字串
    return name.trim()[0].toUpperCase(); // 只取第一個字母
  }

  /// 建立預設頭像
  Widget _buildDefaultAvatar() {
    final initials = _computeInitials(widget.userName ?? '');
    return Container(
      width: widget.size,
      height: widget.size,
      color: Theme.of(context).colorScheme.primary,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initials,
            textAlign: TextAlign.center,
            style: TextStyle(
              // 使用較大的字體，交給 FittedBox 自動縮小以適配圓形
              fontSize: widget.size,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
