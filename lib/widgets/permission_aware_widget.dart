import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/permission_service.dart';
import 'package:here4help/providers/permission_provider.dart';

/// 權限感知元件包裝器
/// 根據用戶權限決定是否顯示子元件
class PermissionAwareWidget extends StatelessWidget {
  final int requiredPermission;
  final Widget child;
  final Widget? fallback;
  final String? permissionDeniedMessage;
  final bool showTooltip;

  const PermissionAwareWidget({
    super.key,
    required this.requiredPermission,
    required this.child,
    this.fallback,
    this.permissionDeniedMessage,
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionProvider>(
      builder: (context, permissionProvider, _) {
        final userPermission = permissionProvider.permission;

        // 檢查權限是否足夠
        if (PermissionService.canAccessPage(
            userPermission, requiredPermission)) {
          return child;
        }

        // 權限不足，顯示 fallback 或預設提示
        if (fallback != null) {
          return fallback!;
        }

        // 預設的權限不足提示
        return _buildPermissionDeniedWidget(context, userPermission);
      },
    );
  }

  Widget _buildPermissionDeniedWidget(
      BuildContext context, int userPermission) {
    final message = permissionDeniedMessage ??
        PermissionService.getFeaturePermissionDescription(
            _getFeatureFromPermission());

    if (showTooltip) {
      return Tooltip(
        message: message,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            size: 20,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Permission Required',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getFeatureFromPermission() {
    // 根據權限要求推測功能類型
    switch (requiredPermission) {
      case 1:
        return 'general';
      case 99:
        return 'admin';
      default:
        return 'unknown';
    }
  }
}

/// 權限感知按鈕
/// 根據用戶權限決定按鈕是否可用
class PermissionAwareButton extends StatelessWidget {
  final int requiredPermission;
  final VoidCallback? onPressed;
  final Widget child;
  final String? permissionDeniedMessage;
  final bool showDisabledState;

  const PermissionAwareButton({
    super.key,
    required this.requiredPermission,
    required this.onPressed,
    required this.child,
    this.permissionDeniedMessage,
    this.showDisabledState = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionProvider>(
      builder: (context, permissionProvider, _) {
        final userPermission = permissionProvider.permission;
        final hasPermission =
            PermissionService.canAccessPage(userPermission, requiredPermission);

        if (hasPermission) {
          return ElevatedButton(
            onPressed: onPressed,
            child: child,
          );
        }

        if (!showDisabledState) {
          return const SizedBox.shrink();
        }

        final message = permissionDeniedMessage ??
            PermissionService.getFeaturePermissionDescription(
                _getFeatureFromPermission());

        return Tooltip(
          message: message,
          child: ElevatedButton(
            onPressed: null, // 禁用按鈕
            child: child,
          ),
        );
      },
    );
  }

  String _getFeatureFromPermission() {
    switch (requiredPermission) {
      case 1:
        return 'general';
      case 99:
        return 'admin';
      default:
        return 'unknown';
    }
  }
}

/// 權限感知圖標按鈕
/// 根據用戶權限決定圖標按鈕是否可用
class PermissionAwareIconButton extends StatelessWidget {
  final int requiredPermission;
  final VoidCallback? onPressed;
  final Icon icon;
  final String? tooltip;
  final String? permissionDeniedMessage;
  final bool showDisabledState;

  const PermissionAwareIconButton({
    super.key,
    required this.requiredPermission,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.permissionDeniedMessage,
    this.showDisabledState = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionProvider>(
      builder: (context, permissionProvider, _) {
        final userPermission = permissionProvider.permission;
        final hasPermission =
            PermissionService.canAccessPage(userPermission, requiredPermission);

        if (hasPermission) {
          return IconButton(
            onPressed: onPressed,
            icon: icon,
            tooltip: tooltip,
          );
        }

        if (!showDisabledState) {
          return const SizedBox.shrink();
        }

        final message = permissionDeniedMessage ??
            PermissionService.getFeaturePermissionDescription(
                _getFeatureFromPermission());

        return Tooltip(
          message: message,
          child: IconButton(
            onPressed: null, // 禁用按鈕
            icon: icon,
            tooltip: tooltip,
          ),
        );
      },
    );
  }

  String _getFeatureFromPermission() {
    switch (requiredPermission) {
      case 1:
        return 'general';
      case 99:
        return 'admin';
      default:
        return 'unknown';
    }
  }
}
