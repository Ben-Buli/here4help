import 'package:flutter/material.dart';
import '../accessibility/accessible_text.dart';
import '../../services/accessibility/semantics_service.dart';

/// 載入狀態組件
/// 提供統一的載入狀態 UI 模板
class LoadingStateWidget extends StatelessWidget {
  final String? message;
  final bool showProgress;
  final double? progress;
  final Color? color;
  final double size;

  const LoadingStateWidget({
    Key? key,
    this.message,
    this.showProgress = false,
    this.progress,
    this.color,
    this.size = 40.0,
  }) : super(key: key);

  /// 預設的載入狀態樣式
  static const LoadingStateWidget loading = LoadingStateWidget(
    message: '載入中...',
  );

  static const LoadingStateWidget submitting = LoadingStateWidget(
    message: '提交中...',
  );

  static const LoadingStateWidget uploading = LoadingStateWidget(
    message: '上傳中...',
    showProgress: true,
  );

  static const LoadingStateWidget processing = LoadingStateWidget(
    message: '處理中...',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticsService = SemanticsService.instance;

    return semanticsService.annotateLoadingState(
      loadingMessage: message,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 載入指示器
            _buildLoadingIndicator(theme),

            // 載入訊息
            if (message != null) ...[
              const SizedBox(height: 16),
              AccessibleText(
                message!,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 進度指示器
            if (showProgress && progress != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color ?? theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AccessibleText(
                '${(progress! * 100).toInt()}%',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    if (showProgress && progress != null) {
      return CircularProgressIndicator(
        value: progress,
        strokeWidth: 3.0,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? theme.colorScheme.primary,
        ),
      );
    } else {
      return CircularProgressIndicator(
        strokeWidth: 3.0,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? theme.colorScheme.primary,
        ),
      );
    }
  }
}

/// 載入覆蓋層組件
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;
  final bool showProgress;
  final double? progress;

  const LoadingOverlay({
    Key? key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
    this.showProgress = false,
    this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: LoadingStateWidget(
              message: loadingMessage,
              showProgress: showProgress,
              progress: progress,
            ),
          ),
      ],
    );
  }
}

/// 骨架載入組件
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                theme.colorScheme.surfaceContainerHighest,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 骨架載入建構器
class SkeletonBuilder {
  static Widget buildTaskCardSkeleton() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLoader(width: double.infinity, height: 20),
            SizedBox(height: 8),
            SkeletonLoader(width: 200, height: 16),
            SizedBox(height: 12),
            Row(
              children: [
                SkeletonLoader(width: 60, height: 16),
                SizedBox(width: 16),
                SkeletonLoader(width: 80, height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildChatMessageSkeleton() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SkeletonLoader(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 100, height: 14),
                SizedBox(height: 4),
                SkeletonLoader(width: double.infinity, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildListSkeleton({int itemCount = 5}) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => buildTaskCardSkeleton(),
    );
  }
}
