import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';

class ChatCacheManager extends ChangeNotifier {
  static const String _postedTasksKey = 'chat_posted_tasks_cache';
  static const String _myWorksKey = 'chat_my_works_cache';
  static const String _lastUpdateKey = 'chat_last_update';
  static const String _cacheVersionKey = 'chat_cache_version';
  
  // 快取數據
  List<Map<String, dynamic>> _postedTasksCache = [];
  List<Map<String, dynamic>> _myWorksCache = [];
  DateTime? _lastUpdate;
  String _cacheVersion = '1.0.0';
  
  // 更新狀態
  bool _isUpdating = false;
  bool _hasNewData = false;
  String? _updateMessage;
  
  // Getters
  List<Map<String, dynamic>> get postedTasksCache => _postedTasksCache;
  List<Map<String, dynamic>> get myWorksCache => _myWorksCache;
  DateTime? get lastUpdate => _lastUpdate;
  bool get isUpdating => _isUpdating;
  bool get hasNewData => _hasNewData;
  String? get updateMessage => _updateMessage;
  
  // 快取是否有效（24小時內）
  bool get isCacheValid {
    if (_lastUpdate == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_lastUpdate!);
    return difference.inHours < 24;
  }
  
  // 快取是否為空
  bool get isCacheEmpty => _postedTasksCache.isEmpty && _myWorksCache.isEmpty;
  
  ChatCacheManager() {
    _loadCacheFromStorage();
  }
  
  /// 從本地儲存載入快取
  Future<void> _loadCacheFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 載入快取版本
      _cacheVersion = prefs.getString(_cacheVersionKey) ?? '1.0.0';
      
      // 載入最後更新時間
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      if (lastUpdateStr != null) {
        _lastUpdate = DateTime.parse(lastUpdateStr);
      }
      
      // 載入 Posted Tasks 快取
      final postedTasksStr = prefs.getString(_postedTasksKey);
      if (postedTasksStr != null) {
        _postedTasksCache = List<Map<String, dynamic>>.from(
          jsonDecode(postedTasksStr).map((x) => Map<String, dynamic>.from(x))
        );
      }
      
      // 載入 My Works 快取
      final myWorksStr = prefs.getString(_myWorksKey);
      if (myWorksStr != null) {
        _myWorksCache = List<Map<String, dynamic>>.from(
          jsonDecode(myWorksStr).map((x) => Map<String, dynamic>.from(x))
        );
      }
      
      debugPrint('📱 快取載入完成: Posted Tasks: ${_postedTasksCache.length}, My Works: ${_myWorksCache.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 快取載入失敗: $e');
    }
  }
  
  /// 儲存快取到本地儲存
  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 儲存快取版本
      await prefs.setString(_cacheVersionKey, _cacheVersion);
      
      // 儲存最後更新時間
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      
      // 儲存 Posted Tasks 快取
      await prefs.setString(_postedTasksKey, jsonEncode(_postedTasksCache));
      
      // 儲存 My Works 快取
      await prefs.setString(_myWorksKey, jsonEncode(_myWorksCache));
      
      debugPrint('💾 快取儲存完成');
    } catch (e) {
      debugPrint('❌ 快取儲存失敗: $e');
    }
  }
  
  /// 初始化快取（App 啟動時調用）
  Future<void> initializeCache() async {
    if (_isUpdating) return;
    
    _setUpdating(true);
    
    try {
      debugPrint('🚀 開始初始化快取...');
      
      // 如果快取有效，直接返回
      if (isCacheValid && !isCacheEmpty) {
        debugPrint('✅ 快取有效，使用現有快取');
        _setUpdating(false);
        return;
      }
      
      // 載入完整數據
      await _loadFullData();
      
      // 儲存快取
      await _saveCacheToStorage();
      
      debugPrint('🎉 快取初始化完成');
    } catch (e) {
      debugPrint('❌ 快取初始化失敗: $e');
    } finally {
      _setUpdating(false);
    }
  }
  
  /// 載入完整數據
  Future<void> _loadFullData() async {
    final taskService = TaskService();
    
    // 載入任務和狀態
    await Future.wait([
      taskService.loadTasks(),
      taskService.loadStatuses(),
    ]);
    
    // 載入 Posted Tasks 數據
    await _loadPostedTasksData();
    
    // 載入 My Works 數據
    await _loadMyWorksData();
  }
  
  /// 載入 Posted Tasks 數據
  Future<void> _loadPostedTasksData() async {
    try {
      final userService = UserService();
      final currentUserId = userService.currentUser?.id;
      if (currentUserId == null) return;
      
      final taskService = TaskService();
      
      // 獲取我發布的任務
      final myPostedTasks = taskService.tasks.where((task) {
        final creatorId = task['creator_id'];
        return creatorId == currentUserId ||
            creatorId?.toString() == currentUserId.toString();
      }).toList();
      
      // 載入每個任務的應徵者資料
      final tasksWithApplications = <Map<String, dynamic>>[];
      
      for (final task in myPostedTasks) {
        try {
          final applications = await taskService.loadApplicationsByTask(task['id'].toString());
          final taskWithApplications = Map<String, dynamic>.from(task);
          taskWithApplications['applications'] = applications;
          tasksWithApplications.add(taskWithApplications);
        } catch (e) {
          debugPrint('Failed to load applications for task ${task['id']}: $e');
          tasksWithApplications.add(task);
        }
      }
      
      _postedTasksCache = tasksWithApplications;
      debugPrint('📋 Posted Tasks 數據載入完成: ${_postedTasksCache.length} 個任務');
    } catch (e) {
      debugPrint('❌ Posted Tasks 數據載入失敗: $e');
    }
  }
  
  /// 載入 My Works 數據
  Future<void> _loadMyWorksData() async {
    try {
      final userService = UserService();
      final currentUserId = userService.currentUser?.id;
      if (currentUserId == null) return;
      
      final taskService = TaskService();
      await taskService.loadMyApplications(currentUserId);
      
      _myWorksCache = _composeMyWorks(taskService, currentUserId);
      debugPrint('📋 My Works 數據載入完成: ${_myWorksCache.length} 個任務');
    } catch (e) {
      debugPrint('❌ My Works 數據載入失敗: $e');
    }
  }
  
  /// 整理 My Works 清單
  List<Map<String, dynamic>> _composeMyWorks(TaskService service, int? currentUserId) {
    final apps = service.myApplications;
    
    if (apps.isEmpty) {
      return [];
    }
    
    return apps.map((app) {
      return {
        'id': app['id'],
        'title': app['title'],
        'description': app['description'],
        'reward_point': app['reward_point'],
        'location': app['location'],
        'task_date': app['task_date'],
        'language_requirement': app['language_requirement'],
        'status_code': app['client_status_code'] ?? app['status_code'],
        'status_display': app['client_status_display'] ?? app['status_display'],
        'creator_id': app['creator_id'],
        'creator_name': app['creator_name'],
        'creator_avatar': app['creator_avatar'],
        'applied_by_me': true,
        'application_id': app['application_id'],
        'application_status': app['application_status'],
        'application_created_at': app['application_created_at'],
        'application_updated_at': app['application_updated_at'],
      };
    }).toList();
  }
  
  /// 輕量檢查更新（進入頁面後調用）
  Future<void> checkForUpdates() async {
    if (_isUpdating) return;
    
    _setUpdating(true);
    _setUpdateMessage('檢查更新中...');
    
    try {
      debugPrint('🔍 開始輕量檢查更新...');
      
      // 檢查是否有新數據
      final hasUpdates = await _checkForDataUpdates();
      
      if (hasUpdates) {
        debugPrint('🔄 發現新數據，開始更新...');
        await _performIncrementalUpdate();
        _setHasNewData(true);
        _setUpdateMessage('數據已更新');
      } else {
        debugPrint('✅ 已是最新數據');
        _setUpdateMessage('已是最新');
        _setHasNewData(false);
      }
      
      // 更新最後更新時間
      _lastUpdate = DateTime.now();
      await _saveCacheToStorage();
      
    } catch (e) {
      debugPrint('❌ 檢查更新失敗: $e');
      _setUpdateMessage('檢查更新失敗');
    } finally {
      _setUpdating(false);
      
      // 3秒後清除更新訊息
      Future.delayed(const Duration(seconds: 3), () {
        _setUpdateMessage(null);
        notifyListeners();
      });
    }
  }
  
  /// 檢查數據是否有更新
  Future<bool> _checkForDataUpdates() async {
    try {
      // 這裡可以實現更複雜的更新檢查邏輯
      // 例如：檢查 updated_after 時間戳、檢查應徵者數量變化等
      
      // 簡單實現：檢查快取是否過期
      if (!isCacheValid) {
        return true;
      }
      
      // 可以添加其他檢查邏輯
      // 例如：檢查是否有新的應徵者
      
      return false;
    } catch (e) {
      debugPrint('❌ 檢查數據更新失敗: $e');
      return false;
    }
  }
  
  /// 執行增量更新
  Future<void> _performIncrementalUpdate() async {
    try {
      // 只更新變更的部分
      await _loadPostedTasksData();
      await _loadMyWorksData();
      
      debugPrint('🔄 增量更新完成');
    } catch (e) {
      debugPrint('❌ 增量更新失敗: $e');
      // 如果增量更新失敗，回退到完整更新
      await _loadFullData();
    }
  }
  
  /// 強制刷新（pull-to-refresh 時調用）
  Future<void> forceRefresh() async {
    if (_isUpdating) return;
    
    _setUpdating(true);
    _setUpdateMessage('正在刷新...');
    
    try {
      debugPrint('🔄 開始強制刷新...');
      
      await _loadFullData();
      await _saveCacheToStorage();
      
      _setHasNewData(true);
      _setUpdateMessage('刷新完成');
      
      debugPrint('🎉 強制刷新完成');
    } catch (e) {
      debugPrint('❌ 強制刷新失敗: $e');
      _setUpdateMessage('刷新失敗');
    } finally {
      _setUpdating(false);
      
      // 2秒後清除更新訊息
      Future.delayed(const Duration(seconds: 2), () {
        _setUpdateMessage(null);
        notifyListeners();
      });
    }
  }
  
  /// 清除快取
  Future<void> clearCache() async {
    try {
      _postedTasksCache.clear();
      _myWorksCache.clear();
      _lastUpdate = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_postedTasksKey);
      await prefs.remove(_myWorksKey);
      await prefs.remove(_lastUpdateKey);
      
      debugPrint('🗑️ 快取已清除');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 清除快取失敗: $e');
    }
  }
  
  /// 設置更新狀態
  void _setUpdating(bool value) {
    _isUpdating = value;
    notifyListeners();
  }
  
  /// 設置新數據狀態
  void _setHasNewData(bool value) {
    _hasNewData = value;
    notifyListeners();
  }
  
  /// 設置更新訊息
  void _setUpdateMessage(String? message) {
    _updateMessage = message;
    notifyListeners();
  }
  
  /// 手動觸發更新（例如：有人應徵時）
  Future<void> triggerUpdate() async {
    debugPrint('🔔 手動觸發更新');
    await checkForUpdates();
  }
}
