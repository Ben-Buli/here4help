import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/constants/shell_pages.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 過濾出 group 為 'support' 的路由
    final supportRoutes =
        shellPages.where((page) => page['group'] == 'support').toList();

    return ListView.builder(
      itemCount: supportRoutes.length,
      itemBuilder: (context, index) {
        final route = supportRoutes[index];
        final path = route['path'] as String;

        // 根據 path 設定對應的 Icon
        Icon trailingIcon;
        if (path.contains('contact')) {
          trailingIcon = const Icon(Icons.contact_mail);
        } else if (path.contains('faq')) {
          trailingIcon = const Icon(Icons.question_answer);
        } else if (path.contains('status')) {
          trailingIcon = const Icon(Icons.info);
        } else {
          trailingIcon = const Icon(Icons.help_outline); // 預設 Icon
        }

        return Column(
          children: [
            ListTile(
              title: Text(route['title'] as String), // 使用 shellPages 中的 title
              trailing: trailingIcon,
              onTap: () => context.go(path), // 使用完整的 path
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}
