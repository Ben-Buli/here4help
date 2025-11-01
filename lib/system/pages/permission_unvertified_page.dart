import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/providers/permission_provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:here4help/config/app_config.dart';
import 'package:intl/intl.dart';

class PermissionUnverifiedPage extends StatefulWidget {
  final String? message;
  final String? currentPath;

  const PermissionUnverifiedPage({
    super.key,
    this.message,
    this.currentPath,
  });

  @override
  State<PermissionUnverifiedPage> createState() =>
      _PermissionUnverifiedPageState();
}

class _PermissionUnverifiedPageState extends State<PermissionUnverifiedPage> {
  bool _isRefreshing = false;
  final String _refreshButtonText = 'Try Again';
  String _buttonText = 'Try Again';
  Color? _buttonBackgroundColor;
  Color? _buttonForegroundColor;
  Map<String, dynamic>? _verificationData;
  bool _isLoadingVerification = false;
  String? _verificationError;

  /// 重設按鈕樣式
  void _resetButtonStyle() {
    if (mounted) {
      setState(() {
        _buttonText = _refreshButtonText;
        _buttonBackgroundColor = null;
        _buttonForegroundColor = null;
        _isRefreshing = false;
      });
    }
  }

  Widget _buildContentByPermission(int permission) {
    switch (permission) {
      case 0:
        return _buildVerificationContent();
      case -1:
        return _buildRestrictedContent();
      case -2:
        return _buildSelfDeactivatedContent();
      default:
        return _buildGenericContent();
    }
  }

  Widget _buildVerificationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your registration is almost complete. Our team is reviewing the student ID you submitted. You will gain full access as soon as it is approved.',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildVerificationStatusCard(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoadingVerification ? null : _loadVerificationStatus,
            icon: _isLoadingVerification
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isLoadingVerification ? 'Refreshing...' : 'Refresh Status'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildRestrictedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMessageCard(
          icon: Icons.report_gmailerrorred,
          color: Colors.red,
          message:
              'Your account has been limited by an administrator. To restore access, please contact our support team for assistance.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/account/support/contact'),
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildSelfDeactivatedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMessageCard(
          icon: Icons.pause_circle_outline,
          color: Colors.orange,
          message:
              'You have temporarily deactivated your account. Visit Security Settings if you would like to enable your account again.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/account/security'),
            icon: const Icon(Icons.security),
            label: const Text('Open Security Settings'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildGenericContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMessageCard(
          icon: Icons.info_outline,
          color: Colors.blueGrey,
          message:
              'Your account does not have sufficient permissions to access this page. Please check your account status or try again later.',
        ),
        const SizedBox(height: 12),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleSmartBack(context),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Go Back'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    Color resolve(Color base, double opacity) {
      if (base is MaterialColor) {
        return base.shade100.withOpacity(opacity == 1 ? 1 : opacity);
      }
      return base.withOpacity(opacity);
    }

    Color resolveText(Color base) {
      if (base is MaterialColor) {
        return base.shade700;
      }
      return base;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolve(color, 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolve(color, 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: resolveText(color)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: resolveText(color),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard() {
    if (_isLoadingVerification) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          children: const [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 12),
            Expanded(
              child: Text('Checking the latest verification status...'),
            ),
          ],
        ),
      );
    }

    if (_verificationError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _verificationError!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
        ),
      );
    }

    if (_verificationData == null || _verificationData!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'We have not received a student ID submission yet. Please return to the onboarding flow to upload your document.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    final status =
        (_verificationData!['verification_status'] ?? 'pending').toString();
    final notes = _verificationData!['verification_notes']?.toString();
    final createdAt = _parseDate(_verificationData!['created_at']);
    final updatedAt = _parseDate(_verificationData!['updated_at']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            icon: Icons.verified_user,
            label: 'Current Status',
            value: _formatStatus(status),
          ),
          if (createdAt != null)
            _buildStatusRow(
              icon: Icons.file_upload,
              label: 'Submitted At',
              value: DateFormat.yMMMd().add_jm().format(createdAt),
            ),
          if (updatedAt != null)
            _buildStatusRow(
              icon: Icons.update,
              label: 'Last Updated',
              value: DateFormat.yMMMd().add_jm().format(updatedAt),
            ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notes,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(
      {required IconData icon,
      required String label,
      required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending Review';
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final permissionProvider =
          Provider.of<PermissionProvider>(context, listen: false);
      if (permissionProvider.permission == 0) {
        _loadVerificationStatus();
      }
    });
  }

  Future<void> _loadVerificationStatus() async {
    setState(() {
      _isLoadingVerification = true;
      _verificationError = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Token missing');
      }

      final response = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/api/auth/get-student-verification-status.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          setState(() {
            _verificationData =
                Map<String, dynamic>.from(decoded['data'] as Map);
          });
        } else {
          setState(() {
            _verificationData = null;
            _verificationError =
                decoded['message']?.toString() ?? 'No verification record found';
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to load verification status: $e');
      if (mounted) {
        setState(() {
          _verificationError =
              'Unable to load verification status. Please try again later.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVerification = false;
        });
      }
    }
  }

  /// 設置按鈕為成功狀態
  void _setButtonSuccess() {
    if (mounted) {
      setState(() {
        _buttonText = 'Success! Redirecting...';
        _buttonBackgroundColor = const Color.fromARGB(255, 89, 140, 91);
        _buttonForegroundColor = Colors.white;
        _isRefreshing = false;
      });
    }
  }

  /// 設置按鈕為失敗狀態
  void _setButtonError(String errorMessage) {
    if (mounted) {
      setState(() {
        _buttonText = '❌ $errorMessage';
        _buttonBackgroundColor = const Color.fromARGB(255, 180, 65, 56);
        _buttonForegroundColor = Colors.white;
        _isRefreshing = false;
      });
    }
  }

  /// 手動刷新用戶資訊和權限
  Future<void> _refreshUserData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _buttonText = 'Updating...';
    });

    try {
      // 1. 刷新 UserService 中的用戶資料
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.refreshUserInfo();

      // 2. 刷新 PermissionProvider 中的權限狀態
      final permissionProvider =
          Provider.of<PermissionProvider>(context, listen: false);

      // 如果用戶資料刷新成功，同步權限狀態
      if (userService.currentUser != null) {
        permissionProvider
            .updatePermission(userService.currentUser!.permission);

        // 檢查權限是否已經足夠，如果是則自動返回到被阻擋的頁面
        if (userService.currentUser!.permission > 0) {
          _setButtonSuccess();

          // 延遲一下讓用戶看到成功訊息，然後返回
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _returnToBlockedPage(context);
          }
          return;
        }
      }

      // 如果權限仍然不足，顯示更新完成訊息
      _setButtonError('No permission change');

      // 3秒後重設按鈕樣式
      await Future.delayed(const Duration(seconds: 3));
      _resetButtonStyle();
    } catch (e) {
      debugPrint('❌ 刷新用戶資料失敗: $e');
      _setButtonError('Update failed');

      // 3秒後重設按鈕樣式
      await Future.delayed(const Duration(seconds: 3));
      _resetButtonStyle();
    }
  }

  /// 返回到被阻擋的頁面（用戶原本想要進入的頁面）
  void _returnToBlockedPage(BuildContext context) {
    final state = GoRouterState.of(context);
    final blockedPath = state.uri.queryParameters['blocked']; // 被阻擋的頁面
    final fromPath = state.uri.queryParameters['from']; // 來源頁面

    debugPrint('🔍 [PermissionUnverified] 當前 URL: ${state.uri}');
    debugPrint('🔍 [PermissionUnverified] 查詢參數: ${state.uri.queryParameters}');
    debugPrint('🔙 [PermissionUnverified] blocked 參數: $blockedPath');
    debugPrint('🔙 [PermissionUnverified] from 參數: $fromPath');

    // 優先使用 blocked 參數，其次使用 from 參數
    final targetPath = blockedPath ?? fromPath;

    if (targetPath != null &&
        targetPath.isNotEmpty &&
        targetPath != '/permission-unverified') {
      debugPrint('🔙 導航到目標頁面: $targetPath');
      context.go(targetPath);
    } else {
      // 如果沒有有效的目標頁面，返回首頁
      debugPrint('🔙 沒有有效的目標頁面資訊，返回首頁');
      context.go('/home');
    }
  }

  /// 智能返回邏輯
  /// 優先返回用戶之前訪問的頁面，如果沒有則返回首頁
  void _handleSmartBack(BuildContext context) {
    final state = GoRouterState.of(context);
    final fromPath = state.uri.queryParameters['from']; // 真正的上一頁
    final blockedPath = state.uri.queryParameters['blocked']; // 被阻擋的頁面

    debugPrint('🔙 智能返回: fromPath=$fromPath, blockedPath=$blockedPath');

    if (fromPath != null && fromPath.isNotEmpty) {
      // 檢查上一頁是否為基本頁面（permission = 0）
      if (_isBasicPage(fromPath)) {
        debugPrint('🔙 返回到基本頁面: $fromPath');
        context.go(fromPath);
        return;
      }
    }

    // 如果沒有有效的上一頁，返回首頁
    debugPrint('🔙 返回到首頁');
    context.go('/home');
  }

  /// 檢查是否為基本頁面（permission = 0）
  bool _isBasicPage(String path) {
    final basicPages = ['/home', '/account', '/task'];
    return basicPages.contains(path);
  }

  @override
  Widget build(BuildContext context) {
    // 從 Provider 獲取用戶權限狀態
    final permissionProvider =
        Provider.of<PermissionProvider>(context, listen: false);
    final userPermission = permissionProvider.permission;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom -
                48,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 403 圖示
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.notifications_active,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.04),

              // 標題
              Text(
                'User Unverified',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.02),

              SizedBox(height: MediaQuery.of(context).size.height * 0.03),

              _buildContentByPermission(userPermission),
            ],
          ),
        ),
      ),
    );
  }
}
