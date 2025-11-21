import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/constants/shell_pages.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 過濾出 group 為 'support' 的路由
    final supportRoutes = shellPages.where((page) {
      final path = page['path'] as String;
      return path.startsWith('/account/support/') &&
          path != '/account/support/contact/chat';
    }).toList();

    return ListView.builder(
      itemCount: supportRoutes.length,
      itemBuilder: (context, index) {
        final route = supportRoutes[index];
        final path = route['path'] as String;

        // 從 shell_pages 設定的 icon 中取得 IconData
        final iconData = route['icon'];
        final trailingIcon = iconData is IconData
            ? Icon(iconData)
            : const Icon(Icons.help_outline); // 預設 Icon

        return Column(
          children: [
            ListTile(
              leading: trailingIcon,
              title: Text(route['title'] as String), // 使用 shellPages 中的 title
              onTap: () => context.go(path), // 使用完整的 path
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}
