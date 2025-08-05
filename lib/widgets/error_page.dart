import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_service.dart';
import 'package:here4help/widgets/theme_aware_components.dart';

class ErrorPage extends StatelessWidget {
  final Exception? error;
  final int? statusCode;

  const ErrorPage({super.key, this.error, this.statusCode});

  @override
  Widget build(BuildContext context) {
    final code =
        statusCode ?? (error?.toString().contains('404') == true ? 404 : null);

    String title;
    String message;
    IconData icon;

    switch (code) {
      case 404:
        title = '404 Not Found';
        message = 'Sorry, the page you are looking for does not exist.';
        icon = Icons.search_off;
        break;
      case 403:
        title = '403 Forbidden';
        message = 'You do not have permission to view this page.';
        icon = Icons.block;
        break;
      case 500:
        title = '500 Server Error';
        message = 'Oops! Something went wrong on our end.';
        icon = Icons.error_outline;
        break;
      default:
        title = 'Error';
        message = 'This page does not exist or is under maintenance.';
        icon = Icons.error;
    }

    // 將詳細錯誤輸出到 log，但不顯示在畫面
    if (error != null) {
      debugPrint('ErrorPage: $error');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 48,
              vertical: isMobile ? 32 : 64,
            ),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Consumer<ThemeService>(
              builder: (context, themeService, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: isMobile ? 64 : 96,
                        color: themeService.currentTheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 36,
                        fontWeight: FontWeight.bold,
                        color: themeService.currentTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeService.currentTheme.primary,
                        foregroundColor: themeService.currentTheme.onPrimary,
                        minimumSize: Size(isMobile ? 120 : 160, 48),
                      ),
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
