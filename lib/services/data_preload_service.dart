// data_preload_service.dart
import 'package:here4help/task/services/task_service.dart';

/// 數據預載入服務
///
/// 這個服務確保在用戶進入特定頁面前，所有必要的數據都已經載入完成
/// 避免了頁面載入時的延遲和複雜的非同步狀態管理
class DataPreloadService {
  static final DataPreloadService _instance = DataPreloadService._internal();
  factory DataPreloadService() => _instance;
  DataPreloadService._internal();

  // 追蹤哪些數據已經載入
  final Map<String, bool> _loadedData = {};

  // 載入鎖，防止重複載入
  final Map<String, Future<void>> _loadingFutures = {};

  /// 預載入聊天頁面所需的所有數據
  Future<void> preloadChatData() async {
    const String key = 'chat_data';

    // 如果已經載入或正在載入，直接返回
    if (_loadedData[key] == true) {
      print('✅ 聊天數據已預載入，直接使用快取');
      return;
    }

    if (_loadingFutures[key] != null) {
      print('⏳ 聊天數據正在載入中，等待完成...');
      return await _loadingFutures[key]!;
    }

    // 開始載入
    print('🔄 開始預載入聊天數據...');
    _loadingFutures[key] = _loadChatDataInternal();

    try {
      await _loadingFutures[key]!;
      _loadedData[key] = true;
      print('✅ 聊天數據預載入完成');
    } catch (e) {
      print('❌ 聊天數據預載入失敗: $e');
      _loadedData[key] = false;
    } finally {
      _loadingFutures.remove(key);
    }
  }

  /// 內部實際載入邏輯
  Future<void> _loadChatDataInternal() async {
    // 並行載入任務和狀態
    await Future.wait([
      TaskService().loadTasks(),
      TaskService().loadStatuses(),
    ]);

    print('✅ 任務和狀態載入完成');
  }

  /// 預載入任務頁面數據
  Future<void> preloadTaskData() async {
    const String key = 'task_data';

    if (_loadedData[key] == true) {
      print('✅ 任務數據已預載入，直接使用快取');
      return;
    }

    if (_loadingFutures[key] != null) {
      print('⏳ 任務數據正在載入中，等待完成...');
      return await _loadingFutures[key]!;
    }

    print('🔄 開始預載入任務數據...');
    _loadingFutures[key] = TaskService().loadTasks();

    try {
      await _loadingFutures[key]!;
      _loadedData[key] = true;
      print('✅ 任務數據預載入完成');
    } catch (e) {
      print('❌ 任務數據預載入失敗: $e');
      _loadedData[key] = false;
    } finally {
      _loadingFutures.remove(key);
    }
  }

  /// 檢查特定數據是否已載入
  bool isDataLoaded(String dataKey) {
    return _loadedData[dataKey] == true;
  }

  /// 清除所有預載入數據（用於登出或數據刷新）
  void clearAllData() {
    _loadedData.clear();
    _loadingFutures.clear();
    print('🧹 已清除所有預載入數據');
  }

  /// 清除特定數據
  void clearData(String dataKey) {
    _loadedData.remove(dataKey);
    _loadingFutures.remove(dataKey);
    print('🧹 已清除 $dataKey 預載入數據');
  }

  /// 根據路由自動預載入對應數據
  Future<void> preloadForRoute(String route) async {
    print('📍 為路由 $route 預載入數據');

    switch (route) {
      case '/chat':
      case '/chat/my-works':
      case '/chat/posted-tasks':
        await preloadChatData();
        break;
      case '/task':
        await preloadTaskData();
        break;
      case '/home':
        // Home 頁面可能需要多種數據
        await Future.wait([
          preloadTaskData(),
          preloadChatData(),
        ]);
        break;
      default:
        print('📍 路由 $route 無需預載入數據');
    }
  }
}
