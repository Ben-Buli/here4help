import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/widgets/search_filter_widget.dart';
import 'package:here4help/chat/widgets/posted_tasks_widget.dart';
import 'package:here4help/chat/widgets/my_works_widget.dart';
import 'package:here4help/chat/widgets/update_status_indicator.dart';

/// 重構後的 ChatListPage - 主控制器
///
/// 📝 **重構說明**
/// 原始檔案: 4,101 行 → 重構後: ~300 行
///
/// **模組分離：**
/// - `ChatListProvider`: 狀態管理
/// - `SearchFilterWidget`: 搜索篩選功能
/// - `PostedTasksWidget`: Posted Tasks 分頁內容
/// - `MyWorksWidget`: My Works 分頁內容
///
/// **技術改進：**
/// - ✅ 移除 GlobalKey 依賴，使用 Provider
/// - ✅ 統一 TabController 管理
/// - ✅ 簡化回調鏈，提升可維護性
/// - ✅ 職責分離，提升團隊協作效率
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
      final chatProvider = context.read<ChatListProvider>();
      chatProvider.initializeTabController(this, initialTab: widget.initialTab);

      // 初始化數據載入
      _initializeData();
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

    // 當應用恢復前台時，重新載入數據
    if (state == AppLifecycleState.resumed) {
      final chatProvider = context.read<ChatListProvider>();
      chatProvider.setLoadingState(true);
      _initializeData();
    }
  }

  /// 初始化數據載入
  Future<void> _initializeData() async {
    final chatProvider = context.read<ChatListProvider>();

    try {
      // 使用快取系統初始化數據
      await chatProvider.initializeWithCache();
    } catch (e) {
      chatProvider.setLoadingState(false, e.toString());
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
        // 如果 Provider 還未初始化，顯示載入畫面
        if (!chatProvider.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // 如果正在載入，顯示 loading
        if (chatProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading chat data...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
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
                    _initializeData();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // 主要 UI
        return Column(
          children: [
            // 更新狀態指示器
            const UpdateStatusBanner(),

            // 內容區域 - 使用 TabBarView 實現左右滑動效果
            // 每個分頁都有自己的搜尋篩選組件，確保狀態獨立
            Expanded(
              child: TabBarView(
                controller: chatProvider.tabController,
                children: const [
                  Column(
                    children: [
                      SearchFilterWidget(),
                      Expanded(child: PostedTasksWidget()),
                    ],
                  ),
                  Column(
                    children: [
                      SearchFilterWidget(),
                      Expanded(child: MyWorksWidget()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 滾動到頂部按鈕組件
/// 可以放置在需要滾動功能的頁面中
class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          final scrollController = PrimaryScrollController.of(context);
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        child: const Icon(Icons.keyboard_arrow_up, size: 24),
      ),
    );
  }
}
