import 'package:flutter/material.dart';
import 'package:here4help/services/auth_error_handler.dart';

/// 全局錯誤處理 Widget
///
/// 包裝在應用程式的根部，用於捕獲和處理未被捕獲的錯誤
/// 特別針對 Token 過期錯誤提供統一處理
///
/// 使用方法：
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return GlobalErrorHandler(
///     child: MaterialApp(...),
///   );
/// }
/// ```
class GlobalErrorHandler extends StatelessWidget {
  final Widget child;
  final void Function(FlutterErrorDetails)? onFlutterError;
  final void Function(Object, StackTrace)? onPlatformError;

  const GlobalErrorHandler({
    super.key,
    required this.child,
    this.onFlutterError,
    this.onPlatformError,
  });

  @override
  Widget build(BuildContext context) {
    return _GlobalErrorWrapper(
      onFlutterError: onFlutterError,
      onPlatformError: onPlatformError,
      child: child,
    );
  }
}

class _GlobalErrorWrapper extends StatefulWidget {
  final Widget child;
  final void Function(FlutterErrorDetails)? onFlutterError;
  final void Function(Object, StackTrace)? onPlatformError;

  const _GlobalErrorWrapper({
    required this.child,
    this.onFlutterError,
    this.onPlatformError,
  });

  @override
  State<_GlobalErrorWrapper> createState() => _GlobalErrorWrapperState();
}

class _GlobalErrorWrapperState extends State<_GlobalErrorWrapper> {
  ErrorWidgetBuilder? _originalErrorWidgetBuilder;

  @override
  void initState() {
    super.initState();
    _setupGlobalErrorHandling();
  }

  @override
  void dispose() {
    _restoreOriginalErrorHandling();
    super.dispose();
  }

  void _setupGlobalErrorHandling() {
    // 保存原始的錯誤處理器
    _originalErrorWidgetBuilder = ErrorWidget.builder;

    // 設置自定義的 Flutter 錯誤處理
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
      widget.onFlutterError?.call(details);
    };

    // 設置自定義的錯誤 Widget 構建器
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _buildErrorWidget(details);
    };
  }

  void _restoreOriginalErrorHandling() {
    // 恢復原始的錯誤處理器
    if (_originalErrorWidgetBuilder != null) {
      ErrorWidget.builder = _originalErrorWidgetBuilder!;
    }
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // 檢查是否為 Token 過期相關錯誤
    final error = details.exception;
    if (AuthErrorHandler.isTokenExpiredError(error)) {
      debugPrint('🚨 [GlobalErrorHandler] 捕獲到 Token 過期錯誤');

      // 異步處理 Token 過期
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AuthErrorHandler.handleTokenExpiry(
          reason: 'Global Flutter error: ${error.toString()}',
        );
      });
    } else {
      // 記錄非 Token 過期的錯誤
      debugPrint('❌ [GlobalErrorHandler] Flutter 錯誤: $error');
      if (details.stack != null) {
        debugPrint('📍 [GlobalErrorHandler] 堆疊追蹤:\n${details.stack}');
      }
    }
  }

  Widget _buildErrorWidget(FlutterErrorDetails details) {
    final error = details.exception;

    // 如果是 Token 過期錯誤，顯示友善的錯誤頁面
    if (AuthErrorHandler.isTokenExpiredError(error)) {
      return _TokenExpiredErrorWidget(error: error);
    }

    // 其他錯誤使用預設的錯誤 Widget 或自定義錯誤頁面
    return _buildGenericErrorWidget(details);
  }

  Widget _buildGenericErrorWidget(FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  '發生了一些問題',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '錯誤: ${details.exception}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // 嘗試重新啟動應用或返回首頁
                    // 這裡可以添加重啟邏輯
                  },
                  child: const Text('重新開始'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Token 過期錯誤專用 Widget
class _TokenExpiredErrorWidget extends StatelessWidget {
  final Object error;

  const _TokenExpiredErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_clock,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Session expired',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please log in again to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    AuthErrorHandler.handleTokenExpiry(
                      reason: 'User clicked re-login button',
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Go to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error details: ${error.toString()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
