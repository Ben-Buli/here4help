import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/widgets/search_filter_widget.dart';
import 'package:here4help/chat/widgets/posted_tasks_widget.dart';
import 'package:here4help/chat/widgets/my_works_widget.dart';
import 'package:here4help/chat/widgets/update_status_indicator.dart';

/// 重構後的 ChatListPage - 專注於頁面結構和 Tab 管理
///
/// 📝 **重構說明**
/// 原始檔案: 4,101 行 → 重構後: ~150 行
///
/// **職責分離：**
/// - `ChatListPage`: 頁面結構、Tab 管理、生命週期
/// - `ChatListProvider`: 狀態管理和數據協調
/// - `SearchFilterWidget`: 搜索篩選功能
/// - `PostedTasksWidget`: Posted Tasks 分頁內容（自包含）
/// - `MyWorksWidget`: My Works 分頁內容（自包含）
///
/// **技術改進：**
/// - ✅ 移除重複的觸控板處理（由各分頁組件自行處理）
/// - ✅ 移除重複的數據載入邏輯（由 Provider 和各分頁組件處理）
/// - ✅ 專注於頁面結構和 Tab 管理
/// - ✅ 簡化生命週期管理
/// - ✅ 移除未使用的組件
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    // 初始化 ChatListProvider 的 TabController
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final chatProvider = context.read<ChatListProvider>();
      chatProvider.initializeTabController(this, initialTab: widget.initialTab);
    });

    // 添加應用生命週期監聽
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 當應用恢復前台時，重新載入當前分頁的數據
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;

      final chatProvider = context.read<ChatListProvider>();
      final currentTab = chatProvider.currentTabIndex;

      // 檢查當前分頁是否需要重新載入
      if (!chatProvider.isTabLoaded(currentTab)) {
        debugPrint('🔄 [ChatListPage] 應用恢復前台，重新載入分頁 $currentTab 數據');
        chatProvider.checkAndTriggerTabLoad(currentTab);
      }
    }
  }

  /// 公開的 tab 切換方法，供外部調用
  void switchTab(int index) {
    if (!mounted) return;
    final chatProvider = context.read<ChatListProvider>();
    chatProvider.switchTab(index);
  }

  /// 獲取當前選中的 tab 索引（保持向後兼容）
  int get currentTabIndex {
    final chatProvider = context.read<ChatListProvider>();
    return chatProvider.currentTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatListProvider>(
      builder: (context, chatProvider, child) {
        // 嘗試從外層取得 DefaultTabController 並與 Provider 同步
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final external = DefaultTabController.maybeOf(context);
          if (external != null) {
            chatProvider.registerExternalTabController(external);
          }
        });

        // 上層已提供 Scaffold/AppBar/TabBar
        // 僅回傳頁面主要內容（包含 UpdateStatusBanner 與 TabBarView）
        return _buildBody(chatProvider);
      },
    );
  }

  /// 構建主體內容
  Widget _buildBody(ChatListProvider chatProvider) {
    // 如果 Provider 還未初始化，顯示載入畫面
    if (!chatProvider.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 如果有錯誤，顯示錯誤
    if (chatProvider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading data'),
            const SizedBox(height: 8),
            Text(
              chatProvider.errorMessage!,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // 觸發 Provider 的錯誤恢復機制
                chatProvider.clearAllTabErrors();
                chatProvider
                    .checkAndTriggerTabLoad(chatProvider.currentTabIndex);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 主要 UI：依外層 DefaultTabController（若有）或 Provider 的索引來切換內容
    final external = DefaultTabController.maybeOf(context);
    final currentIndex = external?.index ?? chatProvider.currentTabIndex;

    Widget bodyForIndex(int index) {
      switch (index) {
        case 0:
          return const Column(
            children: [
              SearchFilterWidget(),
              Expanded(child: PostedTasksWidget()),
            ],
          );
        case 1:
          return const Column(
            children: [
              SearchFilterWidget(),
              Expanded(child: MyWorksWidget()),
            ],
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return Column(
      children: [
        const UpdateStatusBanner(),
        Expanded(child: bodyForIndex(currentIndex)),
      ],
    );
  }
}
