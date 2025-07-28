// login_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/constants/demo_users.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final savedEmail = prefs.getString('remember_email') ?? '';
      final savedPass = prefs.getString('remember_password') ?? '';
      final savedFlag = prefs.getBool('remember_me') ?? false;

      if (savedFlag) {
        setState(() {
          emailController.text = savedEmail;
          passwordController.text = savedPass;
          rememberMe = savedFlag;
        });
      }
    });
  }

  Future<void> _handleLogin(String email, String password) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/auth/login'), // 替換為你的後端網址
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'Bearer $token');
        await prefs.setString('user_email', user['email']);
        await prefs.setInt('user_permission', user['permission'] ?? 0);
        await prefs.setString('user_name', user['name'] ?? '');
        await prefs.setInt('user_points', user['points'] ?? 0);
        await prefs.setString('user_avatarUrl', user['avatar_url'] ?? '');
        await prefs.setString(
            'user_primaryLang', user['primary_language'] ?? '');

        if (rememberMe) {
          await prefs.setString('remember_email', email);
          await prefs.setString('remember_password', password);
          await prefs.setBool('remember_me', true);
        } else {
          await prefs.remove('remember_email');
          await prefs.remove('remember_password');
          await prefs.setBool('remember_me', false);
        }

        Provider.of<UserService>(context, listen: false).setUser(UserModel(
          id: user['id'],
          name: user['name'],
          email: user['email'],
          points: user['points'] ?? 0,
          avatar_url: user['avatar_url'] ?? '',
          primary_language: user['primary_language'] ?? '',
          permission_level: user['permission'] ?? 0,
        ));

        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Success：$email')),
        );
        context.go('/home');
      } else {
        if (response.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Session expired, please login again')),
          );
          context.go('/login');
          return;
        }
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Login Failed: Invalid email or password')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Error: $e')),
      );
    }
  }

  Widget _buildSocialButton(IconData icon, String label) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(icon, color: Colors.black54),
            ),
            Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Image.asset(
                'assets/icon/app_icon_bordered.png',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 12),
              const Text(
                'Here4Help',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Account',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (value) {
                  setState(() {
                    rememberMe = value ?? false;
                  });
                },
              ),
              const Text('Remember me'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter both email and password')),
                  );
                  return;
                }
                _handleLogin(email, password);
              },
              child: const Text(
                'Login',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(thickness: 1),
          const SizedBox(height: 12),
          const Text(
            'SIGN UP WITH',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // 第三方登入按鈕
          Column(
            children: [
              _buildSocialButton(Icons.g_mobiledata, 'Google'),
              _buildSocialButton(Icons.facebook, 'Facebook'),
              _buildSocialButton(Icons.email, 'Email'),
              _buildSocialButton(Icons.apple, 'Apple'),
            ],
          ),
        ],
      ),
    );
  }
}
