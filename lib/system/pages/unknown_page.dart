import 'package:flutter/material.dart';

class UnknownPage extends StatelessWidget {
  const UnknownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '頁面不存在',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
