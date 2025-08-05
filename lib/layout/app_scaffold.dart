// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'dart:ui';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title,
    this.showAppBar = true,
    this.centerTitle = true,
    this.showBottomNav = true,
    this.showBackArrow = false, // 返回鍵：預設不顯示
    this.actions, // 新增
  });

  final Widget child;
  final String? title;
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
    final currentPath = GoRouterState.of(context).uri.toString();
    if (currentPath.isNotEmpty &&
        (_routeHistory.isEmpty || _routeHistory.last != currentPath)) {
      _routeHistory.add(currentPath);
    }
  }

  void _handleBack() {
    try {
      final popped = Navigator.of(context).maybePop();
      popped.then((didPop) {
        if (!didPop) {
          if (_routeHistory.length > 1) {
            final current = _routeHistory.removeLast();
            final previous = _routeHistory.last;
            if (!_nonReturnableRoutes.contains(previous)) {
              context.go(previous);
              _routeHistory.removeLast();
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Back navigation error: $e');
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
              leading: widget.showBackArrow
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: _getBackArrowColor(themeManager),
                      ),
                      onPressed: (_routeHistory.length > 1 &&
                              !_nonReturnableRoutes.contains(
                                  _routeHistory[_routeHistory.length - 2]))
                          ? _handleBack
                          : null,
                    )
                  : null,
              title: Text(
                widget.title ?? '',
                style: TextStyle(
                  color: themeManager.appBarTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
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
            onTap: (index) {
              switch (index) {
                case 0:
                  context.push('/task/create');
                  break;
                case 1:
                  context.push('/task');
                  break;
                case 2:
                  context.push('/home');
                  break;
                case 3:
                  context.push('/chat');
                  break;
                case 4:
                  context.push('/account');
                  break;
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.add_box_outlined),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.message),
                label: '',
              ),
              BottomNavigationBarItem(
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
    final bool canGoBack = _routeHistory.length > 1 &&
        !_nonReturnableRoutes.contains(_routeHistory[_routeHistory.length - 2]);

    if (canGoBack) {
      // 可以返回時使用亮色系
      final style = themeManager.themeStyle;
      switch (style) {
        case 'ocean':
          return Colors.white; // 海洋主題使用純白色
        case 'morandi':
          return Colors.white; // 莫蘭迪主題使用白色
        case 'glassmorphism':
        case 'business':
          // 商業主題使用深色文字
          return const Color(0xFF2D3748); // 深灰文字
        default:
          // 檢查特定主題
          if (themeManager.currentTheme.name == 'sandy_footprints' ||
              themeManager.currentTheme.name == 'sandy_footprints_dark') {
            return Colors.white; // Sandy 主題使用白色
          }
          // Meta 主題使用深色文字
          if (themeManager.currentTheme.name == 'meta_business_style' ||
              themeManager.currentTheme.name == 'meta_business_style_dark') {
            return const Color(0xFF1C1E21); // 深灰文字
          }
          // 彩虹主題使用深色文字
          if (themeManager.currentTheme.name == 'business_gradient' ||
              themeManager.currentTheme.name == 'business_gradient_dark') {
            return const Color(0xFF1F2937); // 深灰文字
          }
          return Colors.white; // 其他主題使用白色
      }
    } else {
      // 不能返回時使用暗色系
      final style = themeManager.themeStyle;
      switch (style) {
        case 'ocean':
          return Colors.white.withOpacity(0.3); // 海洋主題使用半透明白色
        case 'morandi':
          return Colors.white.withOpacity(0.3); // 莫蘭迪主題使用半透明白色
        case 'glassmorphism':
        case 'business':
          // 商業主題使用半透明深色
          return const Color(0xFF2D3748).withOpacity(0.3); // 半透明深灰
        default:
          // 檢查特定主題
          if (themeManager.currentTheme.name == 'sandy_footprints' ||
              themeManager.currentTheme.name == 'sandy_footprints_dark') {
            return Colors.white.withOpacity(0.3); // Sandy 主題使用半透明白色
          }
          // Meta 主題使用半透明深色
          if (themeManager.currentTheme.name == 'meta_business_style' ||
              themeManager.currentTheme.name == 'meta_business_style_dark') {
            return const Color(0xFF1C1E21).withOpacity(0.3); // 半透明深灰
          }
          // 彩虹主題使用半透明深色
          if (themeManager.currentTheme.name == 'business_gradient' ||
              themeManager.currentTheme.name == 'business_gradient_dark') {
            return const Color(0xFF1F2937).withOpacity(0.3); // 半透明深灰
          }
          return Colors.white.withOpacity(0.3); // 其他主題使用半透明白色
      }
    }
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
}
