// login_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';

// 測試帳號清單
const testAccounts = [
  {
    'name': 'Admin',
    'email': 'admin@nccu.test.tw',
    'password': 'admin1234',
    'permission': 99,
    'avatar': 'https://i.pravatar.cc/150?img=1',
  },
  {
    'name': 'Poster',
    'email': 'poster@nccu.test.tw',
    'password': 'user5678',
    'permission': 1, // 正式會員
    'avatar': 'https://i.pravatar.cc/150?img=2',
  },
  {
    'name': 'Tasker',
    'email': 'tasker@nccu.test.tw',
    'password': 'user5678',
    'permission': 1, // 正式會員
    'avatar': 'https://i.pravatar.cc/150?img=2',
  },
  {
    'name': 'Mike',
    'email': 'mike2002@nccu.test.tw',
    'password': 'user5678',
    'permission': 0, // 未審核會員
    'avatar': 'https://i.pravatar.cc/150?img=2',
  },
];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      emailController.text = prefs.getString('saved_email') ?? '';
      passwordController.text = prefs.getString('saved_password') ?? '';
      rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    await Future.delayed(const Duration(milliseconds: 400));

    final matchedAccount = testAccounts.firstWhere(
      (acc) => acc['email'] == email && acc['password'] == password,
      orElse: () => {},
    );

    if (matchedAccount.isNotEmpty) {
      // 使用 UserService 更新當前使用者
      final userService = Provider.of<UserService>(context, listen: false);
      userService.login(UserModel(
        id: matchedAccount['id'] as int? ?? 0,
        name: matchedAccount['name'] as String,
        email: matchedAccount['email'] as String,
        points: 0, // 假設 points 預設為 0
        avatar_url: matchedAccount['avatar'] as String,
        primary_language: 'English', // 假設 primary_language 預設為 English
        permission_level: matchedAccount['permission'] as int,
      ));

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Success：$email')),
      );

      if (kIsWeb) {
        print(
            '✅ Web Login Success：$email Auth Lv. ${matchedAccount['permission']}');
      }

      context.go('/home');
    } else {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Login Failed: Invalid email or password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: (bool? value) {
                    setState(() {
                      rememberMe = value ?? false;
                    });
                  },
                ),
                const Text('Remember'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleLogin,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: 32),
            const Text("Demo Account",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Column(
              children: testAccounts.map((account) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      emailController.text = account['email'] as String;
                      passwordController.text = account['password'] as String;
                      _handleLogin();
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              NetworkImage(account['avatar'] as String),
                          radius: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(account['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text(account['email'] as String,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
