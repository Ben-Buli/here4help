import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:here4help/utils/image_helper.dart';

class OAuthSignupPage extends StatefulWidget {
  const OAuthSignupPage({super.key});

  @override
  State<OAuthSignupPage> createState() => _OAuthSignupPageState();
}

class _OAuthSignupPageState extends State<OAuthSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController referralCodeController = TextEditingController();

  String? avatarUrl;
  String? provider;
  String? providerUserId;
  bool isLoading = false;
  String? selectedSchool;
  String? selectedPrimaryLanguage;

  @override
  void initState() {
    super.initState();
    _loadOAuthData();
  }

  Future<void> _loadOAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        fullNameController.text = prefs.getString('signup_full_name') ?? '';
        nicknameController.text = prefs.getString('signup_nickname') ?? '';
        emailController.text = prefs.getString('signup_email') ?? '';
        avatarUrl = prefs.getString('signup_avatar_url');
        provider = prefs.getString('signup_provider');
        providerUserId = prefs.getString('signup_provider_user_id');
      });

      print('📱 載入 OAuth 資料:');
      print('  👤 姓名: ${fullNameController.text}');
      print('  📧 Email: ${emailController.text}');
      print('  🔗 提供者: $provider');
      print('  🆔 提供者用戶ID: $providerUserId');
      print('  🖼️ 頭像: $avatarUrl');
    } catch (e) {
      print('❌ 載入 OAuth 資料失敗: $e');
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _handleOAuthSignup();
    }
  }

  Future<void> _handleOAuthSignup() async {
    setState(() {
      isLoading = true;
    });

    try {
      print('🚀 開始 OAuth 註冊流程...');

      // 準備註冊資料
      final signupData = {
        'full_name': fullNameController.text.trim(),
        'nickname': nicknameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'referral_code': referralCodeController.text.trim(),
        'school': selectedSchool,
        'primary_language': selectedPrimaryLanguage,
        'avatar_url': avatarUrl,
        'provider': provider,
        'provider_user_id': providerUserId,
      };

      print('📦 註冊資料: $signupData');

      // 這裡應該調用後端 API 完成註冊
      // 暫時模擬成功回應
      await Future.delayed(const Duration(seconds: 2));

      // 清除暫存的 OAuth 資料
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('signup_full_name');
      await prefs.remove('signup_nickname');
      await prefs.remove('signup_email');
      await prefs.remove('signup_avatar_url');
      await prefs.remove('signup_provider');
      await prefs.remove('signup_provider_user_id');

      // 顯示成功訊息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('註冊成功！歡迎加入 Here4Help')),
      );

      // 跳轉到首頁
      context.go('/home');
    } catch (e) {
      print('❌ OAuth 註冊失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('註冊失敗: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('完成註冊 - ${provider?.toUpperCase() ?? '第三方'}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 頭像顯示
                  if (avatarUrl != null) ...[
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: ImageHelper.getAvatarImage(avatarUrl!),
                        onBackgroundImageError: (exception, stackTrace) {
                          print('❌ 頭像載入失敗: $exception');
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 歡迎訊息
                  Center(
                    child: Text(
                      '歡迎使用 $provider 登入！',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '請完成以下資料以完成註冊',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 姓名
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: '姓名 *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '請輸入姓名';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 暱稱
                  TextFormField(
                    controller: nicknameController,
                    decoration: const InputDecoration(
                      labelText: '暱稱',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '請輸入 Email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return '請輸入有效的 Email 格式';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 電話
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: '電話',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 推薦碼
                  TextFormField(
                    controller: referralCodeController,
                    decoration: const InputDecoration(
                      labelText: '推薦碼（選填）',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.card_giftcard),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 註冊按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: isLoading ? null : _submitForm,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              '完成註冊',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 說明文字
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              '註冊說明',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 您使用 $provider 登入，我們會自動建立帳號\n'
                          '• 請確認並補充您的個人資料\n'
                          '• 完成註冊後即可使用所有功能',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
