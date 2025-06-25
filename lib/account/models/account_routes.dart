import 'package:flutter/material.dart';
import 'package:here4help/account/pages/profile_page.dart';
import 'package:here4help/account/pages/wallet_page.dart';
import 'package:here4help/account/pages/ratings_page.dart';
import 'package:here4help/account/pages/task_history_page.dart';
import 'package:here4help/account/pages/security_page.dart';
import 'package:here4help/account/pages/support_page.dart';
import 'package:here4help/account/pages/logout_page.dart';
// -- Support 客服頁面 --
import 'package:here4help/account/pages/faq_page.dart';
import 'package:here4help/account/pages/contact_us_page.dart';
import 'package:here4help/account/pages/issue_status_page.dart';

/// 定義 Account 模組的路由資料結構

class AccountRoute {
  final IconData icon;
  final String title;
  final String route;
  final Widget page;

  const AccountRoute({
    required this.icon,
    required this.title,
    required this.route,
    required this.page,
  });
}

/// 定義 Support 模組的路由列表
const List<AccountRoute> supportRoutes = [
  AccountRoute(
    icon: Icons.question_answer,
    title: 'FAQ',
    route: '/account/support/faq',
    page: FAQPage(),
  ),
  AccountRoute(
    icon: Icons.contact_mail,
    title: 'Contact Us',
    route: '/account/support/contact',
    page: ContactUsPage(),
  ),
  AccountRoute(
    icon: Icons.info,
    title: 'Issue Status',
    route: '/account/support/issue_status',
    page: IssueStatusPage(),
  ),
];

/// 定義 Account 模組的路由列表
const List<AccountRoute> accountRoutes = [
  AccountRoute(
    icon: Icons.person,
    title: 'Personal Information',
    route: '/account/profile',
    page: ProfilePage(),
  ),
  AccountRoute(
    icon: Icons.account_balance_wallet,
    title: 'My Wallet',
    route: '/account/wallet',
    page: WalletPage(),
  ),
  AccountRoute(
    icon: Icons.star_rate,
    title: 'Ratings and Feedback',
    route: '/account/ratings',
    page: RatingsPage(),
  ),
  AccountRoute(
    icon: Icons.history,
    title: 'Task History',
    route: '/account/task_history',
    page: TaskHistoryPage(),
  ),
  AccountRoute(
    icon: Icons.security,
    title: 'Security Settings',
    route: '/account/security',
    page: SecurityPage(),
  ),
  AccountRoute(
    icon: Icons.support_agent,
    title: 'Contact Customer Support',
    route: '/account/support',
    page: SupportPage(),
  ),
  AccountRoute(
    icon: Icons.logout,
    title: 'Log Out',
    route: '/account/logout',
    page: LogoutPage(),
  ),
];
