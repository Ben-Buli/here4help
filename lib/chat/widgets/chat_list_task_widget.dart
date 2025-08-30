import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';

/// 聊天列表標題組件
/// - 主標題：Chats（較小字體，透明度 0.7 的白色 bold 字體）
/// - 次標題：Posted Tasks | My Works（較大字體，支援左右滑動切換）
class ChatListTaskWidget extends StatefulWidget {
  const ChatListTaskWidget({
    super.key,
    this.onTabChanged,
    this.initialTab = 0,
  });

  /// Tab 切換回調
  final Function(int)? onTabChanged;

  /// 初始選中的 tab
  final int initialTab;

  @override
  State<ChatListTaskWidget> createState() => _ChatListTaskWidgetState();
}

class _ChatListTaskWidgetState extends State<ChatListTaskWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Timer? _providerSyncRetryTimer;
  bool _isRegisteredWithProvider = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // 優先調用外部回調
        if (widget.onTabChanged != null) {
          widget.onTabChanged!(_tabController.index);
        } else {
          // 如果沒有外部回調，嘗試與 ChatListProvider 同步（如果可用）
          _syncWithProviderIfAvailable();
        }
      }
    });

    // 延遲註冊到 Provider（如果可用）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithProviderIfAvailable();
    });
  }

  /// 與 ChatListProvider 同步（如果可用）
  void _syncWithProviderIfAvailable() {
    final providerInstance = ChatListProvider.instance;
    if (providerInstance != null) {
      providerInstance.registerExternalTabController(_tabController);
      _isRegisteredWithProvider = true;
      // 與當前 Provider 的索引同步
      if (_tabController.index != providerInstance.currentTabIndex) {
        _tabController.animateTo(providerInstance.currentTabIndex);
      }
      // 完成後停止重試計時器
      _providerSyncRetryTimer?.cancel();
      _providerSyncRetryTimer = null;
    } else {
      // Provider 尚未初始化，啟動短期重試機制
      if (_providerSyncRetryTimer == null) {
        debugPrint('🔍 ChatListProvider.instance 尚未就緒，啟動重試');
        _providerSyncRetryTimer =
            Timer.periodic(const Duration(milliseconds: 200), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _syncWithProviderIfAvailable();
          if (_isRegisteredWithProvider) {
            timer.cancel();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _providerSyncRetryTimer?.cancel();
    _providerSyncRetryTimer = null;
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatListTaskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當外部傳入的 initialTab 改變時，同步更新內部狀態
    if (oldWidget.initialTab != widget.initialTab &&
        _tabController.index != widget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
  }

  // 移除重複的 dispose（上方已有擴充版本）

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        // 使用主題配色
        final subtitleColor = themeManager.effectiveTheme.onSecondary;
        // 移除未讀狀態檢查
        // final chatProvider = Provider.of<ChatListProvider?>(context);
        // final bool postedHasUnread = chatProvider?.hasUnreadForTab(0) ?? false;
        // final bool worksHasUnread = chatProvider?.hasUnreadForTab(1) ?? false;

        // 簡化的 tab 標籤構建函數，移除未讀紅點
        Widget buildTabLabel(String text) {
          return Text(text);
        }

        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.6, // 只佔 appbar 的 60% 寬度
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelPadding: EdgeInsets.zero, // 移除 tab 標籤的 padding
            indicatorPadding: EdgeInsets.zero, // 移除指示器的 padding
            dividerColor: Colors.transparent, // 移除分隔線
            indicatorColor: themeManager.effectiveTheme.secondary, // 移動的下滑線
            indicatorWeight: 2, // 下劃線高度
            labelColor: themeManager.effectiveTheme.accent, // 選中的 tab 使用亮色主題
            unselectedLabelColor:
                subtitleColor.withOpacity(0.6), // 未選中的 tab 保持原樣
            labelStyle: const TextStyle(
              fontSize: 16, // 選中的 tab 字體較大
              fontWeight: FontWeight.w400,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14, // 未選中的 tab 字體較小
              fontWeight: FontWeight.w300,
            ),
            tabs: [
              Tab(child: buildTabLabel('Post')),
              Tab(child: buildTabLabel('Expolore')),
            ],
          ),
        );
      },
    );
  }
}
