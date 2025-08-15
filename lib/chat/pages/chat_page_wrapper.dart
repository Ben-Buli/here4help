import 'package:flutter/material.dart';
import 'package:here4help/chat/providers/chat_providers.dart';
import 'package:here4help/chat/pages/chat_list_page.dart';

/// Chat 頁面包裝器
/// 負責提供 ChatProviders 並包裝 ChatListPage
class ChatPageWrapper extends StatelessWidget {
  const ChatPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return ChatProviders(
      child: const ChatListPage(),
    );
  }
}
