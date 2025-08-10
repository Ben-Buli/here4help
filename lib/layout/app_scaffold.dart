// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/notification_service.dart';
import 'dart:async';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/services/data_preload_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'dart:ui';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.showAppBar = true,
    this.centerTitle = true,
    this.showBottomNav = true,
    this.showBackArrow = false, // 返回鍵：預設不顯示
    this.actions, // 新增
  });

  final Widget child;
  final String? title;
  final Widget? titleWidget;
  final bool showAppBar;
  final bool centerTitle;
  final bool showBottomNav;
  final bool showBackArrow;
  final List<Widget>? actions;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  // 新增 route history
  final List<String> _routeHistory = [];
  // 新增不可返回的路由清單
  final Set<String> _nonReturnableRoutes = {
    '/task/create/preview',
    '/task/apply',
    '/chat/detail',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 檢查 Widget 是否仍然被掛載且可以安全存取 context
    if (!mounted) return;

    try {
      final raw = GoRouterState.of(context).uri.toString();
      final currentPath = _normalizeRoute(raw);

      if (currentPath.isNotEmpty) {
        if (_routeHistory.isEmpty || _routeHistory.last != currentPath) {
          _routeHistory.add(currentPath);
        }
      }
    } catch (e) {
      // 如果無法存取 GoRouterState，忽略這次更新
      // 這可能發生在 Widget 樹重建期間
      debugPrint('Failed to access GoRouterState: $e');
    }
  }

  void _handleBack() async {
    try {
      // 檢查是否在聊天室中，如果是，使用會話管理器的返回路徑
      if (await ChatSessionManager.isInChatRoom()) {
        final returnPath = await ChatSessionManager.getReturnPath();
        debugPrint('🔙 從聊天室返回到: $returnPath');
        await ChatSessionManager.clearCurrentChatSession(); // 清除會話
        context.go(returnPath);
        return;
      }

      // 原有的返回邏輯
      if (_routeHistory.length > 1) {
        // 找到最近的可返回路徑
        String? targetPath;
        int targetIndex = -1;

        for (int i = _routeHistory.length - 2; i >= 0; i--) {
          final previousPath = _routeHistory[i];

          if (!_nonReturnableRoutes.contains(previousPath)) {
            targetPath = previousPath;
            targetIndex = i;
            break;
          }
        }

        if (targetPath != null && targetIndex >= 0) {
          // 移除當前路徑和目標路徑之後的所有路徑
          _routeHistory.removeRange(targetIndex + 1, _routeHistory.length);
          context.go(targetPath);
        } else {
          Navigator.of(context).maybePop();
        }
      } else {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      // 備用方案
      debugPrint('❌ 返回操作失敗: $e');
      Navigator.of(context).maybePop();
    }
  }

  // 將完整 URI 正規化為純路徑（忽略 query 參數，支援 hash 路由）
  String _normalizeRoute(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      if (uri.fragment.isNotEmpty) {
        final frag = Uri.parse(
            uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}');
        return frag.path; // 例如 #/chat/detail?roomId=.. -> /chat/detail
      }
      return uri.path; // 例如 /chat/detail?roomId=.. -> /chat/detail
    } catch (_) {
      return uriString; // 解析失敗則原樣返回
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return themeManager.effectiveTheme.createGradientBlurredBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Scaffold(
                backgroundColor: Colors.transparent, // 讓 Scaffold 背景透明以顯示漸層
                appBar: widget.showAppBar
                    ? _buildGlassmorphismAppBar(themeManager)
                    : null,
                body: SafeArea(
                  top: true, // 總是為頂部添加安全區域，避免被瀏海遮住
                  bottom: !widget.showBottomNav,
                  child: widget.child,
                ),
                bottomNavigationBar: widget.showBottomNav
                    ? _buildGlassmorphismBottomNav(themeManager, context)
                    : null,
              ),
            ),
          ),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          blurRadius: 16.0,
        );
      },
    );
  }

  /// 創建毛玻璃效果的 AppBar
  PreferredSizeWidget _buildGlassmorphismAppBar(
      ThemeConfigManager themeManager) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: themeManager.appBarGradient
                    .map((c) => c.withOpacity(0.95))
                    .toList(),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: widget.centerTitle,
              leading: widget.showBackArrow && _canGoBack()
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: _getBackArrowColor(themeManager),
                      ),
                      onPressed: _handleBack,
                    )
                  : null,
              title: () {
                debugPrint('🔍 [AppScaffold] 構建 AppBar title');
                debugPrint(
                    '🔍 [AppScaffold] widget.titleWidget: ${widget.titleWidget?.runtimeType}');
                debugPrint('🔍 [AppScaffold] widget.title: ${widget.title}');

                return widget.titleWidget ??
                    Text(
                      widget.title ?? '',
                      style: TextStyle(
                        color: themeManager.appBarTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    );
              }(),
              actions: [
                ...?widget.actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 創建毛玻璃效果的 BottomNavigationBar
  Widget _buildGlassmorphismBottomNav(
      ThemeConfigManager themeManager, BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: themeManager.navigationBarBackground,
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            currentIndex: _getCurrentIndex(context),
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedItemColor: themeManager.navigationBarSelectedColor,
            unselectedItemColor: themeManager.navigationBarUnselectedColor,
            elevation: 0,
            onTap: (index) async {
              // 預載入目標頁面的數據
              final preloadService = DataPreloadService();

              switch (index) {
                case 0:
                  context.go('/task/create');
                  break;
                case 1:
                  // 預載入任務數據
                  preloadService.preloadForRoute('/task');
                  context.go('/task');
                  break;
                case 2:
                  // 預載入首頁數據
                  preloadService.preloadForRoute('/home');
                  context.go('/home');
                  break;
                case 3:
                  // 預載入聊天數據
                  preloadService.preloadForRoute('/chat');
                  context.go('/chat');
                  break;
                case 4:
                  context.go('/account');
                  break;
              }
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_box_outlined),
                label: '',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: '',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: _ChatBadgeIcon(),
                label: '',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: '',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 獲取返回箭頭的顏色
  Color _getBackArrowColor(ThemeConfigManager themeManager) {
    return _canGoBack()
        ? themeManager.currentTheme.backArrowColor
        : themeManager.currentTheme.backArrowColorInactive;
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/task/create')) return 0;
    if (location.startsWith('/task')) return 1;
    if (location.startsWith('/home')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/account')) return 4;
    return 2; // 預設 Home
  }

  bool _canGoBack() {
    if (_routeHistory.length <= 1) {
      return false;
    }

    // 檢查是否有可返回的路由
    for (int i = _routeHistory.length - 2; i >= 0; i--) {
      final previousPath = _routeHistory[i];

      if (!_nonReturnableRoutes.contains(previousPath)) {
        return true;
      }
    }

    return false;
  }
}

class _ChatBadgeIcon extends StatefulWidget {
  @override
  State<_ChatBadgeIcon> createState() => _ChatBadgeIconState();
}

class _ChatBadgeIconState extends State<_ChatBadgeIcon> {
  int _total = 0;
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    final center = NotificationCenter();
    _sub = center.totalUnreadStream.listen((v) {
      if (!mounted) return;
      setState(() => _total = v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.message),
        if (_total > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _total > 99 ? '99+' : '$_total',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
