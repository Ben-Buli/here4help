import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/api/oauth_api.dart';
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
  String? oauthToken;
  String? tempTokenExpiresAt;
  bool isLoading = false;
  String? selectedSchool;
  String? selectedPrimaryLanguage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOAuthData();
    });
  }

  Future<void> _loadOAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      Map<String, String> queryParams = {};
      try {
        queryParams = GoRouterState.of(context).uri.queryParameters;
      } catch (_) {
        queryParams = Uri.base.queryParameters;
      }

      final queryToken = queryParams['token'] ?? queryParams['oauth_token'];
      final queryProvider = queryParams['provider'];
      final queryExpires =
          queryParams['expires_at'] ?? queryParams['temp_expires_at'];

      if (queryProvider != null && queryProvider.isNotEmpty) {
        await prefs.setString('signup_provider', queryProvider);
      }
      if (queryToken != null && queryToken.isNotEmpty) {
        await prefs.setString('signup_oauth_token', queryToken);
      }
      if (queryExpires != null && queryExpires.isNotEmpty) {
        await prefs.setString('signup_oauth_token_expires_at', queryExpires);
      }

      final resolvedToken = (queryToken != null && queryToken.isNotEmpty)
          ? queryToken
          : prefs.getString('signup_oauth_token');

      setState(() {
        fullNameController.text = prefs.getString('signup_full_name') ?? '';
        nicknameController.text = prefs.getString('signup_nickname') ?? '';
        emailController.text = prefs.getString('signup_email') ?? '';
        avatarUrl = prefs.getString('signup_avatar_url');
        provider = queryProvider ?? prefs.getString('signup_provider');
        providerUserId = prefs.getString('signup_provider_user_id');
        oauthToken = resolvedToken;
        tempTokenExpiresAt =
            queryExpires ?? prefs.getString('signup_oauth_token_expires_at');
      });

      debugPrint('📱 載入 OAuth 資料:');
      debugPrint('  👤 姓名: ${fullNameController.text}');
      debugPrint('  📧 Email: ${emailController.text}');
      debugPrint('  🔗 提供者: $provider');
      debugPrint('  🆔 提供者用戶ID: $providerUserId');
      debugPrint('  🖼️ 頭像: $avatarUrl');
      debugPrint(
          '  🔑 OAuth Token: ${oauthToken != null ? oauthToken!.substring(0, oauthToken!.length > 8 ? 8 : oauthToken!.length) + '...' : '無'}');

      if (resolvedToken != null && resolvedToken.isNotEmpty) {
        await _fetchTempUserData(resolvedToken);
      }
    } catch (e) {
      debugPrint('❌ 載入 OAuth 資料失敗: $e');
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _handleOAuthSignup();
    }
  }

  Future<void> _handleOAuthSignup() async {
    if (oauthToken == null || oauthToken!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暫存登入資料已失效，請重新以第三方帳戶登入'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      debugPrint('🚀 開始 OAuth 註冊流程...');

      final signupData = <String, dynamic>{
        'oauth_token': oauthToken,
        'name': fullNameController.text.trim(),
        'nickname': nicknameController.text.trim(),
        'phone': phoneController.text.trim(),
        'intro_referral_code': referralCodeController.text.trim(),
        'primary_language':
            (selectedPrimaryLanguage ?? 'English').trim().isEmpty
                ? 'English'
                : (selectedPrimaryLanguage ?? 'English').trim(),
        'school': selectedSchool,
        'avatar_url': avatarUrl,
      };

      signupData.removeWhere((key, value) {
        if (key == 'oauth_token') return false;
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
        return false;
      });

      debugPrint('📦 註冊資料鍵值: ${signupData.keys.toList()}');

      final response = await http
          .post(
            Uri.parse(AppConfig.api('/auth/register-oauth.php')),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(signupData),
          )
          .timeout(const Duration(seconds: 30));

      final body = response.body;
      debugPrint('📥 OAuth 註冊回應狀態碼: ${response.statusCode}');
      final preview = body.length > 200 ? '${body.substring(0, 200)}...' : body;
      debugPrint('📥 OAuth 註冊回應內容: $preview');

      final decoded = jsonDecode(body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map && data['token'] != null && data['user'] is Map) {
          final token = data['token'] as String;
          final user = Map<String, dynamic>.from(data['user'] as Map);

          await AuthService.saveToken(token);
          await AuthService.saveUserData(user);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', user['email'] ?? '');
          await prefs.setInt('user_permission', user['permission'] ?? 0);
          await prefs.setString('user_name', user['name'] ?? '');
          await prefs.setInt('user_points', user['points'] ?? 0);
          await prefs.setString('user_avatarUrl', user['avatar_url'] ?? '');
          await prefs.setString(
              'user_primaryLang', user['primary_language'] ?? '');

          await _clearCachedOAuthSignupData(prefs);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('註冊成功！請繼續完成學生證驗證'),
              backgroundColor: Colors.green,
            ),
          );

          context.go('/signup/student-id');
          return;
        }

        throw Exception('註冊回應格式不正確');
      }

      final message = decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Registration failed';
      throw Exception(message);
    } catch (e) {
      debugPrint('❌ OAuth 註冊失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('註冊失敗: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _clearCachedOAuthSignupData(SharedPreferences prefs) async {
    await prefs.remove('signup_full_name');
    await prefs.remove('signup_nickname');
    await prefs.remove('signup_email');
    await prefs.remove('signup_avatar_url');
    await prefs.remove('signup_provider');
    await prefs.remove('signup_provider_user_id');
    await prefs.remove('signup_oauth_token');
    await prefs.remove('signup_oauth_token_expires_at');
  }

  Future<void> _fetchTempUserData(String token) async {
    try {
      final data = await OAuthApi.fetchTempUser(token);
      if (data == null) {
        debugPrint('⚠️ 無法取得 OAuth 暫存資料 (token: $token)');
        return;
      }

      final fetchedName = data['name']?.toString() ?? '';
      final fetchedEmail = data['email']?.toString() ?? '';
      String? fetchedAvatar = data['avatar_url']?.toString();
      final fetchedProvider = data['provider']?.toString() ?? provider;
      final fetchedProviderUserId =
          data['provider_user_id']?.toString() ?? providerUserId;

      if ((fetchedAvatar == null || fetchedAvatar.isEmpty) &&
          data['raw_data'] is Map) {
        final rawData = data['raw_data'] as Map;
        final tokenInfo = rawData['token_info'];
        if (tokenInfo is Map) {
          final picture = tokenInfo['picture'];
          if (picture is String && picture.isNotEmpty) {
            fetchedAvatar = picture;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        if (fetchedName.isNotEmpty) {
          fullNameController.text = fetchedName;
          if (nicknameController.text.trim().isEmpty ||
              nicknameController.text == fullNameController.text) {
            nicknameController.text = fetchedName;
          }
        }
        if (fetchedEmail.isNotEmpty) {
          emailController.text = fetchedEmail;
        }
        if (fetchedAvatar != null && fetchedAvatar.isNotEmpty) {
          avatarUrl = fetchedAvatar;
        }
        provider = fetchedProvider;
        providerUserId = fetchedProviderUserId;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('signup_full_name', fullNameController.text);
      await prefs.setString('signup_nickname', nicknameController.text);
      await prefs.setString('signup_email', emailController.text);
      if (avatarUrl != null && avatarUrl!.isNotEmpty) {
        await prefs.setString('signup_avatar_url', avatarUrl!);
      }
      if (provider != null && provider!.isNotEmpty) {
        await prefs.setString('signup_provider', provider!);
      }
      if (providerUserId != null && providerUserId!.isNotEmpty) {
        await prefs.setString('signup_provider_user_id', providerUserId!);
      }
    } catch (e) {
      debugPrint('❌ 取得 OAuth 暫存資料失敗: $e');
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
