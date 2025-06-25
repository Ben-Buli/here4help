// user_service.dart
// 處理使用者登入、登出、以及權限等級的服務
// 這個服務會在登入時更新使用者資訊，並提供當前使用者的權限等級。
import 'package:flutter/material.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:here4help/constants/demo_users.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService extends ChangeNotifier {
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool isLoading = true;

  UserService() {
    _loadUserFromPreferences(); // 僅載入使用者資訊，不執行登出
  }

  Future<void> _loadUserFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final permissionLevel = prefs.getInt('user_permission');
    debugPrint(
        'Loading user preferences: email=$email, permissionLevel=$permissionLevel');
    if (email != null) {
      _currentUser = UserModel(
        id: prefs.getInt('user_id') ?? 0, // 預設 ID 為 0
        name: prefs.getString('user_name') ?? '',
        email: email,
        points: prefs.getInt('user_points') ?? 0,
        avatar_url: prefs.getString('user_avatarUrl') ?? '',
        primary_language: prefs.getString('user_primaryLang') ?? '',
        permission_level: permissionLevel ?? 0, // 預設權限等級為 0
      );
      debugPrint('User loaded: $_currentUser');
      isLoading = false;
      notifyListeners();
    } else {
      debugPrint('No user found in preferences');
    }
  }

  Future<void> login(UserModel user) => setUser(user);

  /// 登出使用者
  Future<void> logout(BuildContext context) async {
    clearUser();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_points');
    await prefs.remove('user_avatarUrl');
    await prefs.remove('user_primaryLang');
    await prefs.remove('user_permission');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log out success')),
    );
  }

  Future<void> setUser(UserModel user) async {
    debugPrint('setUser called with ${user.id}');
    _currentUser = UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      points: user.points,
      avatar_url: user.avatar_url,
      primary_language: user.primary_language,
      permission_level: user.permission_level,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', user.id);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
    await prefs.setInt('user_points', user.points);
    await prefs.setString('user_avatarUrl', user.avatar_url);
    await prefs.setString('user_primaryLang', user.primary_language);
    await prefs.setInt('user_permission', user.permission_level);
    debugPrint('User saved to preferences: $user');
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> loginWithEmail(String email, String password) async {
    final matchedAccount = testAccounts.firstWhere(
      (acc) => acc['email'] == email && acc['password'] == password,
      orElse: () => {},
    );
    if (matchedAccount.isNotEmpty) {
      setUser(UserModel(
        id: matchedAccount['id'] as int? ?? 0,
        name: matchedAccount['name'] as String,
        email: matchedAccount['email'] as String,
        points: (matchedAccount['points'] as num).toInt(),
        avatar_url: (matchedAccount['avatar_url'] ?? '') as String,
        primary_language:
            (matchedAccount['language_requirement'] ?? '') as String,
        permission_level: matchedAccount['permission'] as int,
      ));
      return true;
    }
    return false;
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
