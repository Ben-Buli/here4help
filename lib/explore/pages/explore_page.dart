import 'package:flutter/material.dart';

class ExplorePage extends StatelessWidget {
  ExplorePage({super.key});
  final List<Map<String, String>> chatList = [
    {
      'name': 'Alice',
      'message': 'Hey, how are you?',
      'time': '10:30 AM',
    },
    {
      'name': 'Bob',
      'message': 'Let\'s catch up later!',
      'time': '09:15 AM',
    },
    {
      'name': 'Charlie',
      'message': 'Did you see the news?',
      'time': 'Yesterday',
    },
    {
      'name': 'Diana',
      'message': 'Happy Birthday!',
      'time': '2 days ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: chatList.length,
      itemBuilder: (context, index) {
        final chat = chatList[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(chat['name']![0]),
          ),
          title: Text(chat['name']!),
          subtitle: Text(chat['message']!),
          trailing: Text(chat['time']!),
          onTap: () {
            // Handle chat tap
          },
        );
      },
    );
  }
}
