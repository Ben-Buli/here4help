import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/utils/image_helper.dart';

class TaskPosterInfoCard extends StatelessWidget {
  const TaskPosterInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  final avatarImage = _getAvatarImage(context);
                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primary.withOpacity(0.1),
                    backgroundImage: avatarImage,
                    onBackgroundImageError: avatarImage != null
                        ? (exception, stackTrace) {
                            debugPrint('❌ Avatar loading error: $exception');
                          }
                        : null,
                    child: _getAvatarChild(context),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Provider.of<UserService>(context, listen: false)
                              .currentUser
                              ?.name ??
                          'Unknown Poster',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.onSurface,
                      ),
                    ),
                    Text(
                      'Task Creator',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  ImageProvider? _getAvatarImage(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    final avatarUrl = user?.avatar_url;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final imageProvider = ImageHelper.getAvatarImage(avatarUrl);
        return imageProvider;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Widget? _getAvatarChild(BuildContext context) {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    final avatarUrl = user?.avatar_url;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      final themeManager =
          Provider.of<ThemeConfigManager>(context, listen: false);
      final theme = themeManager.effectiveTheme;
      return Icon(
        Icons.person,
        color: theme.primary,
        size: 24,
      );
    }
    return null;
  }
}
