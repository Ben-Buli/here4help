import 'package:flutter/material.dart';
import 'package:here4help/account/pages/change_password.dart';
import 'package:here4help/services/api/account_api.dart';
import 'package:here4help/services/api/password_api.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:here4help/providers/permission_provider.dart';

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

  // 停用阻擋提示（點擊後回傳的即時結果）
  String? _deactivateInlineMessage;

  @override
  void initState() {
    super.initState();
    _checkRiskyActions();
  }

  Future<void> _checkRiskyActions() async {
    setState(() {
      isCheckingRiskyActions = true;
      errorMessage = null;
      // 重新檢查時清空點擊後的即時提示
      _deactivateInlineMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() {
          errorMessage = 'Not logged in';
        });
        return;
      }

      final result = await AccountApi.checkRiskyActions(token);
      if (result['success'] == true) {
        setState(() {
          riskyActionsData = result['data'];
        });
      } else {
        setState(() {
          errorMessage =
              result['message']?.toString() ?? 'Failed to check account status';
        });
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

  /// 暫停帳號風險狀態警告
  Widget _buildRiskyActionsWarning() {
    if (riskyActionsData == null) return const SizedBox.shrink();

    final hasActiveTasks = riskyActionsData!['has_active_tasks'] ?? false;
    final hasPostedTasks = riskyActionsData!['has_posted_open_tasks'] ?? false;
    final hasActiveChats = riskyActionsData!['has_active_chats'] ?? false;

    if (!hasActiveTasks && !hasPostedTasks && !hasActiveChats) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.tertiary),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.tertiaryContainer,
      ),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.onTertiaryContainer),
        title: Text(
          'Account Protection Warning',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onTertiaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasActiveTasks)
              Text('• You have active tasks',
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onTertiaryContainer)),
            if (hasPostedTasks)
              Text('• You have open posted tasks',
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onTertiaryContainer)),
            if (hasActiveChats)
              Text('• You have active chats',
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onTertiaryContainer)),
            const SizedBox(height: 8),
            Text(
              'Please complete or cancel all tasks before deactivating your account.',
              style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  bool _canDeactivateAccount() {
    if (isCheckingRiskyActions || riskyActionsData == null) {
      return false;
    }

    // 檢查是否已被管理員停權
    if (riskyActionsData!['permission'] == -1) {
      return false;
    }

    // 檢查是否已停用
    if (riskyActionsData!['permission'] == -3) {
      return false;
    }

    // 如果 API 沒有提供 can_deactivate 欄位，預設允許停用（容錯處理）
    return riskyActionsData!['can_deactivate'] ?? true;
  }

  Widget? _getDeactivateSubtitle() {
    if (_deactivateInlineMessage != null) {
      return Text(
        _deactivateInlineMessage!,
        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
      );
    }

    if (isCheckingRiskyActions) {
      return const Text('Checking account status...',
          style: TextStyle(color: Colors.grey));
    }

    if (riskyActionsData == null) {
      return const Text('Unable to check account status',
          style: TextStyle(color: Colors.grey));
    }

    // 檢查各種無法停用的情況
    if (riskyActionsData!['permission'] == -1) {
      return Text('Account suspended by administrator',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary));
    }

    if (riskyActionsData!['permission'] == -3) {
      return const Text('Account already deactivated',
          style: TextStyle(color: Colors.grey));
    }

    if (riskyActionsData!['can_deactivate'] == false) {
      return Text('Complete all active tasks first',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary));
    }

    return const Text('Temporarily disable your account',
        style: TextStyle(color: Colors.grey));
  }

  void _showDeactivateConfirmDialog() {
    _showAccountActionDialog(
      icon: Icons.pause_circle,
      iconColor: Theme.of(context).colorScheme.primary,
      title: 'Deactivate Account',
      content:
          'Are you sure you want to deactivate your account? You can reactivate it anytime from this page.',
      confirmText: 'Deactivate',
      confirmColor: Theme.of(context).colorScheme.primary,
      onConfirm: () {
        Navigator.of(context).pop();
        _deactivateAccount();
      },
    );
  }

  void _showReactivateConfirmDialog() {
    _showAccountActionDialog(
      icon: Icons.play_circle_fill,
      iconColor: Theme.of(context).colorScheme.tertiary,
      title: 'Reactivate Account',
      content: 'Are you sure you want to reactivate your account?',
      confirmText: 'Reactivate',
      confirmColor: Theme.of(context).colorScheme.tertiary,
      onConfirm: () {
        Navigator.of(context).pop();
        _reactivateAccount();
      },
    );
  }

  void _showAccountActionDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: onConfirm,
              style: TextButton.styleFrom(
                foregroundColor: confirmColor,
              ),
              child: Text(confirmText),
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
      _deactivateInlineMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Not logged in');
      }

      final prefs = await SharedPreferences.getInstance();
      final result = await AccountApi.deactivateAccount(token);

      if (result['success'] == true) {
        // 更新權限狀態
        final permissionProvider =
            Provider.of<PermissionProvider>(context, listen: false);
        permissionProvider.updatePermission(-3);

        // 更新本地權限狀態
        await prefs.setInt('permission', -3);

        // 重新檢查風險狀態
        await _checkRiskyActions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account deactivated successfully',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        final code = result['code'];
        if (code == 'E7010') {
          final data = (result['data'] ?? {}) as Map<String, dynamic>;
          final posted = (data['posted_open_tasks'] ?? 0) as int;
          final executing = (data['executing_tasks'] ?? 0) as int;
          String msg;
          if (posted > 0 && executing > 0) {
            msg =
                'You have $posted posted tasks and $executing executing tasks. Complete or cancel them first.';
          } else if (posted > 0) {
            msg = 'You have $posted posted tasks that are still open.';
          } else if (executing > 0) {
            msg = 'You have $executing executing tasks in progress.';
          } else {
            msg = 'You have active tasks. Complete or cancel them first.';
          }
          setState(() {
            _deactivateInlineMessage = msg;
          });
        } else {
          // 其他錯誤：顯示錯誤訊息
          final message =
              result['message']?.toString() ?? 'Failed to deactivate account';
          setState(() {
            errorMessage = message;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $message'),
                backgroundColor: Theme.of(context).colorScheme.error,
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Not logged in');
      }

      final prefs = await SharedPreferences.getInstance();
      final result = await AccountApi.reactivateAccount(token);
      if (result['success'] == true) {
        // 更新權限狀態
        final permissionProvider =
            Provider.of<PermissionProvider>(context, listen: false);
        permissionProvider.updatePermission(1);

        // 更新本地權限狀態
        await prefs.setInt('permission', 1);

        // 重新檢查風險狀態
        await _checkRiskyActions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account reactivated successfully',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        final code = result['code'];
        if (code == 'E2010') {
          setState(() {
            errorMessage = 'Account is not in a deactivated state';
          });
        } else {
          final message =
              result['message']?.toString() ?? 'Failed to reactivate account';
          setState(() {
            errorMessage = message;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $message'),
                backgroundColor: Theme.of(context).colorScheme.error,
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showConfirmDialog(String action, Future<void> Function() onConfirm) {
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
            onPressed: () async {
              Navigator.pop(context);
              await onConfirm();
            },
            child: const Text('sure'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      setState(() {
        isLoading = true;
      });

      // 使用 AuthService 執行登出
      await AuthService.logout();

      if (mounted) {
        // 顯示成功訊息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully logged out',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // 導航至登入頁面
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
              child: Icon(Icons.lock,
                  size: 60, color: Theme.of(context).colorScheme.scrim),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.scrim),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock,
                            color: Theme.of(context).colorScheme.scrim),
                        const SizedBox(width: 8),
                        const Text('Password',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (!editingPassword)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Change'),
                            onPressed: () =>
                                setState(() => editingPassword = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              elevation: 0,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!editingPassword)
                      Row(
                        children: [
                          Icon(Icons.security,
                              color: Theme.of(context).colorScheme.tertiary,
                              size: 16),
                          const SizedBox(width: 8),
                          const Text('Your password is protected',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    if (editingPassword)
                      ChangePassword(
                        onCancel: () => setState(() => editingPassword = false),
                        onDone: () => setState(() => editingPassword = false),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 登出按鈕
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: OutlinedButton.icon(
                  icon: Icon(Icons.logout,
                      color: Theme.of(context).colorScheme.tertiary),
                  label: Text('Log Out',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary)),
                  onPressed: () => _showConfirmDialog('log out', () async {
                    // 執行登出邏輯
                    await _performLogout();
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text('Account Protection',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.tertiary)),
            const SizedBox(height: 8),

            // 風險檢查狀態
            if (isCheckingRiskyActions)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                    child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.tertiary,
                )),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.tertiary),
                ),
              )
            else if (riskyActionsData != null)
              Column(
                children: [
                  _buildRiskyActionsWarning(),
                  const SizedBox(height: 12),
                ],
              ),

            // 停用/重新啟用帳號按鈕顯示邏輯
            if (riskyActionsData == null ||
                (riskyActionsData!['permission'] != -1 &&
                    riskyActionsData!['permission'] != -3))
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.secondary),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
                child: ListTile(
                  leading: Icon(Icons.pause_circle,
                      color: Theme.of(context).colorScheme.secondary),
                  title: Text('Deactivate Account',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      )),
                  subtitle: _getDeactivateSubtitle(),
                  onTap: _canDeactivateAccount()
                      ? () => _showDeactivateConfirmDialog()
                      : null,
                  trailing: _canDeactivateAccount()
                      ? Icon(Icons.arrow_forward_ios,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 16)
                      : Icon(Icons.lock,
                          color: Theme.of(context).colorScheme.scrim, size: 16),
                ),
              ),
            if (riskyActionsData != null &&
                riskyActionsData!['permission'] == -3)
              Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).colorScheme.tertiary),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                ),
                child: ListTile(
                  leading: Icon(Icons.play_circle_fill,
                      color: Theme.of(context).colorScheme.tertiary),
                  title: Text('Reactivate Account',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.bold,
                      )),
                  subtitle: Text(
                    'Reactivate your account to resume using the app',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary),
                  ),
                  onTap: () => _showReactivateConfirmDialog(),
                  trailing: Icon(Icons.arrow_forward_ios,
                      color: Theme.of(context).colorScheme.tertiary, size: 16),
                ),
              ),

            // 管理員停權提示
            if (riskyActionsData != null &&
                riskyActionsData!['permission'] == -1)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Suspended by Administrator',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your account has been suspended by an administrator. Please contact customer service for assistance.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // 導航至客服聯繫頁面
                            context.go('/account/support/contact');
                          },
                          child: const Text('Contact Support'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            // 危險操作區域
            Text('Danger Zone',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error,
                )),
            const SizedBox(height: 8),

            // 刪除帳號按鈕
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.error),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.errorContainer,
              ),
              child: ListTile(
                leading: Icon(Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Delete Account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    )),
                subtitle: Text(
                  'Permanently delete your account and all data',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _showDeleteAccountDialog(),
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

  void _showDeleteAccountDialog() {
    final TextEditingController confirmationController =
        TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    bool isDeleting = false;
    String? deleteError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  const Text('Delete Account'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This action cannot be undone. Your account and all associated data will be permanently deleted.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'To confirm deletion, please type "DELETE" (case-sensitive) in the field below:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmationController,
                      decoration: const InputDecoration(
                        // labelText: 'Type "DELETE" to confirm',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.keyboard),
                        hintText: 'DELETE',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        // labelText: 'Reason for deletion (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment),
                        hintText: 'Tell us why you\'re leaving...',
                      ),
                    ),
                    if (deleteError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.error),
                        ),
                        child: Text(
                          deleteError!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          confirmationController.dispose();
                          reasonController.dispose();
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          if (confirmationController.text != 'DELETE') {
                            setDialogState(() {
                              deleteError =
                                  'Please type "DELETE" exactly as shown to confirm';
                            });
                            return;
                          }

                          setDialogState(() {
                            isDeleting = true;
                            deleteError = null;
                          });

                          try {
                            await PasswordApi.deleteAccount(
                              password:
                                  confirmationController.text, // 傳遞 DELETE 作為確認
                              reason: reasonController.text.isEmpty
                                  ? null
                                  : reasonController.text,
                            );

                            if (mounted) {
                              // 更新權限狀態
                              final permissionProvider =
                                  Provider.of<PermissionProvider>(context,
                                      listen: false);
                              permissionProvider.clearPermission();

                              // 清除本地資料
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.clear();

                              // 顯示成功訊息並跳轉到登入頁面
                              if (mounted) {
                                final navigator = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                final router = GoRouter.of(context);

                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Account deleted successfully',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary)),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                );
                                router.go('/login');
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              deleteError =
                                  e.toString().replaceFirst('Exception: ', '');
                              isDeleting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  child: isDeleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onError),
                          ),
                        )
                      : const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
