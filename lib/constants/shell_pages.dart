// ==================== flutter ====================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==================== account 模組 ====================
import 'package:here4help/account/pages/account_page.dart';
import 'package:here4help/account/pages/contact_us_page.dart';
import 'package:here4help/account/pages/faq_page.dart';
import 'package:here4help/account/pages/issue_status_page.dart';
import 'package:here4help/account/pages/logout_page.dart';
import 'package:here4help/account/pages/point_policy_page.dart';
import 'package:here4help/account/pages/profile_page.dart';
import 'package:here4help/account/pages/ratings_page.dart';
import 'package:here4help/account/pages/security_page.dart';
import 'package:here4help/account/pages/support_page.dart';
import 'package:here4help/account/pages/terms_of_use_page.dart';
import 'package:here4help/account/pages/theme_settings_page.dart';
import 'package:here4help/account/pages/wallet_page.dart';
import 'package:here4help/account/pages/wallet_withdraw_page.dart';
import 'package:here4help/account/pages/point_history_page.dart';
import 'package:here4help/account/pages/privacy_policy_page.dart';

// ==================== auth 模組 ====================
import 'package:here4help/auth/pages/login_page.dart';
import 'package:here4help/auth/pages/forgot_password_page.dart';
import 'package:here4help/auth/pages/signup_page.dart';
import 'package:here4help/auth/pages/student_id_page.dart';
import 'package:here4help/auth/pages/student_id_update_page.dart';

// ==================== chat 模組 ====================
import 'package:here4help/chat/pages/chat_list_page.dart';
import 'package:here4help/chat/pages/chat_page_wrapper.dart';
import 'package:here4help/chat/widgets/chat_detail_wrapper.dart';
import 'package:here4help/chat/widgets/support_chat_detail_wrapper.dart';
import 'package:here4help/chat/widgets/chat_title_widget.dart';
import 'package:here4help/chat/widgets/chat_list_task_widget.dart';

import 'package:here4help/chat/providers/chat_list_provider.dart';

// ==================== explore 模組 ====================

// ==================== home 模組 ====================
import 'package:here4help/home/pages/home_page.dart';

// ==================== pay 模組 ====================
import 'package:here4help/pay/pages/pay_setting_page.dart';

// ==================== system 模組 ====================
import 'package:here4help/system/pages/permission_denied_page.dart';
import 'package:here4help/system/pages/permission_unvertified_page.dart';
import 'package:here4help/system/pages/not_found_page.dart';

// ==================== task 模組 ====================
import 'package:here4help/task/pages/task_create_page.dart';
import 'package:here4help/task/pages/task_list_page.dart';
import 'package:here4help/task/pages/task_preview_page.dart';
import 'package:here4help/task/pages/task_apply_page.dart';
import 'package:here4help/task/pages/task_edit_page.dart';

// 集中管理 ShellRoute 內的頁面
final List<Map<String, dynamic>> shellPages = [
  {
    'path': '/login',
    'child': const LoginPage(),
    'title': 'Login',
    'showAppBar': false,
    'showBottomNav': false,
    'showBackArrow': false,
    'allowSwipeBack': false,
    'permission': -10, // 公開頁面：任何狀態都可訪問登入頁
  },
  {
    'path': '/forgot-password',
    'child': const ForgotPasswordPage(),
    'title': 'Forgot Password',
    'showAppBar': false,
    'showBottomNav': false,
    'showBackArrow': false,
    'allowSwipeBack': false,
    'permission': -10, // 公開頁面：任何狀態都可訪問
  },
  {
    'path': '/signup',
    'builder': (context, extra) {
      Map<String, dynamic>? oauthData;
      if (extra is Map<String, dynamic>) {
        oauthData = Map<String, dynamic>.from(extra);
      }
      return SignupPage(oauthData: oauthData);
    },
    'title': 'ESSENTIAL INFORMATION',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': -10, // 公開頁面：任何狀態都可訪問（包括未登入）
  },

  {
    'path': '/signup/student-id',
    'child': const StudentIdPage(),
    'title': 'IDENTITY VERIFICATION',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': -10, // 公開頁面：任何狀態都可訪問（包括未登入）
  },
  {
    'path': '/signup/student-id/update',
    'builder': (context, extra) {
      // 確保 extra 參數的類型安全
      Map<String, dynamic>? rejectedData;
      if (extra is Map<String, dynamic>) {
        rejectedData = extra;
      } else if (extra != null) {
        // 如果 extra 不是 Map，嘗試轉換
        try {
          rejectedData = Map<String, dynamic>.from(extra as Map);
        } catch (e) {
          debugPrint('⚠️ 無法轉換 extra 參數為 Map<String, dynamic>: $e');
          rejectedData = null;
        }
      }

      return StudentIdUpdatePage(rejectedData: rejectedData);
    },
    'title': 'UPDATE STUDENT ID',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': 0, // 已登入用戶可更新學生證
  },
  {
    'path': '/home',
    'child': const HomePage(),
    'title': 'Home',
    'showBottomNav': true,
    'showAppBar': true,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'permission': 0, // 新用戶可訪問首頁
  },
  {
    'path': '/chat',
    'child': const ChatPageWrapper(),
    'title': 'Chats',
    'showBottomNav': true,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'permission': 1, // 需要已認證用戶才能訪問聊天
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
    'allowSwipeBack': true,
    'permission': 1, // 需要已認證用戶才能訪問聊天詳情
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
    'allowSwipeBack': true,
    'permission': 0, // 新用戶可訪問帳戶頁面
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
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': 1, // 需要已認證用戶才能創建任務
  },
  {
    'path': '/task/edit',
    'builder': (context, data) {
      return TaskEditPage(
        editData: data as Map<String, dynamic>?,
      );
    },
    'title': 'Editing Task',
    'showBottomNav': true,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': 1, // 需要已認證用戶才能編輯任務
  },
  {
    'path': '/task/create/preview',
    'child': const TaskPreviewPage(),
    'title': 'Task Preview',
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'permission': 1, // 需要已認證用戶才能預覽任務
  },
  {
    'path': '/task',
    'child': const TaskListPage(),
    'title': 'Task',
    'showBottomNav': true,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'permission': 0, // 新用戶可瀏覽任務列表
    'actionsBuilder': (context) => [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () async {
              // 使用 GoRouter.of(context) 獲取正確的 GoRouter 實例
              try {
                GoRouter.of(context).go('/task/create');
              } catch (e) {
                // 備用方案：使用 Navigator.push
                try {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChatListPage(),
                    ),
                  );
                } catch (e) {
                  debugPrint('❌ Navigator.push 也失敗: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to navigate to task create page.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
  },
  {
    'path': '/task/apply',
    'builder': (context, state) {
      return TaskApplyPage(data: state as Map<dynamic, dynamic>);
    },
    'title': 'Task Apply Resume',
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': 1, // 需要已認證用戶才能應徵任務
  },
  // Account 模組路由
  {
    'path': '/account/profile',
    'child': const ProfilePage(),
    'title': 'Personal Information',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'icon': Icons.person,
    'permission': 0, // 新用戶可編輯個人資料
  },
  {
    'path': '/account/wallet',
    'child': const WalletPage(),
    'title': 'My Wallet',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.account_balance_wallet,
    'permission': 1, // 需要已認證用戶才能訪問錢包
  },
  {
    'path': '/account/wallet/point_history',
    'child': const PointHistoryPage(),
    'title': 'Point History',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.history,
    'permission': 0, // 需要已認證用戶才能查看點數歷史
  },
  {
    'path': '/account/wallet/withdraw',
    'child': const WalletWithdrawPage(),
    'title': 'Withdraw Request',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'icon': Icons.output_outlined,
    'permission': 1, // 需要已認證用戶才能申請提領
  },
  {
    'path': '/account/wallet/point_policy',
    'child': const PointPolicyPage(),
    'title': 'Point Policy',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.stars,
    'permission': 0, // 新用戶可查看點數政策
  },
  // {
  //   'path': '/account/ratings',
  //   'child': const RatingsPage(),
  //   'title': 'Ratings and Feedback',
  //   'showAppBar': true,
  //   'showBottomNav': false,
  //   'showBackArrow': true,
  //   'icon': Icons.star_rate,
  //   'permission': 1, // 需要已認證用戶才能查看評價
  // },
  {
    'path': '/account/task_history',
    'child': const RatingsPage(),
    // 'child': const TaskHistoryPage(),
    'title': 'Task History & Feedback',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.history,
    'permission': 1, // 需要已認證用戶才能查看任務歷史
  },
  {
    'path': '/account/security',
    'child': const SecurityPage(),
    'title': 'Security Settings',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'icon': Icons.lock,
    'permission': 0, // 新用戶可訪問安全設定
  },
  {
    'path': '/account/theme',
    'child': const ThemeSettingsPage(),
    'title': 'Theme Settings',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.palette,
    'permission': 0, // 新用戶可訪問主題設定
  },
  {
    'path': '/account/support',
    'child': const SupportPage(),
    'title': 'Contact Customer Support',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.support_agent,
    'permission': 0, // 新用戶可聯繫客服
  },
  {
    'path': '/account/logout',
    'child': const LogoutPage(),
    'title': 'Log Out',
    'showAppBar': false,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'icon': Icons.logout,
    'permission': 0, // 新用戶可登出
  },
  // Support 子路由
  {
    'path': '/account/support/contact',
    'child': const ContactUsPage(),
    'title': 'Contact Us',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'icon': Icons.contact_mail,
    'permission': 0, // 新用戶可聯繫客服
  },

  {
    'path': '/account/support/issue_status',
    'child': const IssueStatusPage(),
    'title': 'Check Issue Status',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.report_problem,
    'permission': 0, // 新用戶可查看問題狀態
  },
  {
    'path': '/account/support/contact/chat',
    'builder': (context, data) {
      return SupportChatDetailWrapper(data: data as Map<String, dynamic>?);
    },
    'title': 'Support Chat',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.chat,
    'permission': 0, // 新用戶可訪問客服聊天室
  },
  {
    'path': '/account/support/faq',
    'child': const FAQPage(),
    'title': 'FAQ',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.help_outline,
    'permission': 0, // 新用戶可查看 FAQ
  },
  {
    'path': '/privacy',
    'child': const PrivacyPolicyPage(),
    'title': 'Privacy Policy',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'permission': -10, // 公開頁面：任何狀態都可訪問
  },
  {
    'path': '/terms',
    'child': const TermsOfUsePage(),
    'title': 'Terms of Use',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'permission': -10, // 公開頁面：任何狀態都可訪問
  },
  {
    'path': '/account/support/terms',
    'child': const TermsOfUsePage(),
    'title': 'Terms of Use',
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': true,
    'icon': Icons.file_open,
    'permission': 0,
  },
  {
    'path': '/pay/setting',
    'child': const PaySettingPage(),
    'title': 'Pay Setting',
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': 0, // 新用戶可設定支付
  },
  // #region 權限不足頁面
  {
    'path': '/permission-denied',
    'child': const PermissionDeniedPage(),
    'title': 'Permission Denied', // 403
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': false,
    'allowSwipeBack': false,
    'permission': -10, // 公開頁面：任何狀態都可訪問權限不足頁面
  },
  {
    'path': '/permission-unverified',
    'child': const PermissionUnverifiedPage(),
    'title': 'User Unverified', // 未驗證
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': false,
    'allowSwipeBack': false,
    'permission': 0, // 新用戶可訪問權限不足頁面
  },
  {
    'path': '/page-not-found',
    'builder': (context, extra) {
      final requestedPath = extra is String ? extra : null;
      return NotFoundPage(requestedPath: requestedPath);
    },
    'title': 'Page Not Found', // 404
    'showAppBar': true,
    'showBottomNav': false,
    'showBackArrow': true,
    'allowSwipeBack': false,
    'permission': -10, // 公開頁面：任何狀態都可訪問 404 頁面
  },
  // #endregion
];

/// 檢查路徑是否存在於 shell pages 中
bool isValidShellPage(String path) {
  // 移除查詢參數，只檢查路徑
  final cleanPath = Uri.parse(path).path;

  // 允許匹配子路徑（例如 /account/support/contact/chat）
  // shellPages 可能包含 routes: [] 的子路由，需要展開檢查。
  final allPaths = <String>[];
  for (final page in shellPages) {
    final basePath = page['path'] as String?;
    if (basePath == null || basePath.isEmpty) continue;
    allPaths.add(basePath);

    final subRoutes = page['routes'];
    if (subRoutes is List) {
      for (final sub in subRoutes) {
        if (sub is Map && sub['path'] is String) {
          allPaths.add('$basePath/${sub['path']}');
        }
      }
    }
  }

  return allPaths.any((p) => cleanPath == p || cleanPath.startsWith('$p/'));
}
