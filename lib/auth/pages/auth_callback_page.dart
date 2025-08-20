import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/third_party_auth_service.dart';
import '../../config/app_config.dart';

class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({Key? key}) : super(key: key);

  @override
  _AuthCallbackPageState createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  bool _isProcessing = true;
  String _status = '處理中...';
  String? _errorMessage;
  Map<String, dynamic>? _userData;
  String? _token;
  bool? _isNewUser;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // 獲取 URL 參數
      final uri = Uri.parse(html.window.location.href);
      final success = uri.queryParameters['success'] == 'true';
      final provider = uri.queryParameters['provider'] ?? '';
      final error = uri.queryParameters['error'] ?? '';

      print('🔐 OAuth 回調處理開始');
      print('   Provider: $provider');
      print('   Success: $success');
      print('   Error: $error');

      if (success) {
        // 處理登入成功
        await _handleLoginSuccess(uri);
      } else {
        // 處理登入失敗
        await _handleLoginError(error);
      }
    } catch (e) {
      print('❌ 回調處理錯誤: $e');
      setState(() {
        _isProcessing = false;
        _status = '處理失敗';
        _errorMessage = '回調處理時發生錯誤: $e';
      });
    }
  }

  Future<void> _handleLoginSuccess(Uri uri) async {
    try {
      setState(() {
        _status = '登入成功，正在處理...';
      });

      // 解析參數
      final token = uri.queryParameters['token'];
      final userDataStr = uri.queryParameters['user_data'];
      final isNewUserStr = uri.queryParameters['is_new_user'];

      if (token == null || userDataStr == null) {
        throw Exception('缺少必要的登入資訊');
      }

      // 解析用戶資料
      final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
      final isNewUser = isNewUserStr == 'true';

      print('✅ 登入成功');
      print('   Token: ${token.substring(0, 20)}...');
      print('   User ID: ${userData['id']}');
      print('   Name: ${userData['name']}');
      print('   Is New User: $isNewUser');

      // 儲存登入資訊
      await _saveLoginInfo(token, userData);

      setState(() {
        _isProcessing = false;
        _status = '登入成功！';
        _userData = userData;
        _token = token;
        _isNewUser = isNewUser;
      });

      // 延遲後重定向到主頁
      Future.delayed(const Duration(seconds: 2), () {
        _redirectToMainPage();
      });
    } catch (e) {
      print('❌ 登入成功處理失敗: $e');
      setState(() {
        _isProcessing = false;
        _status = '登入處理失敗';
        _errorMessage = '處理登入資訊時發生錯誤: $e';
      });
    }
  }

  Future<void> _handleLoginError(String error) async {
    print('❌ 登入失敗: $error');
    setState(() {
      _isProcessing = false;
      _status = '登入失敗';
      _errorMessage = error;
    });

    // 延遲後重定向到登入頁面
    Future.delayed(const Duration(seconds: 3), () {
      _redirectToLoginPage();
    });
  }

  Future<void> _saveLoginInfo(
      String token, Map<String, dynamic> userData) async {
    try {
      // 這裡應該調用 AuthService 來儲存登入資訊
      // 暫時使用簡單的本地儲存
      print('💾 儲存登入資訊...');

      // TODO: 整合 AuthService
      // await AuthService.saveLoginInfo(token, userData);

      print('✅ 登入資訊儲存成功');
    } catch (e) {
      print('❌ 儲存登入資訊失敗: $e');
      throw e;
    }
  }

  void _redirectToMainPage() {
    print('🔄 重定向到主頁...');
    // 重定向到主頁或儀表板
    html.window.location.href = '/home';
  }

  void _redirectToLoginPage() {
    print('🔄 重定向到登入頁面...');
    // 重定向到登入頁面
    html.window.location.href = '/login';
  }

  void _retryLogin() {
    print('🔄 重試登入...');
    // 重新導向到 Google 登入
    final thirdPartyAuth = ThirdPartyAuthService();
    thirdPartyAuth.signInWithProvider('google');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登入處理中'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  '請稍候，正在處理您的登入請求...',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // 成功狀態
                if (_userData != null) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.green,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '歡迎回來，${_userData!['name']}！',
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  if (_isNewUser == true) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '這是您第一次使用 Google 登入',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _redirectToMainPage,
                    child: const Text('前往主頁'),
                  ),
                ] else ...[
                  // 錯誤狀態
                  const Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.red,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _retryLogin,
                        child: const Text('重試登入'),
                      ),
                      OutlinedButton(
                        onPressed: _redirectToLoginPage,
                        child: const Text('返回登入頁面'),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
