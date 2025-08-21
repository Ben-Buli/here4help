import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 權限狀態管理 Provider
/// 提供權限變更通知和持久化功能
class PermissionProvider extends ChangeNotifier {
  static PermissionProvider? _instance;

  // 單例模式
  static PermissionProvider get instance {
    _instance ??= PermissionProvider._internal();
    return _instance!;
  }

  PermissionProvider._internal();

  // 當前用戶權限
  int _permission = 0;

  // 用戶資料
  Map<String, dynamic>? _userData;

  // 是否已初始化
  bool _isInitialized = false;

  // Getters
  int get permission => _permission;
  Map<String, dynamic>? get userData => _userData;
  bool get isInitialized => _isInitialized;

  /// 初始化權限狀態
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataString = prefs.getString('user_data');

      if (token != null && userDataString != null) {
        final userData = jsonDecode(userDataString) as Map<String, dynamic>;
        _userData = userData;
        _permission = userData['permission'] ?? 0;

        print('🔐 權限狀態初始化完成: $_permission');
      } else {
        print('🔐 未找到登入資訊，使用預設權限: $_permission');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('❌ 權限狀態初始化失敗: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 更新權限狀態
  void updatePermission(int newPermission) {
    if (_permission != newPermission) {
      _permission = newPermission;
      print('🔐 權限狀態更新: $_permission');
      notifyListeners();
      _savePermissionToStorage();
    }
  }

  /// 更新用戶資料
  void updateUserData(Map<String, dynamic> newUserData) {
    _userData = newUserData;
    final newPermission = newUserData['permission'] ?? 0;

    if (_permission != newPermission) {
      _permission = newPermission;
      print('🔐 用戶資料更新，權限變更: $_permission');
      notifyListeners();
      _savePermissionToStorage();
    } else {
      print('🔐 用戶資料更新，權限未變更: $_permission');
      notifyListeners();
    }
  }

  /// 清除權限狀態（登出時使用）
  void clearPermission() {
    _permission = 0;
    _userData = null;
    _isInitialized = false;
    print('🔐 權限狀態已清除');
    notifyListeners();
    _clearPermissionFromStorage();
  }

  /// 檢查是否有特定權限
  bool hasPermission(int requiredPermission) {
    return _permission >= requiredPermission;
  }

  /// 檢查是否可以訪問聊天功能
  bool canAccessChat() {
    return _permission >= 1;
  }

  /// 檢查是否可以創建任務
  bool canCreateTask() {
    return _permission >= 1;
  }

  /// 檢查是否可以應徵任務
  bool canApplyTask() {
    return _permission >= 1;
  }

  /// 檢查是否可以訪問錢包功能
  bool canAccessWallet() {
    return _permission >= 1;
  }

  /// 檢查是否可以進行支付
  bool canMakePayment() {
    return _permission >= 1;
  }

  /// 檢查是否可以訪問管理功能
  bool canAccessAdmin() {
    return _permission == 99;
  }

  /// 檢查帳號是否有效
  bool isAccountValid() {
    return _permission >= -4;
  }

  /// 檢查帳號是否被停權
  bool isAccountSuspended() {
    return _permission == -1 || _permission == -3;
  }

  /// 檢查帳號是否被刪除
  bool isAccountDeleted() {
    return _permission == -2 || _permission == -4;
  }

  /// 檢查是否需要驗證
  bool needsVerification() {
    return _permission == 0;
  }

  /// 獲取權限狀態描述
  String getPermissionStatus() {
    switch (_permission) {
      case 0:
        return 'Account verification required';
      case 1:
        return 'Account verified';
      case 99:
        return 'Administrator';
      case -1:
        return 'Account suspended by administrator';
      case -2:
        return 'Account removed by administrator';
      case -3:
        return 'Account self-suspended';
      case -4:
        return 'Account self-removed';
      default:
        return 'Unknown permission status';
    }
  }

  /// 獲取權限限制說明
  String getPermissionRestrictions() {
    if (_permission < 1) {
      return 'You need to verify your account to access all features';
    }
    return 'No restrictions';
  }

  /// 保存權限到本地存儲
  Future<void> _savePermissionToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_permission', _permission);

      if (_userData != null) {
        await prefs.setString('user_data', jsonEncode(_userData));
      }

      print('💾 權限狀態已保存到本地存儲');
    } catch (e) {
      print('❌ 保存權限狀態失敗: $e');
    }
  }

  /// 從本地存儲清除權限
  Future<void> _clearPermissionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_permission');
      await prefs.remove('user_data');
      await prefs.remove('auth_token');

      print('🗑️ 權限狀態已從本地存儲清除');
    } catch (e) {
      print('❌ 清除權限狀態失敗: $e');
    }
  }

  /// 從本地存儲載入權限
  Future<void> _loadPermissionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPermission = prefs.getInt('user_permission');

      if (storedPermission != null) {
        _permission = storedPermission;
        print('📱 從本地存儲載入權限: $_permission');
      }
    } catch (e) {
      print('❌ 從本地存儲載入權限失敗: $e');
    }
  }
}
