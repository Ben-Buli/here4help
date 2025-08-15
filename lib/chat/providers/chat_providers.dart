import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/services/chat_cache_manager.dart';

/// 聊天頁面的 Provider 配置
class ChatProviders extends StatelessWidget {
  final Widget child;
  
  const ChatProviders({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatCacheManager>(
          create: (context) => ChatCacheManager(),
        ),
      ],
      child: child,
    );
  }
}
