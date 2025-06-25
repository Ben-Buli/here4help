import 'package:flutter/material.dart';

class BannedPage extends StatelessWidget {
  const BannedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '你的帳號已被封鎖或暫停使用，請聯絡客服處理。',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
