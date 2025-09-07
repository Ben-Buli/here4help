import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:here4help/chat/utils/avatar_cache_manager.dart';
import 'package:here4help/chat/widgets/task_card_components.dart';

/// 帶快取功能的頭像 Widget
/// 統一的頭像顯示組件，支援記憶體快取和錯誤處理
class CachedAvatarWidget extends StatefulWidget {
  final String? avatarPath;
  final String name;
  final double radius;
  final double fontSize;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const CachedAvatarWidget({
    super.key,
    required this.avatarPath,
    required this.name,
    this.radius = 20,
    this.fontSize = 14,
    this.backgroundColor,
    this.textStyle,
  });

  @override
  State<CachedAvatarWidget> createState() => _CachedAvatarWidgetState();
}

class _CachedAvatarWidgetState extends State<CachedAvatarWidget> {
  Uint8List? _imageData;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(CachedAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果頭像路徑改變，重新載入
    if (oldWidget.avatarPath != widget.avatarPath) {
      _loadAvatar();
    }
  }

  /// 載入頭像
  Future<void> _loadAvatar() async {
    if (!mounted) return;

    // 檢查是否為空路徑
    if (widget.avatarPath == null || widget.avatarPath!.isEmpty) {
      setState(() {
        _imageData = null;
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    // 檢查是否為已知失敗的 URL
    if (AvatarCacheManager.isFailedUrl(widget.avatarPath)) {
      setState(() {
        _imageData = null;
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    // 檢查是否已在快取中
    if (AvatarCacheManager.isCached(widget.avatarPath)) {
      final cachedData =
          await AvatarCacheManager.getAvatarData(widget.avatarPath);
      if (mounted && cachedData != null) {
        setState(() {
          _imageData = cachedData;
          _hasError = false;
          _isLoading = false;
        });
        return;
      }
    }

    // 開始載入
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final imageData =
          await AvatarCacheManager.getAvatarData(widget.avatarPath);

      if (mounted) {
        setState(() {
          _imageData = imageData;
          _hasError = imageData == null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [CachedAvatarWidget] 載入頭像失敗: ${widget.avatarPath}, 錯誤: $e');
      if (mounted) {
        setState(() {
          _imageData = null;
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.backgroundColor ?? TaskCardUtils.getAvatarColor(widget.name);

    // 如果正在載入，顯示載入指示器
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: backgroundColor,
        child: SizedBox(
          width: widget.radius * 0.6,
          height: widget.radius * 0.6,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      );
    }

    // 如果有圖片數據，顯示圖片
    if (_imageData != null && !_hasError) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: backgroundColor,
        backgroundImage: MemoryImage(_imageData!),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('❌ [CachedAvatarWidget] 圖片顯示錯誤: ${widget.avatarPath}');
          if (mounted) {
            setState(() {
              _hasError = true;
              _imageData = null;
            });
          }
        },
        child: _hasError ? _buildInitialsText() : null,
      );
    }

    // 顯示首字母頭像
    return _buildInitialsAvatar();
  }

  /// 建構首字母頭像
  Widget _buildInitialsAvatar() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor:
          widget.backgroundColor ?? TaskCardUtils.getAvatarColor(widget.name),
      child: _buildInitialsText(),
    );
  }

  /// 建構首字母文字
  Widget _buildInitialsText() {
    return Text(
      TaskCardUtils.getInitials(widget.name),
      style: widget.textStyle ??
          TextStyle(
            color: Colors.white,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// 快取頭像預載入服務
class AvatarPreloadService {
  /// 預載入聊天室中的所有頭像
  static Future<void> preloadChatAvatars(
      List<Map<String, dynamic>> chatItems) async {
    final avatarPaths = <String>[];

    for (final item in chatItems) {
      // 提取各種可能的頭像路徑
      final paths = [
        item['avatar']?.toString(),
        item['creator_avatar']?.toString(),
        item['applier_avatar']?.toString(),
        item['participant_avatar']?.toString(),
        item['chat_partner_avatar']?.toString(),
      ];

      for (final path in paths) {
        if (path != null && path.isNotEmpty && !avatarPaths.contains(path)) {
          avatarPaths.add(path);
        }
      }
    }

    if (avatarPaths.isNotEmpty) {
      debugPrint('🚀 [AvatarPreloadService] 開始預載入 ${avatarPaths.length} 個頭像');
      await AvatarCacheManager.preloadAvatars(avatarPaths);
      debugPrint('✅ [AvatarPreloadService] 頭像預載入完成');
    }
  }

  /// 預載入任務相關的頭像
  static Future<void> preloadTaskAvatars(
      List<Map<String, dynamic>> tasks) async {
    final avatarPaths = <String>[];

    for (final task in tasks) {
      // 任務創建者頭像
      final creatorAvatar = task['creator_avatar']?.toString();
      if (creatorAvatar != null && creatorAvatar.isNotEmpty) {
        avatarPaths.add(creatorAvatar);
      }

      // 應徵者頭像
      final applicants = task['applicants'];
      if (applicants is List) {
        for (final applicant in applicants) {
          if (applicant is Map<String, dynamic>) {
            final applierAvatar = applicant['applier_avatar']?.toString();
            if (applierAvatar != null && applierAvatar.isNotEmpty) {
              avatarPaths.add(applierAvatar);
            }
          }
        }
      }
    }

    // 去重
    final uniquePaths = avatarPaths.toSet().toList();

    if (uniquePaths.isNotEmpty) {
      debugPrint('🚀 [AvatarPreloadService] 開始預載入任務頭像 ${uniquePaths.length} 個');
      await AvatarCacheManager.preloadAvatars(uniquePaths);
      debugPrint('✅ [AvatarPreloadService] 任務頭像預載入完成');
    }
  }
}
