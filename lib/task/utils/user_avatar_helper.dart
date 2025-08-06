import 'package:flutter/material.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:provider/provider.dart';

class UserAvatarHelper {
  /// 獲取用戶頭像圖片
  static ImageProvider? getAvatarImage(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    final avatarUrl = user?.avatar_url;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        return ImageHelper.getAvatarImage(avatarUrl);
      } catch (e) {
        debugPrint('❌ Avatar loading error: $e');
        return null;
      }
    }
    return null;
  }

  /// 獲取用戶頭像子組件（當沒有圖片時顯示的圖標）
  static Widget? getAvatarChild(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    final avatarUrl = user?.avatar_url;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Icon(
        Icons.person,
        color: Theme.of(context).primaryColor,
        size: 24,
      );
    }
    return null;
  }

  /// 獲取用戶名稱
  static String getUserName(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    return user?.name ?? 'Unknown User';
  }

  /// 獲取用戶暱稱
  static String getUserNickname(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    return user?.nickname ?? user?.name ?? 'Unknown User';
  }

  /// 檢查用戶是否有頭像
  static bool hasAvatar(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    final avatarUrl = user?.avatar_url;
    return avatarUrl != null && avatarUrl.isNotEmpty;
  }

  /// 獲取頭像 URL
  static String? getAvatarUrl(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    return user?.avatar_url;
  }

  /// 創建圓形頭像組件
  static Widget buildCircleAvatar({
    required BuildContext context,
    double radius = 24,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    final avatarImage = getAvatarImage(context);
    final avatarChild = getAvatarChild(context);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? theme.primary.withOpacity(0.1),
      backgroundImage: avatarImage,
      onBackgroundImageError: avatarImage != null
          ? (exception, stackTrace) {
              debugPrint('❌ Avatar loading error: $exception');
            }
          : null,
      child: avatarChild,
    );
  }

  /// 創建帶邊框的圓形頭像組件
  static Widget buildCircleAvatarWithBorder({
    required BuildContext context,
    double radius = 24,
    double borderWidth = 2,
    Color? borderColor,
    Color? backgroundColor,
  }) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    final avatarImage = getAvatarImage(context);
    final avatarChild = getAvatarChild(context);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? theme.primary,
          width: borderWidth,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? theme.primary.withOpacity(0.1),
        backgroundImage: avatarImage,
        onBackgroundImageError: avatarImage != null
            ? (exception, stackTrace) {
                debugPrint('❌ Avatar loading error: $exception');
              }
            : null,
        child: avatarChild,
      ),
    );
  }
}
