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
        // 優先取 user_data.permission，若缺失則回退到 user_permission（備援）
        _permission = (userData['permission'] ??
            prefs.getInt('user_permission') ??
            0) as int;

        print('🔐 權限狀態初始化完成: $_permission');
      } else {
        // 未登入或 user_data 缺失，嘗試從備援欄位載入權限
        final fallbackPermission = prefs.getInt('user_permission');
        if (fallbackPermission != null) {
          _permission = fallbackPermission;
          print('🔐 從備援欄位載入權限: $_permission');
        } else {
          print('🔐 未找到登入資訊，使用預設權限: $_permission');
        }
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

  /// 獲取權限狀態描述 (軟刪除不可登入、停權可登入)
  String getPermissionStatus() {
    switch (_permission) {
      case 0:
        return 'Account verification required';
      case 1:
        return 'Account verified';
      case 99:
        return 'Administrator';
      // case -1:
      //   return 'Account suspended by administrator';
      case -2:
        return 'Account removed by administrator';
      // case -3:
      //   return 'Account self-suspended';
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

  /// 同步後端權限狀態
  /// 當收到後端 API 響應時，確保前端權限狀態與後端一致
  void syncWithBackendResponse(Map<String, dynamic> apiResponse) {
    try {
      // 檢查 API 響應中是否包含權限資訊
      if (apiResponse.containsKey('permission')) {
        final backendPermission = apiResponse['permission'] as int?;
        if (backendPermission != null && backendPermission != _permission) {
          print('🔄 同步後端權限狀態: $_permission -> $backendPermission');
          updatePermission(backendPermission);
        }
      }

      // 檢查 API 響應中是否包含用戶資料
      if (apiResponse.containsKey('user_data')) {
        final userData = apiResponse['user_data'] as Map<String, dynamic>?;
        if (userData != null) {
          updateUserData(userData);
        }
      }

      // 檢查 API 響應中是否包含用戶資訊（直接包含權限）
      if (apiResponse.containsKey('user')) {
        final user = apiResponse['user'] as Map<String, dynamic>?;
        if (user != null && user.containsKey('permission')) {
          final userPermission = user['permission'] as int?;
          if (userPermission != null && userPermission != _permission) {
            print('🔄 同步用戶權限狀態: $_permission -> $userPermission');
            updatePermission(userPermission);
          }
        }
      }
    } catch (e) {
      print('❌ 同步後端權限狀態失敗: $e');
    }
  }

  /// 檢查權限狀態是否與後端一致
  /// 用於調試和驗證權限同步是否正常
  bool isPermissionConsistent(int expectedPermission) {
    return _permission == expectedPermission;
  }

  /// 強制更新權限狀態（用於特殊情況）
  /// 通常不建議直接使用，優先使用 syncWithBackendResponse
  void forceUpdatePermission(int newPermission) {
    print('⚠️ 強制更新權限狀態: $_permission -> $newPermission');
    _permission = newPermission;
    notifyListeners();
    _savePermissionToStorage();
  }
}
