/// 每條路由對應所需的最低權限等級
/// - 0: New User (Unrecognized)
/// - 1: User
/// - -2: Banned
final Map<String, int> routePermissions = {
  '/home': 1,
  '/task': 0,
  // 註冊相關頁面不需要權限驗證
  '/signup': 0,
  '/signup/student-id': 0,
};
