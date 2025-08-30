// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/services/data_preload_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'dart:ui';
import 'dart:math';
import 'package:here4help/services/scroll_event_bus.dart';
import 'package:here4help/constants/shell_pages.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';

// 新增：導覽列項目資料結構
class NavigationItem {
  final IconData icon;
  final String label;
  final String route;
  final bool requiresPreload;
  final Widget? customIcon;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    this.requiresPreload = false,
    this.customIcon,
  });
}

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

  /// 獲取上一個有效的路由路徑
  static String? getPreviousValidRoute() {
    return _AppScaffoldState.getPreviousValidRoute();
  }
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

  // 靜態方法來獲取當前的路由歷史
  static _AppScaffoldState? _currentInstance;

  @override
  void initState() {
    super.initState();
    _currentInstance = this;
  }

  @override
  void dispose() {
    if (_currentInstance == this) {
      _currentInstance = null;
    }
    super.dispose();
  }

  /// 獲取當前的路由歷史
  static List<String> getCurrentRouteHistory() {
    return _currentInstance?._routeHistory ?? [];
  }

  /// 獲取上一個有效的路由路徑
  static String? getPreviousValidRoute() {
    final history = getCurrentRouteHistory();
    if (history.length < 2) return null;

    final instance = _currentInstance;
    if (instance == null) return null;

    // 從倒數第二個開始查找（跳過當前路徑）
    for (int i = history.length - 2; i >= 0; i--) {
      final path = history[i];
      // 跳過不可返回的路由和權限拒絕頁面
      if (!instance._nonReturnableRoutes.contains(path) &&
          !path.contains('/permission-denied')) {
        return path;
      }
    }

    return null;
  }

  // 新增：統一的導覽列項目配置
  static const List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home,
      label: 'Home',
      route: '/home',
      requiresPreload: true,
    ),
    NavigationItem(
      icon: Icons.search,
      label: 'Tasks',
      route: '/task',
      requiresPreload: true,
    ),
    NavigationItem(
      icon: Icons.message,
      label: 'Chat',
      route: '/chat',
      requiresPreload: true,
      customIcon: null, // 將在 build 時動態創建 _ChatBadgeDotIcon
    ),
    NavigationItem(
      icon: Icons.person,
      label: 'Account',
      route: '/account',
      requiresPreload: false,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 檢查 Widget 是否仍然被掛載且可以安全存取 context
    if (!mounted) return;

    try {
      final raw = GoRouterState.of(context).uri.toString();
      final currentPath = _normalizeRoute(raw);

      // 檢查當前路徑是否為有效的 shell page
      if (currentPath.isNotEmpty && !_isSystemPage(currentPath)) {
        if (!isValidShellPage(currentPath)) {
          debugPrint('🚫 無效路徑檢測到: $currentPath，重定向到 404');
          // 延遲執行重定向，避免在 build 過程中修改路由
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/page-not-found', extra: currentPath);
            }
          });
          return;
        }
      }

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

      // 特殊處理：如果在權限拒絕頁面，需要智能返回
      final currentState = GoRouterState.of(context);
      if (currentState.uri.path.contains('/permission-denied')) {
        _handlePermissionDeniedBack();
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

  /// 處理權限拒絕頁面的返回邏輯
  void _handlePermissionDeniedBack() {
    final state = GoRouterState.of(context);
    final fromPath = state.uri.queryParameters['from']; // 真正的上一頁
    final blockedPath = state.uri.queryParameters['blocked']; // 被阻擋的頁面

    debugPrint(
        '🔙 AppScaffold 返回: fromPath=$fromPath, blockedPath=$blockedPath');

    if (fromPath != null && fromPath.isNotEmpty) {
      // 檢查上一頁是否為基本頁面（permission = 0）
      if (_isBasicPage(fromPath)) {
        debugPrint('🔙 AppScaffold 返回到基本頁面: $fromPath');
        context.go(fromPath);
        return;
      }
    }

    // 如果沒有有效的上一頁，返回首頁
    debugPrint('🔙 AppScaffold 返回到首頁');
    context.go('/home');
  }

  /// 檢查是否為基本頁面（permission = 0）
  bool _isBasicPage(String path) {
    final basicPages = [
      '/home',
      '/account',
      '/task',
      '/account/profile',
      '/account/security',
    ];
    return basicPages.contains(path);
  }

  /// 檢查是否為系統頁面（不需要 404 檢查）
  bool _isSystemPage(String path) {
    final systemPages = [
      '/page-not-found',
      '/permission-denied',
      '/permission-unverified',
      '/login',
      '/signup',
    ];
    return systemPages.any((systemPath) => path.startsWith(systemPath));
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
        // 若主題為 taipei_101 或 milk_tea_earth，提供專屬背景
        final baseThemeName =
            themeManager.currentTheme.name.replaceAll('_dark', '');
        final isTaipei101 = baseThemeName == 'taipei_101';
        final isMilkTea = baseThemeName == 'milk_tea_earth';
        final backgroundChild = Center(
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
        );

        if (isTaipei101 || baseThemeName == 'pride_s_curve' || isMilkTea) {
          return Stack(
            children: [
              // 簡化的點狀燈飾背景：多層次散落的發光點
              if (isTaipei101) ...[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _Taipei101LightsPainter(),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _Taipei101TowerPainter(
                      bodyColor: const Color(0xFF273043).withOpacity(0.55),
                      edgeColor: Colors.white.withOpacity(0.18),
                      windowColor: Colors.white.withOpacity(0.16),
                    ),
                  ),
                ),
              ],
              if (baseThemeName == 'pride_s_curve')
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SCurveRainbowPainter(),
                  ),
                ),
              if (isMilkTea)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BubbleTeaPatternPainter(
                      cupColor:
                          themeManager.currentTheme.accent.withOpacity(0.35),
                      lidColor: themeManager.currentTheme.background
                          .withOpacity(0.25),
                      strawColor:
                          themeManager.currentTheme.primary.withOpacity(0.35),
                      pearlColor:
                          themeManager.currentTheme.onSurface.withOpacity(0.35),
                    ),
                  ),
                ),
              backgroundChild,
            ],
          );
        }

        // 對特定主題（clownfish、patrick_star）強制水平 0deg 漸層
        final bool forceHorizontal =
            baseThemeName == 'clownfish' || baseThemeName == 'patrick_star';
        final AlignmentGeometry? beginOverride =
            forceHorizontal ? Alignment.centerLeft : null;
        final AlignmentGeometry? endOverride =
            forceHorizontal ? Alignment.centerRight : null;

        return themeManager.effectiveTheme.createGradientBlurredBackground(
          child: backgroundChild,
          begin: beginOverride,
          end: endOverride,
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
              gradient: themeManager.appBarGradient.isNotEmpty
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: themeManager.appBarGradient
                          .map((c) => c.withOpacity(0.95))
                          .toList(),
                    )
                  : null,
              color: themeManager.appBarGradient.isNotEmpty
                  ? null
                  : themeManager.navigationBarBackground,
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
              scrolledUnderElevation: 0, // 滾動時不改變背景色
              surfaceTintColor: Colors.transparent, // 移除 Material 3 的表面色調
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
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedItemColor: themeManager.navigationBarSelectedColor,
            unselectedItemColor: themeManager.navigationBarUnselectedColor,
            elevation: 0,
            onTap: (index) async {
              final current = _getCurrentIndex(context);
              if (index == current) {
                // 同頁：發送滾頂事件
                final route = _navigationItems[index].route;
                ScrollEventBus().emit(route);
                return;
              }

              // 預載入目標頁面的數據
              final preloadService = DataPreloadService();
              final targetItem = _navigationItems[index];

              if (targetItem.requiresPreload) {
                preloadService.preloadForRoute(targetItem.route);
              }

              context.go(targetItem.route);
            },
            items: _navigationItems.map((item) {
              // 特殊處理 Chat 項目的圖標
              if (item.route == '/chat') {
                return BottomNavigationBarItem(
                  icon: _ChatBadgeDotIcon(),
                  label: item.label,
                );
              }

              return BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              );
            }).toList(),
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

    // 優先檢查更長的路徑，避免 /task 匹配到 /task/create
    for (int i = 0; i < _navigationItems.length; i++) {
      final item = _navigationItems[i];
      if (location.startsWith(item.route)) {
        return i;
      }
    }

    // 如果沒有匹配到任何路由，返回 Home 頁面
    return 2; // Home 頁面的索引
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

class _Taipei101LightsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(101);
    final bg = Paint()
      ..color = Colors.white.withOpacity(0) // 透明，讓主題背景顯示
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bg);

    final lightPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.fill;

    // 散落 120 顆冷白藍光點
    for (int i = 0; i < 120; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 1.5 + random.nextDouble() * 2.5;
      final hue = 210 + random.nextDouble() * 30; // 冷藍色域
      final color =
          HSLColor.fromAHSL(1, hue, 0.6, 0.85).toColor().withOpacity(0.7);
      lightPaint.color = color;
      canvas.drawCircle(Offset(x, y), radius, lightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SCurveRainbowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 背景打底（透明以顯示主題背景色）
    final base = Paint()..color = Colors.transparent;
    canvas.drawRect(rect, base);

    // 使用多條沿 45° 走向的 S 曲線描繪彩虹帶
    final colors = [
      const Color(0xFFE65C5C), // red
      const Color(0xFFF2A64F), // orange
      const Color(0xFFF2E86A), // yellow
      const Color(0xFF52AE6B), // green
      const Color(0xFF4A79EA), // blue
      const Color(0xFFA262AD), // violet
    ];

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..color = colors[i].withOpacity(0.35)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final path = Path();
      final dx = i * 30.0;
      path.moveTo(-50 + dx, size.height * 0.15);
      path.cubicTo(
        size.width * 0.25 + dx,
        size.height * 0.05,
        size.width * 0.55 + dx,
        size.height * 0.30,
        size.width + 50 + dx,
        size.height * 0.22,
      );
      path.cubicTo(
        size.width * 0.55 + dx,
        size.height * 0.40,
        size.width * 0.25 + dx,
        size.height * 0.60,
        -50 + dx,
        size.height * 0.55,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Taipei101TowerPainter extends CustomPainter {
  final Color bodyColor;
  final Color edgeColor;
  final Color windowColor;

  _Taipei101TowerPainter({
    required this.bodyColor,
    required this.edgeColor,
    required this.windowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width * 0.62; // 右側偏中，避免擋住內容
    final baseY = size.height * 0.82;
    // 固定大樓寬度以「手機版最小寬度」為基準（例如 360px）
    const double baselineMobileWidth = 360.0;
    final double referenceWidth =
        size.width <= baselineMobileWidth ? size.width : baselineMobileWidth;
    final double towerWidth = referenceWidth * 0.16;
    final sectionHeight = size.height * 0.06;

    final bodyPaint = Paint()..color = bodyColor;
    final edgePaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 畫 6 層等邊梯形向上堆疊（上底較寬、下底較窄以符合你描述）
    for (int i = 0; i < 6; i++) {
      final topY = baseY - (i + 1) * sectionHeight;
      final bottomY = baseY - i * sectionHeight;
      final topWidth = towerWidth * (1.15 - i * 0.08);
      final bottomWidth = towerWidth * (1.0 - i * 0.06);

      final path = Path();
      path.moveTo(centerX - topWidth / 2, topY);
      path.lineTo(centerX + topWidth / 2, topY);
      path.lineTo(centerX + bottomWidth / 2, bottomY);
      path.lineTo(centerX - bottomWidth / 2, bottomY);
      path.close();
      canvas.drawPath(path, bodyPaint);
      canvas.drawPath(path, edgePaint);
    }

    // 頂端尖塔
    final spirePath = Path();
    spirePath.moveTo(centerX - towerWidth * 0.12, baseY - 6 * sectionHeight);
    spirePath.lineTo(centerX + towerWidth * 0.12, baseY - 6 * sectionHeight);
    spirePath.lineTo(centerX, baseY - 6.9 * sectionHeight);
    spirePath.close();
    canvas.drawPath(spirePath, bodyPaint);
    canvas.drawPath(spirePath, edgePaint);

    // 窗格點綴
    final windowPaint = Paint()
      ..color = windowColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final y = baseY - (i + 0.5) * sectionHeight;
      for (int j = -2; j <= 2; j++) {
        final x = centerX + j * (towerWidth * 0.12);
        canvas.drawCircle(Offset(x, y), 1.2, windowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BubbleTeaPatternPainter extends CustomPainter {
  final Color cupColor;
  final Color lidColor;
  final Color strawColor;
  final Color pearlColor;

  _BubbleTeaPatternPainter({
    required this.cupColor,
    required this.lidColor,
    required this.strawColor,
    required this.pearlColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);

    // 簡化：在畫面上散佈多個小尺寸珍奶圖示，低不透明度作為背景插圖
    for (int i = 0; i < 10; i++) {
      final scale = 0.6 + rnd.nextDouble() * 0.6;
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      _drawBubbleTea(canvas, Offset(x, y), 60 * scale);
    }
  }

  void _drawBubbleTea(Canvas canvas, Offset center, double width) {
    final cupH = width * 1.2;
    final cupW = width;
    final cupTop = center.dy - cupH / 2;
    final cupLeft = center.dx - cupW / 2;

    // 吸管
    final strawPaint = Paint()
      ..color = strawColor
      ..style = PaintingStyle.fill;
    final strawPath = Path();
    strawPath.moveTo(cupLeft + cupW * 0.6, cupTop + cupH * 0.05);
    strawPath.lineTo(cupLeft + cupW * 0.7, cupTop - cupH * 0.15);
    strawPath.lineTo(cupLeft + cupW * 0.78, cupTop - cupH * 0.10);
    strawPath.lineTo(cupLeft + cupW * 0.66, cupTop + cupH * 0.05);
    strawPath.close();
    canvas.drawPath(strawPath, strawPaint);

    // 杯蓋
    final lidPaint = Paint()..color = lidColor;
    final lidRect =
        Rect.fromLTWH(cupLeft, cupTop + cupH * 0.1, cupW, cupH * 0.08);
    canvas.drawRRect(
        RRect.fromRectAndRadius(lidRect, const Radius.circular(8)), lidPaint);

    // 杯身（下寬上窄略梯形）
    final cupPaint = Paint()..color = cupColor;
    final cupPath = Path();
    cupPath.moveTo(cupLeft + cupW * 0.2, cupTop + cupH * 0.18);
    cupPath.lineTo(cupLeft + cupW * 0.8, cupTop + cupH * 0.18);
    cupPath.lineTo(cupLeft + cupW * 0.72, cupTop + cupH * 0.95);
    cupPath.lineTo(cupLeft + cupW * 0.28, cupTop + cupH * 0.95);
    cupPath.close();
    canvas.drawPath(cupPath, cupPaint);

    // 珍珠（限制在杯身範圍內，允許被杯邊裁切）
    canvas.save();
    canvas.clipPath(cupPath); // 限制繪製區域到杯身
    final pearlPaint = Paint()..color = pearlColor;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3 + r; c++) {
        final px = cupLeft + cupW * (0.35 + c * 0.12 - r * 0.06);
        final py = cupTop + cupH * (0.65 + r * 0.10);
        canvas.drawCircle(Offset(px, py), width * 0.05, pearlPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatBadgeDotIcon extends StatefulWidget {
  @override
  State<_ChatBadgeDotIcon> createState() => _ChatBadgeDotIconState();
}

class _ChatBadgeDotIconState extends State<_ChatBadgeDotIcon> {
  @override
  void initState() {
    super.initState();
    // 不再需要 StreamSubscription，直接使用 Consumer
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatListProvider>(
      builder: (context, chatProvider, child) {
        // 計算當前用戶有權限的聊天室未讀數總和
        int totalUnread = 0;

        // 獲取當前用戶信息
        final userService = Provider.of<UserService>(context, listen: false);
        final currentUserId = userService.currentUser?.id.toString();

        // 調試：打印未讀數據
        debugPrint('🔍 [底部導航] 調試未讀數據:');
        debugPrint('  - 當前用戶 ID: $currentUserId');
        debugPrint('  - 總聊天室數: ${chatProvider.unreadByRoom.length}');
        debugPrint('  - 未讀數據: ${chatProvider.unreadByRoom}');

        if (currentUserId != null) {
          // 只統計當前用戶有權限的聊天室
          for (final entry in chatProvider.unreadByRoom.entries) {
            final roomId = entry.key;
            final count = entry.value;

            // 檢查聊天室是否屬於當前用戶
            if (_isUserAuthorizedForRoom(roomId, currentUserId)) {
              totalUnread += count;
              debugPrint('  - 有權限的聊天室: $roomId = $count');
            } else {
              debugPrint('  - 無權限的聊天室: $roomId = $count (已排除)');
            }
          }
        }

        debugPrint('  - 最終未讀總數: $totalUnread');
        debugPrint(
            '  - 顯示類型: ${totalUnread > 99 ? "99+" : totalUnread > 9 ? "數字" : "小圓點"}');

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.message),
            if (totalUnread > 0)
              Positioned(
                right: totalUnread > 99 ? -2 : 0,
                top: totalUnread > 99 ? -2 : 0,
                child: Container(
                  width: totalUnread > 99 ? 16 : (totalUnread > 9 ? 12 : 8),
                  height: totalUnread > 99 ? 16 : (totalUnread > 9 ? 12 : 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: totalUnread > 99
                      ? const Center(
                          child: Text(
                            '99+',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : totalUnread > 9
                          ? Center(
                              child: Text(
                                totalUnread.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                ),
              ),
          ],
        );
      },
    );
  }

  /// 檢查用戶是否有權限訪問特定聊天室
  bool _isUserAuthorizedForRoom(String roomId, String currentUserId) {
    // 這裡需要根據聊天室 ID 的格式來判斷用戶權限
    // 假設聊天室 ID 格式為: "room_${taskId}_${creatorId}_${participantId}"
    // 或者 "room_${taskId}_${userId1}_${userId2}"

    try {
      // 解析聊天室 ID
      if (roomId.startsWith('room_')) {
        final parts = roomId.split('_');
        if (parts.length >= 4) {
          // 格式: room_taskId_creatorId_participantId
          final creatorId = parts[2];
          final participantId = parts[3];

          // 檢查當前用戶是否為創建者或參與者
          return creatorId == currentUserId || participantId == currentUserId;
        }
      }

      // 如果無法解析，預設為無權限
      return false;
    } catch (e) {
      // 解析失敗，預設為無權限
      return false;
    }
  }
}
