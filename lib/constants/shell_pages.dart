// ==================== flutter ====================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== account 模組 ====================
import 'package:here4help/account/pages/account_page.dart';
import 'package:here4help/account/pages/contact_us_page.dart';
import 'package:here4help/account/pages/faq_page.dart';
import 'package:here4help/account/pages/issue_status_page.dart';
import 'package:here4help/account/pages/logout_page.dart';
import 'package:here4help/account/pages/point_policy.dart';
import 'package:here4help/account/pages/profile_page.dart';
import 'package:here4help/account/pages/ratings_page.dart';
import 'package:here4help/account/pages/security_page.dart';
import 'package:here4help/account/pages/support_page.dart';
import 'package:here4help/account/pages/task_history_page.dart';
import 'package:here4help/account/pages/theme_settings_page.dart';
import 'package:here4help/account/pages/wallet_page.dart';

// ==================== auth 模組 ====================
import 'package:here4help/auth/pages/login_page.dart';
import 'package:here4help/auth/pages/signup_page.dart';
import 'package:here4help/auth/pages/student_id_page.dart';
import 'package:here4help/auth/pages/oauth_signup_page.dart';

// ==================== chat 模組 ====================
import 'package:here4help/chat/pages/chat_list_page.dart';
import 'package:here4help/chat/pages/chat_page_wrapper.dart';
import 'package:here4help/chat/widgets/chat_detail_wrapper.dart';
import 'package:here4help/chat/widgets/chat_title_widget.dart';
import 'package:here4help/chat/widgets/chat_list_task_widget.dart';

import 'package:here4help/chat/providers/chat_list_provider.dart';

// ==================== explore 模組 ====================

// ==================== home 模組 ====================
import 'package:here4help/home/pages/home_page.dart';

// ==================== pay 模組 ====================
import 'package:here4help/pay/pages/pay_setting_page.dart';

// ==================== task 模組 ====================
import 'package:here4help/task/pages/task_create_page.dart';
import 'package:here4help/task/pages/task_list_page.dart';
import 'package:here4help/task/pages/task_preview_page.dart';
import 'package:here4help/task/pages/task_apply_page.dart';

// 集中管理 ShellRoute 內的頁面
final List<Map<String, dynamic>> shellPages = [
  {
    'path': '/login',
    'child': const LoginPage(),
    'title': 'Login',
    'showAppBar': false,
    'showBottomNav': false,
    'showBackArrow': false,
  },
  {
    'path': '/signup',
    'builder': (context, extra) =>
        SignupPage(oauthData: extra as Map<String, dynamic>?),
    'title': 'ESSENTIAL INFORMATION',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
  },

  {
    'path': '/signup/student-id',
    'child': const StudentIdPage(),
    'title': 'IDENTITY VERIFICATION',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
  },
  {
    'path': '/home',
    'child': const HomePage(),
    'title': 'Home',
    'showBottomNav': true,
    'showAppBar': true,
    'showBackArrow': true
  },
  {
    'path': '/chat',
    'child': const ChatPageWrapper(),
    'title': 'Chats',
    'showBottomNav': true,
    'showBackArrow': true,
    'titleWidgetBuilder': (context, data) {
      // 透過 ChatListProvider 的靜態實例建立雙向同步
      return ChatListTaskWidget(
        initialTab: ChatListProvider.instance?.currentTabIndex ?? 0,
        onTabChanged: (index) {
          // AppBar tab 被點擊時，通知 Provider 進行切換（會同步 TabBarView）
          ChatListProvider.instance?.switchTab(index);
        },
      );
    },
  },
  {
    'path': '/chat/detail',
    'builder': (context, data) {
      return ChatDetailWrapper(data: data as Map<String, dynamic>?);
    },
    'title': '', // 設定空字串，讓 appBarBuilder 的標題優先顯示
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'titleWidgetBuilder': (context, data) {
      return ChatTitleWidget(data: data as Map<String, dynamic>?);
    },
  },
  {
    'path': '/account',
    'child': const AccountPage(),
    'title': 'Account',
    'showBottomNav': true,
    'showBackArrow': true,
  },
  {
    'path': '/task/create',
    'builder': (context, data) {
      return TaskCreatePage(
        editData: data as Map<String, dynamic>?,
      );
    },
    'title': 'Posting Task',
    'showBottomNav': true,
    'showBackArrow': true
  },
  {
    'path': '/task/create/preview',
    'child': const TaskPreviewPage(),
    'title': 'Task Preview',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/task',
    'child': const TaskListPage(),
    'title': 'Task',
    'showBottomNav': true,
    'showBackArrow': true,
    'actionsBuilder': (context) => [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              print('🔍 Edit Icon 被點擊，準備導航到 /chat');
              print('🔍 當前路徑: ${GoRouterState.of(context).uri.path}');
              print('🔍 Context 是否可用: ${context.mounted}');

              // 檢查用戶登入狀態
              final prefs = await SharedPreferences.getInstance();
              final email = prefs.getString('user_email');
              print('🔍 用戶登入狀態: ${email != null ? "已登入 ($email)" : "未登入"}');

              print('🔍 嘗試導航...');

              // 使用 GoRouter.of(context) 獲取正確的 GoRouter 實例
              try {
                print('🔍 執行 GoRouter.of(context).go...');
                GoRouter.of(context).go('/task/create');
                print('✅ GoRouter.of(context).go 執行完成');
              } catch (e) {
                print('❌ GoRouter.of(context).go 失敗: $e');
                // 備用方案：使用 Navigator.push
                try {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChatListPage(),
                    ),
                  );
                  print('✅ Navigator.push 執行完成');
                } catch (e2) {
                  print('❌ Navigator.push 也失敗: $e2');
                }
              }
            },
          ),
        ],
  },
  {
    'path': '/task/create/preview',
    'builder': (context, state) {
      return const TaskPreviewPage();
    },
    'title': 'Task Preview',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/task/apply',
    'builder': (context, state) {
      return TaskApplyPage(data: state as Map<dynamic, dynamic>);
    },
    'title': 'Task Apply Resume',
    'showBottomNav': false,
    'showBackArrow': true
  },
  // Account 模組路由
  {
    'path': '/account/profile',
    'child': const ProfilePage(),
    'title': 'Personal Information',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.person,
  },
  {
    'path': '/account/wallet',
    'child': const WalletPage(),
    'title': 'My Wallet',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.account_balance_wallet,
  },
  {
    'path': '/account/wallet/point_policy',
    'child': const PointPolicyPage(),
    'title': 'Pont Policy',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.stars,
  },
  {
    'path': '/account/ratings',
    'child': const RatingsPage(),
    'title': 'Ratings and Feedback',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.star_rate,
  },
  {
    'path': '/account/task_history',
    'child': const TaskHistoryPage(),
    'title': 'Task History',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.history,
  },
  {
    'path': '/account/security',
    'child': const SecurityPage(),
    'title': 'Security Settings',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.lock,
  },
  {
    'path': '/account/theme',
    'child': const ThemeSettingsPage(),
    'title': 'Theme Settings',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.palette,
  },
  {
    'path': '/account/support',
    'child': const SupportPage(),
    'title': 'Contact Customer Support',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.support_agent,
  },
  {
    'path': '/account/logout',
    'child': const LogoutPage(),
    'title': 'Log Out',
    'showAppBar': false,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.logout,
  },
  // Support 子路由
  {
    'path': '/account/support/contact',
    'child': const ContactUsPage(),
    'title': 'Contact Us',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.contact_mail,
  },
  {
    'path': '/account/support/faq',
    'child': const FAQPage(),
    'title': 'FAQ',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.help_outline,
  },
  {
    'path': '/account/support/issue_status',
    'child': const IssueStatusPage(),
    'title': 'Check Issue Status',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'icon': Icons.report_problem,
  },
  {
    'path': '/pay/setting',
    'child': const PaySettingPage(),
    'title': 'Pay Setting',
    'showBottomNav': false,
    'showBackArrow': true
  },
];
