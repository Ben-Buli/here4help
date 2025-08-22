import '../cache/cache_manager.dart';
import '../offline/offline_manager.dart';

/// 離線感知的 API 服務基類
/// 提供自動快取和離線支援功能
abstract class OfflineAwareApi {
  final CacheManager _cacheManager = CacheManager.instance;
  final OfflineManager _offlineManager = OfflineManager.instance;

  /// 執行帶快取的 GET 請求
  Future<Map<String, dynamic>> cachedGet({
    required String endpoint,
    required String cacheKey,
    Duration? cacheExpiry,
    bool forceRefresh = false,
  }) async {
    try {
      // 檢查網路狀態
      final isOnline = _offlineManager.isOnline;

      // 如果離線或不強制刷新，嘗試從快取獲取
      if (!isOnline || !forceRefresh) {
        final cachedData = await _getCachedResponse(cacheKey);
        if (cachedData != null) {
          return {
            'success': true,
            'data': cachedData,
            'fromCache': true,
            'isOffline': !isOnline,
          };
        }
      }

      // 如果離線且沒有快取，返回離線錯誤
      if (!isOnline) {
        return {
          'success': false,
          'message': '無網路連接且無快取資料',
          'isOffline': true,
        };
      }

      // 執行網路請求
      final response = await performGetRequest(endpoint);

      if (response['success'] == true) {
        // 快取成功的回應
        await _cacheResponse(
          cacheKey: cacheKey,
          data: response['data'],
          expiry: cacheExpiry,
        );

        return {
          ...response,
          'fromCache': false,
          'isOffline': false,
        };
      }

      // 網路請求失敗，嘗試返回快取資料
      final cachedData = await _getCachedResponse(cacheKey);
      if (cachedData != null) {
        return {
          'success': true,
          'data': cachedData,
          'fromCache': true,
          'isOffline': false,
          'warning': '網路請求失敗，返回快取資料',
        };
      }

      return response;
    } catch (e) {
      // 發生異常，嘗試返回快取資料
      final cachedData = await _getCachedResponse(cacheKey);
      if (cachedData != null) {
        return {
          'success': true,
          'data': cachedData,
          'fromCache': true,
          'isOffline': _offlineManager.isOffline,
          'warning': '請求異常，返回快取資料: $e',
        };
      }

      return {
        'success': false,
        'message': '請求失敗且無快取資料: $e',
        'isOffline': _offlineManager.isOffline,
      };
    }
  }

  /// 執行帶離線支援的 POST 請求
  Future<Map<String, dynamic>> offlineAwarePost({
    required String endpoint,
    required Map<String, dynamic> data,
    bool allowOfflineQueue = true,
    String? offlineActionType,
  }) async {
    try {
      // 檢查網路狀態
      if (!_offlineManager.isOnline) {
        if (allowOfflineQueue) {
          // 添加到離線佇列
          await _offlineManager.addOfflineAction(
            type: offlineActionType ?? 'api_call',
            endpoint: endpoint,
            data: data,
          );

          return {
            'success': true,
            'message': '已添加到離線佇列，將在網路恢復時自動執行',
            'isOffline': true,
            'queued': true,
          };
        } else {
          return {
            'success': false,
            'message': '無網路連接',
            'isOffline': true,
          };
        }
      }

      // 執行網路請求
      final response = await performPostRequest(endpoint, data);

      return {
        ...response,
        'isOffline': false,
        'queued': false,
      };
    } catch (e) {
      if (allowOfflineQueue && !_offlineManager.isOnline) {
        // 網路異常，添加到離線佇列
        await _offlineManager.addOfflineAction(
          type: offlineActionType ?? 'api_call',
          endpoint: endpoint,
          data: data,
        );

        return {
          'success': true,
          'message': '網路異常，已添加到離線佇列',
          'isOffline': true,
          'queued': true,
        };
      }

      return {
        'success': false,
        'message': '請求失敗: $e',
        'isOffline': _offlineManager.isOffline,
      };
    }
  }

  /// 執行帶快取的列表請求
  Future<Map<String, dynamic>> cachedListGet({
    required String endpoint,
    required String listType,
    int page = 1,
    int perPage = 20,
    Duration? cacheExpiry,
    bool forceRefresh = false,
  }) async {
    try {
      final isOnline = _offlineManager.isOnline;

      // 離線或不強制刷新時，嘗試從快取獲取
      if (!isOnline || !forceRefresh) {
        final cachedList = await _getCachedListResponse(listType);
        if (cachedList != null) {
          // 實現分頁邏輯
          final startIndex = (page - 1) * perPage;
          final paginatedItems =
              cachedList.skip(startIndex).take(perPage).toList();

          return {
            'success': true,
            'data': {
              'items': paginatedItems,
              'pagination': {
                'current_page': page,
                'per_page': perPage,
                'total': cachedList.length,
                'total_pages': (cachedList.length / perPage).ceil(),
              }
            },
            'fromCache': true,
            'isOffline': !isOnline,
          };
        }
      }

      if (!isOnline) {
        return {
          'success': false,
          'message': '無網路連接且無快取資料',
          'isOffline': true,
        };
      }

      // 執行網路請求
      final response = await performListRequest(endpoint, page, perPage);

      if (response['success'] == true) {
        final responseData = response['data'];
        final items = responseData['items'] as List<dynamic>?;

        if (items != null) {
          // 快取列表資料
          await _cacheListResponse(
            listType: listType,
            items: items.cast<Map<String, dynamic>>(),
            expiry: cacheExpiry,
          );
        }

        return {
          ...response,
          'fromCache': false,
          'isOffline': false,
        };
      }

      // 網路請求失敗，嘗試返回快取資料
      final cachedList = await _getCachedListResponse(listType);
      if (cachedList != null) {
        final startIndex = (page - 1) * perPage;
        final paginatedItems =
            cachedList.skip(startIndex).take(perPage).toList();

        return {
          'success': true,
          'data': {
            'items': paginatedItems,
            'pagination': {
              'current_page': page,
              'per_page': perPage,
              'total': cachedList.length,
              'total_pages': (cachedList.length / perPage).ceil(),
            }
          },
          'fromCache': true,
          'isOffline': false,
          'warning': '網路請求失敗，返回快取資料',
        };
      }

      return response;
    } catch (e) {
      // 異常處理，嘗試返回快取資料
      final cachedList = await _getCachedListResponse(listType);
      if (cachedList != null) {
        final startIndex = (page - 1) * perPage;
        final paginatedItems =
            cachedList.skip(startIndex).take(perPage).toList();

        return {
          'success': true,
          'data': {
            'items': paginatedItems,
            'pagination': {
              'current_page': page,
              'per_page': perPage,
              'total': cachedList.length,
              'total_pages': (cachedList.length / perPage).ceil(),
            }
          },
          'fromCache': true,
          'isOffline': _offlineManager.isOffline,
          'warning': '請求異常，返回快取資料: $e',
        };
      }

      return {
        'success': false,
        'message': '請求失敗且無快取資料: $e',
        'isOffline': _offlineManager.isOffline,
      };
    }
  }

  /// 快取回應資料
  Future<void> _cacheResponse({
    required String cacheKey,
    required dynamic data,
    Duration? expiry,
  }) async {
    try {
      if (data is Map<String, dynamic>) {
        await _cacheManager.cacheUserProfile(
          userId: cacheKey.hashCode,
          profile: data,
          expiry: expiry ?? CacheManager.defaultExpiry,
        );
      }
    } catch (e) {
      print('快取回應失敗: $e');
    }
  }

  /// 獲取快取的回應資料
  Future<Map<String, dynamic>?> _getCachedResponse(String cacheKey) async {
    try {
      return await _cacheManager.getCachedUserProfile(cacheKey.hashCode);
    } catch (e) {
      print('獲取快取回應失敗: $e');
      return null;
    }
  }

  /// 快取列表回應資料
  Future<void> _cacheListResponse({
    required String listType,
    required List<Map<String, dynamic>> items,
    Duration? expiry,
  }) async {
    try {
      switch (listType) {
        case 'tasks':
          await _cacheManager.cacheTaskList(
            listType: 'all',
            tasks: items,
            expiry: expiry,
          );
          break;
        case 'chats':
          await _cacheManager.cacheChatList(
            chats: items,
            expiry: expiry,
          );
          break;
        case 'notifications':
          await _cacheManager.cacheNotificationList(
            notifications: items,
            expiry: expiry,
          );
          break;
        default:
          // 使用通用快取
          await _cacheManager.cacheTaskList(
            listType: listType,
            tasks: items,
            expiry: expiry,
          );
      }
    } catch (e) {
      print('快取列表回應失敗: $e');
    }
  }

  /// 獲取快取的列表回應資料
  Future<List<Map<String, dynamic>>?> _getCachedListResponse(
      String listType) async {
    try {
      switch (listType) {
        case 'tasks':
          return await _cacheManager.getCachedTaskList('all');
        case 'chats':
          return await _cacheManager.getCachedChatList();
        case 'notifications':
          return await _cacheManager.getCachedNotificationList();
        default:
          return await _cacheManager.getCachedTaskList(listType);
      }
    } catch (e) {
      print('獲取快取列表回應失敗: $e');
      return null;
    }
  }

  /// 使快取失效
  Future<void> invalidateCache(String pattern) async {
    await _cacheManager.invalidateCache(pattern);
  }

  /// 子類需要實現的抽象方法

  /// 執行 GET 請求
  Future<Map<String, dynamic>> performGetRequest(String endpoint);

  /// 執行 POST 請求
  Future<Map<String, dynamic>> performPostRequest(
      String endpoint, Map<String, dynamic> data);

  /// 執行列表請求
  Future<Map<String, dynamic>> performListRequest(
      String endpoint, int page, int perPage);
}
