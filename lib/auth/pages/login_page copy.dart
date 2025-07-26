// login_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> _handleLogin(String email, String password) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final userService = Provider.of<UserService>(context, listen: false);
        userService.setUser(UserModel(
          id: responseData['id'] as int,
          name: responseData['name'] as String,
          email: responseData['email'] as String,
          points: responseData['points'] as int,
          primary_language: responseData['primary_language'] as String,
          permission_level: responseData['permission_level'] as int,
          avatar_url: responseData['avatar_url'] as String,
        ));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Success')),
        );

        context.go('/home');
      } else {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Logo
          Image.asset(
            'assets/icon/app_icon_bordered.png', // 替換為新的 logo 路徑
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 16),
          const Text(
            'Here4Help',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          // Account Input
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Account',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Password Input
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              _handleLogin(emailController.text, passwordController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 48), // 寬度 100%，高度 48
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // 圓角設計
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Login',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),
          // Sign Up Options
          const Divider(
            thickness: 1,
            height: 32,
          ),
          const Text(
            'SIGN UP WITH',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  // Google 登入功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google login pressed')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // 圓角設計
                  ),
                  minimumSize: const Size(double.infinity, 48), // 寬度 100%，高度 48
                ),
                child: const Text(
                  'Google',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Facebook 登入功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Facebook login pressed')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // 圓角設計
                  ),
                  minimumSize: const Size(double.infinity, 48), // 寬度 100%，高度 48
                ),
                child: const Text(
                  'Facebook',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Email 登入功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email login pressed')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // 圓角設計
                  ),
                  minimumSize: const Size(double.infinity, 48), // 寬度 100%，高度 48
                ),
                child: const Text(
                  'Email',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Apple 登入功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apple login pressed')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // 圓角設計
                  ),
                  minimumSize: const Size(double.infinity, 48), // 寬度 100%，高度 48
                ),
                child: const Text(
                  'Apple',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
