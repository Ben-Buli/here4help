import 'package:flutter/material.dart';

class ChatDetailPage extends StatelessWidget {
  const ChatDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Text(
                  "Hey, I am Joe a law student at NCCU. I can help you open an account at three o'clock on Wednesday afternoon. Is it convenient for you?"),
              SizedBox(height: 8),
              Text('👉 View Resume', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _actionButton(Icons.volume_off, 'Silence', () {}),
            _actionButton(Icons.article, 'Complaint', () {}),
            _actionButton(Icons.block, 'Block', () {}),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  static Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.black)),
        Text(label),
      ],
    );
  }
}
