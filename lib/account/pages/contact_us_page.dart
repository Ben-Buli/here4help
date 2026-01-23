import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/api/support_event_api.dart';
import 'package:here4help/widgets/support_issue_dialog.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _activeSupport;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkActiveSupportCase();
  }

  Future<void> _checkActiveSupportCase() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 檢查是否有進行中的客服事件
      final response = await SupportEventApi.getSupportChatList();
      debugPrint('🔍 ContactUsPage: getSupportChatList 回應: $response');

      if (response['success'] == true && response['data'] != null) {
        final chatList = response['data']['chat_list'] as List?;
        debugPrint('🔍 ContactUsPage: 聊天室列表: $chatList');
        debugPrint('🔍 ContactUsPage: 聊天室數量: ${chatList?.length ?? 0}');

        // 尋找進行中的客服事件
        final activeCase = chatList?.firstWhere(
          (chat) {
            debugPrint('🔍 ContactUsPage: 檢查聊天室: $chat');
            debugPrint('🔍 ContactUsPage: 事件狀態: ${chat['event_status']}');
            return chat['event_status'] == 'submitted' ||
                chat['event_status'] == 'in_progress';
          },
          orElse: () => null,
        );

        debugPrint('🔍 ContactUsPage: 找到的活躍案例: $activeCase');

        setState(() {
          _activeSupport = activeCase;
          _isLoading = false;
        });

        // 如果有進行中的客服事件，直接跳轉到聊天室
        if (_activeSupport != null) {
          final roomId = _activeSupport!['room_id'];
          debugPrint('🚀 ContactUsPage: 發現活躍客服事件，準備導航到 roomId: $roomId');
          _navigateToSupportChat(roomId);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToSupportChat(dynamic roomId) {
    // 跳轉到客服聊天室
    final roomIdStr = roomId.toString();
    debugPrint(
        '🚀 ContactUsPage: 導航到客服聊天室, roomId: $roomIdStr (type: ${roomId.runtimeType})');
    debugPrint(
        '🚀 ContactUsPage: 導航 URL: /account/support/contact/chat?room_id=$roomIdStr');
    context.go('/account/support/contact/chat?room_id=$roomIdStr');
  }

  Future<void> _showSupportIssueDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const SupportIssueDialog(),
    );

    if (result != null) {
      // 建立客服事件
      await _createSupportIssue(result['title']!, result['description']!);
    }
  }

  Future<void> _createSupportIssue(String title, String description) async {
    try {
      setState(() => _isLoading = true);

      final response = await SupportEventApi.createIssue(
        title: title,
        description: description,
      );

      if (response['room_id'] != null) {
        final roomId = response['room_id'];
        debugPrint('✅ ContactUsPage: 客服事件建立成功');
        debugPrint(
            '✅ ContactUsPage: 收到 roomId: $roomId (type: ${roomId.runtimeType})');
        debugPrint('✅ ContactUsPage: 完整回應: $response');

        if (mounted) {
          // 先更新 loading 狀態
          setState(() => _isLoading = false);

          // 顯示成功消息
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Support case created successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // 延遲導航，讓用戶看到成功消息
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              _navigateToSupportChat(roomId);
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ??
                  'Failed to create support case: Invalid response'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading support status',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkActiveSupportCase,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // 沒有進行中的客服事件，顯示建立新事件的介面
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.support_agent,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'No issue pending at the moment',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Need help? Contact our support team and we\'ll get back to you as soon as possible.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showSupportIssueDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Contact Us',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
