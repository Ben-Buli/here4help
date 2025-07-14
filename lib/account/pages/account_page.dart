// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/constants/shell_pages.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final accountRoutes = shellPages.where((route) {
      final path = route['path'] as String?;
      if (path == null) return false;

      // 保證是以 /account/ 開頭的子路由
      if (!path.startsWith('/account/')) return false;

      // 拆解路徑層級
      final segments = path.split('/').where((e) => e.isNotEmpty).toList();

      // 只取 account 的第一層子路由 => 例如 /account/profile (2 段)
      return segments.length == 2 && segments[0] == 'account';
    }).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: accountRoutes.length,
            itemBuilder: (context, index) {
              final item = accountRoutes[index];
              final isLogout = item['title'] == 'Log Out';
              return ListTile(
                leading: Icon(
                  item['icon'],
                  color: isLogout ? Colors.red : null,
                ),
                title: Text(
                  item['title'],
                  style: TextStyle(
                    color: isLogout ? Colors.red : null,
                    fontWeight: isLogout ? FontWeight.bold : null,
                  ),
                ),
                tileColor: isLogout ? Colors.transparent : null,
                onTap: () async {
                  if (isLogout) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Log Out'),
                        content:
                            const Text('Are you sure you want to log out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Log Out'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      context.go(item['path']);
                    }
                  } else {
                    context.go(item['path']);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
