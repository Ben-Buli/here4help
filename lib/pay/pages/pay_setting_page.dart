// pay_setting_page.dart
import 'package:flutter/material.dart';

class PaySettingPage extends StatefulWidget {
  const PaySettingPage({super.key});

  @override
  State<PaySettingPage> createState() => _PaySettingPageState();
}

class _PaySettingPageState extends State<PaySettingPage> {
  String firstInput = '';
  String secondInput = '';
  bool confirmMode = false;

  void _handleKeyPress(String value) {
    setState(() {
      if (!confirmMode) {
        if (firstInput.length < 6) firstInput += value;
        if (firstInput.length == 6) confirmMode = true;
      } else {
        if (secondInput.length < 6) secondInput += value;
        if (secondInput.length == 6) {
          if (firstInput == secondInput) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment code set successfully')),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Codes do not match, try again.')),
            );
            firstInput = '';
            secondInput = '';
            confirmMode = false;
          }
        }
      }
    });
  }

  void _clear() {
    setState(() {
      if (!confirmMode) {
        firstInput = firstInput.isNotEmpty
            ? firstInput.substring(0, firstInput.length - 1)
            : '';
      } else {
        secondInput = secondInput.isNotEmpty
            ? secondInput.substring(0, secondInput.length - 1)
            : '';
      }
    });
  }

  Widget _buildDots(String code) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          6,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 16,
              height: 2,
              color: index < code.length ? Colors.black : Colors.black26,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final code = confirmMode ? secondInput : firstInput;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Code')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDots(code),
          GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            shrinkWrap: true,
            crossAxisCount: 3,
            children: [
              for (var i = 1; i <= 9; i++) _buildKey(i.toString()),
              _buildKey('0'),
              _buildKey('Clear'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildKey(String value) => GestureDetector(
        onTap: () => value == 'Clear' ? _clear() : _handleKeyPress(value),
        child: Container(
          margin: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value, style: const TextStyle(fontSize: 24)),
        ),
      );
}
