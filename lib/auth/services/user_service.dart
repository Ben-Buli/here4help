// user_service.dart
// 處理使用者登入、登出、以及權限等級的服務
// 這個服務會優先從資料庫獲取使用者資訊，SharedPreferences 僅作為備用方案
import 'package:flutter/material.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'auth_service.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService extends ChangeNotifier {
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool isLoading = true;

  UserService() {
    _initializeUser();
  }

  /// 初始化用戶資訊 - 優先從資料庫獲取，備用 SharedPreferences
  Future<void> _initializeUser() async {
    try {
      // 首先嘗試從資料庫獲取最新的用戶資訊
      await _loadUserFromDatabase();
    } catch (e) {
      debugPrint('❌ 從資料庫獲取用戶資訊失敗: $e');
      // 如果資料庫獲取失敗，則從 SharedPreferences 載入
      await _loadUserFromPreferences();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 從資料庫獲取用戶資訊
  Future<void> _loadUserFromDatabase() async {
    try {
      debugPrint('🔍 嘗試從資料庫獲取用戶資訊...');
      final userData = await AuthService.getProfile();

      debugPrint('🔍 從資料庫獲取的原始資料: $userData');
      debugPrint('🔍 avatar_url 欄位值: ${userData['avatar_url']}');

      if (userData.isNotEmpty) {
        _currentUser = UserModel.fromJson(userData);
        debugPrint('✅ 從資料庫成功獲取用戶資訊: ${_currentUser?.name}');
        debugPrint('✅ 用戶頭像 URL: ${_currentUser?.avatar_url}');

        // 如果 avatar_url 是空的，設置默認值
        if (_currentUser?.avatar_url.isEmpty == true) {
          debugPrint('⚠️ avatar_url 是空的，設置默認值');
          _currentUser = _currentUser?.copyWith(
            avatar_url: 'assets/images/avatar/avatar-1.png',
          );
          debugPrint('✅ 已設置默認頭像 URL: ${_currentUser?.avatar_url}');
        }

        // 同時更新 SharedPreferences 作為備用
        await _saveUserToPreferences(_currentUser!);
      } else {
        throw Exception('No user data returned from database');
      }
    } catch (e) {
      debugPrint('❌ 從資料庫獲取用戶資訊失敗: $e');
      rethrow;
    }
  }

  /// 從 SharedPreferences 載入用戶資訊（備用方案）
  Future<void> _loadUserFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final permissionLevel = prefs.getInt('user_permission');
    final avatarUrl = prefs.getString('user_avatarUrl');

    debugPrint(
        '🔍 從 SharedPreferences 載入用戶資訊: email=$email, avatarUrl=$avatarUrl');

    if (email != null) {
      _currentUser = UserModel(
        id: prefs.getInt('user_id') ?? 0,
        name: prefs.getString('user_name') ?? '',
        nickname: prefs.getString('user_nickname') ??
            prefs.getString('user_name') ??
            '',
        email: email,
        phone: prefs.getString('user_phone') ?? '',
        points: prefs.getInt('user_points') ?? 0,
        avatar_url: avatarUrl ?? '',
        status: prefs.getString('user_status') ?? 'active',
        provider: prefs.getString('user_provider') ?? 'email',
        created_at: prefs.getString('user_created_at') ?? '',
        updated_at: prefs.getString('user_updated_at') ?? '',
        referral_code: prefs.getString('user_referral_code'),
        google_id: prefs.getString('user_google_id'),
        primary_language: prefs.getString('user_primaryLang') ?? 'English',
        permission_level: permissionLevel ?? 0,
      );
      debugPrint('✅ 從 SharedPreferences 載入用戶資訊成功: ${_currentUser?.name}');
      debugPrint(
          '✅ 從 SharedPreferences 載入的 avatar_url: ${_currentUser?.avatar_url}');
    } else {
      debugPrint('ℹ️ SharedPreferences 中沒有用戶資訊');
    }
  }

  /// 保存用戶資訊到 SharedPreferences（作為備用）
  Future<void> _saveUserToPreferences(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id);
      await prefs.setString('user_name', user.name);
      await prefs.setString('user_nickname', user.nickname);
      await prefs.setString('user_email', user.email);
      await prefs.setInt('user_points', user.points);
      await prefs.setString('user_avatarUrl', user.avatar_url);
      await prefs.setString('user_primaryLang', user.primary_language);
      await prefs.setInt('user_permission', user.permission_level);
      debugPrint('✅ 用戶資訊已保存到 SharedPreferences');
      debugPrint('✅ 保存的 avatar_url: ${user.avatar_url}');
    } catch (e) {
      debugPrint('❌ 保存用戶資訊到 SharedPreferences 失敗: $e');
    }
  }

  /// 刷新用戶資訊（從資料庫重新獲取）
  Future<void> refreshUserInfo() async {
    try {
      isLoading = true;
      notifyListeners();

      await _loadUserFromDatabase();
      debugPrint('✅ 用戶資訊刷新成功');
    } catch (e) {
      debugPrint('❌ 刷新用戶資訊失敗: $e');
      // 如果刷新失敗，保持當前用戶資訊不變
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(UserModel user) => setUser(user);

  /// 登出使用者
  Future<void> logout(BuildContext context) async {
    try {
      // 清除記憶體中的用戶資訊
      clearUser();

      // 清除 SharedPreferences 中的用戶資訊
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_nickname');
      await prefs.remove('user_email');
      await prefs.remove('user_points');
      await prefs.remove('user_avatarUrl');
      await prefs.remove('user_primaryLang');
      await prefs.remove('user_permission');

      // 清除其他可能的用戶相關緩存
      await prefs.remove('user_phone');
      await prefs.remove('user_status');
      await prefs.remove('user_provider');
      await prefs.remove('user_created_at');
      await prefs.remove('user_updated_at');
      await prefs.remove('user_referral_code');
      await prefs.remove('user_google_id');

      // 清除 AuthService 中的 token
      await AuthService.logout();

      // 清除 Flutter 圖片緩存
      if (context.mounted) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        debugPrint('✅ 已清除 Flutter 圖片緩存');
      }

      // 重置未讀中心為 0
      final placeholder = NotificationServicePlaceholder();
      await placeholder.init(userId: 'placeholder');
      await NotificationCenter().use(placeholder);

      debugPrint('✅ 用戶登出完成，所有緩存已清除');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log out success')),
        );
      }
    } catch (e) {
      debugPrint('❌ 登出失敗: $e');
    }
  }

  /// 設置用戶資訊（登入時使用）
  Future<void> setUser(UserModel user) async {
    debugPrint('🔍 setUser called with ${user.id}');
    debugPrint('🔍 setUser avatar_url: ${user.avatar_url}');

    // 清除舊的圖片緩存（避免顯示前一個用戶的頭像）
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('✅ 已清除圖片緩存以避免顯示舊用戶頭像');

    _currentUser = user;

    // 保存到 SharedPreferences 作為備用
    await _saveUserToPreferences(user);

    // 初始化未讀中心（Socket + 冷啟快照）
    try {
      final svc = SocketNotificationService();
      await svc.init(userId: user.id.toString());
      await NotificationCenter().use(svc);
      await svc.refreshSnapshot();
    } catch (e) {
      // 降級為 0 佔位
      final placeholder = NotificationServicePlaceholder();
      await placeholder.init(userId: 'placeholder');
      await NotificationCenter().use(placeholder);
    }

    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> loginWithEmail(String email, String password) async {
    try {
      final result = await AuthService.login(email, password);
      final userData = result['user'];

      debugPrint('🔍 loginWithEmail 完整 userData: $userData');
      debugPrint('🔍 loginWithEmail userData keys: ${userData.keys.toList()}');

      final avatarUrl = userData['avatar_url'] as String? ?? '';
      debugPrint('🔍 loginWithEmail avatar_url from server: "$avatarUrl"');
      debugPrint('🔍 loginWithEmail avatar_url length: ${avatarUrl.length}');

      final user = UserModel(
        id: userData['id'] as int? ?? 0,
        name: userData['name'] as String? ?? '',
        nickname: userData['nickname'] as String? ??
            userData['name'] as String? ??
            '',
        email: userData['email'] as String? ?? '',
        phone: userData['phone'] as String? ?? '',
        points: (userData['points'] as num?)?.toInt() ?? 0,
        avatar_url: avatarUrl,
        status: userData['status'] as String? ?? 'active',
        provider: userData['provider'] as String? ?? 'email',
        created_at: userData['created_at'] as String? ?? '',
        updated_at: userData['updated_at'] as String? ?? '',
        referral_code: userData['referral_code'] as String?,
        google_id: userData['google_id'] as String?,
        primary_language: userData['primary_language'] as String? ?? 'English',
        permission_level: userData['permission'] as int? ?? 0,
      );

      debugPrint('🔍 創建的 UserModel avatar_url: "${user.avatar_url}"');
      await setUser(user);
      debugPrint(
          '🔍 setUser 完成後的 currentUser avatar_url: "${_currentUser?.avatar_url}"');
      return true;
    } catch (e) {
      debugPrint('❌ Login failed: $e');
      return false;
    }
  }

  int getCurrentPermissionLevel() {
    if (_currentUser == null) {
      return 0; // Default permission level for unauthenticated users
    }
    // Fetch the permission level from the current user
    return _currentUser?.permission_level ?? 0;
  }

  bool get isLoggedIn => _currentUser != null;

  Future<void> ensureUserLoaded() async {
    while (isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
