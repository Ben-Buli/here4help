import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging && widget.onTabChanged != null) {
        widget.onTabChanged!(_tabController.index);
      }
    });
  }

  @override
  void didUpdateWidget(ChatListTaskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當外部傳入的 initialTab 改變時，同步更新內部狀態
    if (oldWidget.initialTab != widget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        // 使用主題配色
        final subtitleColor = themeManager.effectiveTheme.onSecondary;

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
            tabs: const [
              Tab(text: 'Posted Tasks'),
              Tab(text: 'My Works'),
            ],
          ),
        );
      },
    );
  }
}
