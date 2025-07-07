// login_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/constants/demo_users.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';

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

    await Future.delayed(const Duration(milliseconds: 400));

    final matchedAccount = testAccounts.firstWhere(
      (acc) => acc['email'] == email && acc['password'] == password,
      orElse: () => {},
    );

    if (matchedAccount.isNotEmpty) {
      final userService = Provider.of<UserService>(context, listen: false);
      userService.setUser(
        UserModel(
          id: matchedAccount['id'] as int? ?? 0,
          name: matchedAccount['name'] as String,
          email: matchedAccount['email'] as String,
          points: matchedAccount['points'] as int,
          avatar_url: (matchedAccount['avatar_url'] ?? '') as String,
          primary_language:
              (matchedAccount['language_requirement'] ?? '') as String,
          permission_level: matchedAccount['permission'] as int,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', matchedAccount['email'] as String);
      await prefs.setInt(
          'user_permission', matchedAccount['permission'] as int);
      await prefs.setString('user_name', matchedAccount['name'] as String);
      await prefs.setInt('user_points', matchedAccount['points'] as int);
      await prefs.setString(
          'user_avatarUrl', (matchedAccount['avatar_url'] ?? '') as String);
      await prefs.setString('user_primaryLang',
          (matchedAccount['language_requirement'] ?? '') as String);

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Success：$email')),
      );

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          const Text("Demo Account",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("tap to login",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 10)),
          const SizedBox(height: 12),
          Column(
            children: testAccounts.map((account) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _handleLogin(
                      account['email'] as String,
                      account['password'] as String,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.primaries[
                                  (account['name']?.hashCode ?? 0) %
                                      Colors.primaries.length]
                              .withOpacity(0.8),
                          child: Text(
                            (account['name']?.toString().isNotEmpty == true)
                                ? account['name']!.toString()[0].toUpperCase()
                                : '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(account['name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text(account['email']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
