// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Scaffold(
            appBar: widget.showAppBar
                ? AppBar(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    shape: null,
                    elevation: 0,
                    centerTitle: widget.centerTitle,
                    leading: widget.showBackArrow
                        ? IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              color: (_routeHistory.length > 1 &&
                                      !_nonReturnableRoutes.contains(
                                          _routeHistory[
                                              _routeHistory.length - 2]))
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey,
                            ),
                            onPressed: (_routeHistory.length > 1 &&
                                    !_nonReturnableRoutes.contains(
                                        _routeHistory[
                                            _routeHistory.length - 2]))
                                ? _handleBack
                                : null,
                          )
                        : null,
                    title: Text(
                      widget.title ?? '',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    actions: [
                      ...?widget.actions,
                    ],
                  )
                : null,
            body: SafeArea(
              top: widget.showAppBar,
              bottom: !widget.showBottomNav,
              child: widget.child,
            ),
            bottomNavigationBar: widget.showBottomNav
                ? BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: _getCurrentIndex(context),
                    showSelectedLabels: false,
                    showUnselectedLabels: false,
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
                  )
                : null,
          ),
        ),
      ),
    );
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
