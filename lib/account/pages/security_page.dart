import 'package:flutter/material.dart';
import 'package:here4help/account/pages/change_password.dart';
import 'package:here4help/services/api/account_api.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool editingPassword = false;
  bool isLoading = false;
  bool isCheckingRiskyActions = false;
  Map<String, dynamic>? riskyActionsData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _checkRiskyActions();
  }

  Future<void> _checkRiskyActions() async {
    setState(() {
      isCheckingRiskyActions = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null) {
        final result = await AccountApi.checkRiskyActions(token);
        if (result['success'] == true) {
          setState(() {
            riskyActionsData = result['data'];
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to check account status: $e';
      });
    } finally {
      setState(() {
        isCheckingRiskyActions = false;
      });
    }
  }

  Widget _buildRiskyActionsWarning() {
    if (riskyActionsData == null) return const SizedBox.shrink();

    final hasActiveTasks = riskyActionsData!['has_active_tasks'] ?? false;
    final hasPostedTasks = riskyActionsData!['has_posted_open_tasks'] ?? false;
    final hasActiveChats = riskyActionsData!['has_active_chats'] ?? false;

    if (!hasActiveTasks && !hasPostedTasks && !hasActiveChats) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Account Protection Warning',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            if (hasActiveTasks)
              const Text('• You have active tasks in progress',
                  style: TextStyle(color: Colors.orange)),
            if (hasPostedTasks)
              const Text('• You have posted tasks that are still open',
                  style: TextStyle(color: Colors.orange)),
            if (hasActiveChats)
              const Text('• You have active chat conversations',
                  style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 8),
            const Text(
              'Please complete or cancel all tasks before deactivating your account.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivateConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Deactivate Account'),
          content: const Text(
            'Are you sure you want to deactivate your account? '
            'You can reactivate it anytime from this page.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deactivateAccount();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
  }

  void _showReactivateConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reactivate Account'),
          content: const Text(
            'Are you sure you want to reactivate your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reactivateAccount();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Reactivate'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deactivateAccount() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null) {
        final result = await AccountApi.deactivateAccount(token);
        if (result['success'] == true) {
          // 更新本地權限狀態
          await prefs.setInt('permission', -3);

          // 重新檢查風險狀態
          await _checkRiskyActions();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account deactivated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to deactivate account: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _reactivateAccount() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null) {
        final result = await AccountApi.reactivateAccount(token);
        if (result['success'] == true) {
          // 更新本地權限狀態
          await prefs.setInt('permission', 1);

          // 重新檢查風險狀態
          await _checkRiskyActions();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account reactivated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to reactivate account: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

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
    return Stack(
      children: [
        ListView(
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

            // 風險檢查狀態
            if (isCheckingRiskyActions)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (riskyActionsData != null)
              _buildRiskyActionsWarning(),

            // 停用帳號按鈕
            ListTile(
              title: const Text('Deactivate Account',
                  style: TextStyle(color: Colors.red)),
              subtitle: riskyActionsData != null &&
                      !riskyActionsData!['can_deactivate']
                  ? const Text('Complete all active tasks first',
                      style: TextStyle(color: Colors.orange))
                  : null,
              onTap: riskyActionsData != null &&
                      riskyActionsData!['can_deactivate']
                  ? () => _showDeactivateConfirmDialog()
                  : null,
            ),

            // 重新啟用帳號按鈕（如果已停用）
            if (riskyActionsData != null &&
                riskyActionsData!['permission'] == -3)
              ListTile(
                title: const Text('Reactivate Account',
                    style: TextStyle(color: Colors.green)),
                onTap: () => _showReactivateConfirmDialog(),
              ),

            // 管理員停權提示
            if (riskyActionsData != null &&
                riskyActionsData!['permission'] == -1)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Suspended by Administrator',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your account has been suspended by an administrator. Please contact customer service for assistance.',
                          style: TextStyle(color: Colors.orange),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // TODO: 打開客服聊天或聯繫方式
                          },
                          child: const Text('Contact Support'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => _showConfirmDialog('log out', () {
                  // TODO: 登出邏輯
                }),
                child:
                    const Text('log out', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
