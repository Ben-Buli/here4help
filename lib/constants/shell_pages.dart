// ==================== flutter ====================

// ==================== account 模組 ====================
import 'package:here4help/account/pages/account_page.dart';
import 'package:here4help/account/pages/contact_us_page.dart';
import 'package:here4help/account/pages/faq_page.dart';
import 'package:here4help/account/pages/issue_status_page.dart';
import 'package:here4help/account/pages/logout_page.dart';
import 'package:here4help/account/pages/profile_page.dart';
import 'package:here4help/account/pages/ratings_page.dart';
import 'package:here4help/account/pages/security_page.dart';
import 'package:here4help/account/pages/support_page.dart';
import 'package:here4help/account/pages/task_history_page.dart';
import 'package:here4help/account/pages/wallet_page.dart';

// ==================== auth 模組 ====================
import 'package:here4help/auth/pages/login_page.dart';

// ==================== chat 模組 ====================
import 'package:here4help/chat/pages/chat_list_page.dart';
import 'package:here4help/chat/pages/chat_detail_page.dart';

// ==================== explore 模組 ====================
import 'package:here4help/explore/pages/explore_page.dart';

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
    'path': '/home',
    'child': const HomePage(),
    'title': 'Home',
    'showBottomNav': true, // 确保值为布尔类型
    'showAppBar': true, // 确保值为布尔类型
    'showBackArrow': false // 确保值为布尔类型
  },
  {
    'path': '/chat',
    'child': const ChatListPage(),
    'title': 'Posts',
    'showBottomNav': true,
    'showBackArrow': false
  },
  {
    'path': '/chat/detail',
    'builder': (context, data) {
      return ChatDetailPage(data: data as Map<String, dynamic>);
    },
    // 設定寫在ChatDetailPage中
    'showAppBar': false,
    'showBottomNav': false,
    'showBackArrow': false
  },
  {
    'path': '/account',
    'child': const AccountPage(),
    'title': 'Account',
    'showBottomNav': true,
  },
  {
    'path': '/task',
    'child': const TaskListPage(),
    'title': 'Task',
    'showBottomNav': true,
    'showBackArrow': false
  },
  {
    'path': '/task/create',
    'child': const TaskCreatePage(),
    'title': 'Posting Task',
    'showBottomNav': true,
    'showBackArrow': true
  },
  {
    'path': '/task/create/preview',
    'builder': (context, state) {
      return TaskPreviewPage(data: state as Map<String, dynamic>);
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
    'title': 'Task Apply',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/account/wallet',
    'child': const WalletPage(),
    'title': 'Wallet',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/account/profile',
    'child': const ProfilePage(),
    'title': 'Profile',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/account/ratings',
    'child': const RatingsPage(),
    'title': 'Ratings',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/account/history',
    'child': const TaskHistoryPage(),
    'title': 'History',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/account/security',
    'child': const SecurityPage(),
    'title': 'Security Settings',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/account/support',
    'child': const SupportPage(),
    'title': 'Support',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
  },
  {
    'path': '/account/support/contact',
    'child': const ContactUsPage(),
    'title': 'Contact Us',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'group': 'support',
  },
  {
    'path': '/account/support/faq',
    'child': const FAQPage(),
    'title': 'FAQ',
    'showAppBar': true,
    'showBottomNav': false,
    'group': 'support',
  },
  {
    'path': '/account/support/status',
    'child': const IssueStatusPage(),
    'title': 'Issue Status',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'group': 'support',
  },
  {
    'path': '/account/logout',
    'child': const LogoutPage(),
    'title': 'Logout',
    'showBottomNav': false,
    'showBackArrow': true
  },
  {
    'path': '/account/support/explore',
    'child': ExplorePage(),
    'title': 'Explore',
    'showBottomNav': true,
    'showBackArrow': false
  },
  {
    'path': '/pay/setting',
    'child': const PaySettingPage(),
    'title': 'Pay Setting',
    'showBottomNav': false,
    'showBackArrow': true
  },
];
