// signup_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESSENTIAL INFORMATION')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField('First name'),
            _buildTextField('Last name'),
            _buildGenderSelector(),
            _buildTextField('Email'),
            _buildTextField('Phone number'),
            _buildTextField('Country'),
            Row(
              children: [
                const Expanded(child: Text('Address')),
                ElevatedButton(
                  onPressed: () => context.go('/pay/setting'),
                  child: const Text('Permanent'),
                ),
              ],
            ),
            _buildTextField('Password', obscure: true),
            _buildTextField('Date of Birth', hint: 'YYYY/MM/DD'),
            _buildTextField('Payment password', hint: 'Input six numbers'),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {String? hint, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        obscureText: obscure,
        keyboardType:
            obscure ? TextInputType.visiblePassword : TextInputType.text,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ChoiceChip(label: Text('Male'), selected: true),
        ChoiceChip(label: Text('Female'), selected: false),
        ChoiceChip(label: Text('Not to disclose'), selected: false),
      ],
    );
  }
}
