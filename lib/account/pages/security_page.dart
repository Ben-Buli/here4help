import 'package:flutter/material.dart';
import 'package:here4help/account/pages/change_password.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool editingPassword = false;

  void _showConfirmDialog(String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('Are you sure you want to $action?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('sure'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Icon(Icons.lock, size: 60, color: Colors.grey[400]),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text('Password',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (!editingPassword)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => setState(() => editingPassword = true),
              ),
          ],
        ),
        if (!editingPassword)
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text('********'),
          ),
        if (editingPassword)
          ChangePassword(
            onCancel: () => setState(() => editingPassword = false),
            onDone: () => setState(() => editingPassword = false),
          ),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Account Protection',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListTile(
          title: const Text('Deactivate Account',
              style: TextStyle(color: Colors.red)),
          onTap: () => _showConfirmDialog('deactivate your account', () {
            // TODO: 停用帳號邏輯
          }),
        ),
        ListTile(
          title: const Text('Delete Account',
              style: TextStyle(color: Colors.red)),
          onTap: () => _showConfirmDialog('delete your account', () {
            // TODO: 刪除帳號邏輯
          }),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => _showConfirmDialog('log out', () {
              // TODO: 登出邏輯
            }),
            child: const Text('log out', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}
