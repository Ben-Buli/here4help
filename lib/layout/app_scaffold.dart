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
import 'dart:math';

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
