/// 每條路由對應所需的最低權限等級
///COMMENT '0=新用戶未認證, 1=已認證用戶, 99=管理員, -1=被管理員停權, -2=被管理員軟刪除, -3=用戶自行停權, -4=用戶自行軟刪除'
final Map<String, int> routePermissions = {
  '/home': 1,
  '/task': 0,
  // 註冊相關頁面不需要權限驗證
  '/signup': 0,
  '/signup/student-id': 0,
};
