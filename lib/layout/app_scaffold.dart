// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showAppBar;
  final bool centerTitle;
  final bool showBottomNav;
  final bool showBackArrow;
  final List<Widget>? actions;

  /// AppScaffold 是應用程式的主要結構元件，
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Scaffold(
            appBar: showAppBar
                ? AppBar(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    elevation: 0,
                    centerTitle: centerTitle,
                    leading: showBackArrow
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Color(0xFF2563EB)),
                            onPressed: () {
                              debugPrint(
                                  'Back button pressed: ${context.canPop()}');
                              if (context.canPop()) {
                                context.pop();
                                return;
                              }
                              context.go('/home');
                            },
                          )
                        : null,
                    title: Text(
                      title ?? '',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1.0),
                      child: Container(
                        height: 1.0,
                        color: const Color(0xFFCCCCCC),
                      ),
                    ),
                  )
                : null,
            body: child,
            bottomNavigationBar: showBottomNav
                ? BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: _getCurrentIndex(context),
                    showSelectedLabels: false,
                    showUnselectedLabels: false,
                    onTap: (index) {
                      switch (index) {
                        case 0:
                          context.go('/task/create');
                          break;
                        case 1:
                          context.go('/task');
                          break;
                        case 2:
                          context.go('/home');
                          break;
                        case 3:
                          context.go('/chat');
                          break;
                        case 4:
                          context.go('/account');
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
