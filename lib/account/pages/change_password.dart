import 'package:flutter/material.dart';
import 'package:here4help/services/api/password_api.dart';

class ChangePassword extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const ChangePassword({
    super.key,
    required this.onCancel,
    required this.onDone,
  });

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController currentController = TextEditingController();
  final TextEditingController newController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _showConfirmField = false;

  @override
  void dispose() {
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (currentController.text.isEmpty || newController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (!_showConfirmField) {
      setState(() {
        _showConfirmField = true;
        _errorMessage = null;
      });
      return;
    }

    if (confirmController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please confirm your new password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await PasswordApi.changePassword(
        currentPassword: currentController.text,
        newPassword: newController.text,
        confirmPassword: confirmController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDone();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 當前密碼和新密碼
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
              ),
            ),
          ],
        ),

        // 確認密碼欄位（條件顯示）
        if (_showConfirmField) ...[
          const SizedBox(height: 8),
          TextField(
            controller: confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
          ),
        ],

        // 錯誤訊息
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // 按鈕
        Row(
          children: [
            TextButton(
              onPressed: _isLoading ? null : widget.onCancel,
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_showConfirmField ? 'Change Password' : 'Next'),
            ),
          ],
        ),
      ],
    );
  }
}
