import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/chat/services/unified_chat_api_service.dart';

/// 統一數據持久化管理器 - 遵循聊天系統規格文件標準
/// 
/// 實現規格文件的持久化策略：
/// - prefer_local: 優先讀本地快取
/// - auto_save: API 成功回寫本地
/// - incremental: 僅更新差異
class UnifiedPersistenceManager {
  static const String _tag = '[UnifiedPersistenceManager]';
  
  // 快取鍵定義
  static const String _unreadCacheKey = 'unified_unread_cache';
  static const String _chatRoomsCacheKey = 'unified_chat_rooms_cache';
  static const String _lastSyncTimeKey = 'unified_last_sync_time';
  
  // 快取過期時間（分鐘）
  static const int _cacheExpiryMinutes = 5;
  
  /// 獲取未讀數據 - 實現 prefer_local 策略
  static Future<Map<String, dynamic>?> getUnreadData({
    String scope = 'all',
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('$_tag 獲取未讀數據: scope=$scope, forceRefresh=$forceRefresh');
      
      if (!forceRefresh) {
        // 嘗試從本地快取讀取
        final cachedData = await _getCachedUnreadData(scope);
        if (cachedData != null) {
          debugPrint('✅ $_tag 從本地快取載入未讀數據');
          return cachedData;
        }
      }
      
      // 從 API 獲取數據
      debugPrint('🌐 $_tag 從 API 獲取未讀數據');
      final apiData = await UnifiedChatApiService.getUnreadCounts(scope: scope);
      
      // auto_save: API 成功回寫本地
      await _cacheUnreadData(scope, apiData);
      debugPrint('✅ $_tag API 數據已保存到本地快取');
      
      return apiData;
    } catch (e) {
      debugPrint('❌ $_tag 獲取未讀數據失敗: $e');
      
      // 降級到本地快取（忽略過期時間）
      final fallbackData = await _getCachedUnreadData(scope, ignoreExpiry: true);
      if (fallbackData != null) {
        debugPrint('🔄 $_tag 使用過期快取數據作為降級');
        return fallbackData;
      }
      
      rethrow;
    }
  }
  
  /// 獲取聊天室列表 - 實現 prefer_local 策略
  static Future<List<Map<String, dynamic>>> getChatRooms({
    required String scope,
    bool withUnread = true,
    bool forceRefresh = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('$_tag 獲取聊天室列表: scope=$scope, forceRefresh=$forceRefresh');
      
      if (!forceRefresh && offset == 0) {
        // 只有第一頁才使用快取
        final cachedData = await _getCachedChatRooms(scope);
        if (cachedData != null) {
          debugPrint('✅ $_tag 從本地快取載入聊天室列表');
          return cachedData;
        }
      }
      
      // 從 API 獲取數據
      debugPrint('🌐 $_tag 從 API 獲取聊天室列表');
      final apiResponse = await UnifiedChatApiService.getChatRooms(
        scope: scope,
        withUnread: withUnread,
        limit: limit,
        offset: offset,
      );
      
      final rooms = (apiResponse['rooms'] as List?)
          ?.map((r) => Map<String, dynamic>.from(r))
          .toList() ?? [];
      
      // auto_save: 只快取第一頁數據
      if (offset == 0) {
        await _cacheChatRooms(scope, rooms);
        debugPrint('✅ $_tag 聊天室列表已保存到本地快取');
      }
      
      return rooms;
    } catch (e) {
      debugPrint('❌ $_tag 獲取聊天室列表失敗: $e');
      
      // 降級到本地快取
      if (offset == 0) {
        final fallbackData = await _getCachedChatRooms(scope, ignoreExpiry: true);
        if (fallbackData != null) {
          debugPrint('🔄 $_tag 使用過期快取數據作為降級');
          return fallbackData;
        }
      }
      
      rethrow;
    }
  }
  
  /// 標記聊天室已讀 - 實現 incremental 策略
  static Future<Map<String, dynamic>> markRoomAsRead({
    required String roomId,
    int? upToMessageId,
  }) async {
    try {
      debugPrint('$_tag 標記聊天室已讀: roomId=$roomId');
      
      // 調用 API
      final result = await UnifiedChatApiService.markRoomAsRead(
        roomId: roomId,
        upToMessageId: upToMessageId,
      );
      
      // incremental: 更新本地快取中的未讀數據
      await _incrementalUpdateUnreadCache(roomId, 0);
      debugPrint('✅ $_tag 本地未讀快取已增量更新');
      
      return result;
    } catch (e) {
      debugPrint('❌ $_tag 標記聊天室已讀失敗: $e');
      rethrow;
    }
  }
  
  /// 批量獲取所有數據 - 優化網路請求
  static Future<Map<String, dynamic>> getAllData({
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('$_tag 批量獲取所有數據: forceRefresh=$forceRefresh');
      
      if (!forceRefresh) {
        // 檢查本地快取
        final cachedUnread = await _getCachedUnreadData('all');
        final cachedPostedRooms = await _getCachedChatRooms('posted');
        final cachedMyWorksRooms = await _getCachedChatRooms('myworks');
        
        if (cachedUnread != null && cachedPostedRooms != null && cachedMyWorksRooms != null) {
          debugPrint('✅ $_tag 從本地快取載入所有數據');
          return {
            'unread': cachedUnread,
            'posted_rooms': cachedPostedRooms,
            'myworks_rooms': cachedMyWorksRooms,
            'source': 'cache',
          };
        }
      }
      
      // 從 API 並發獲取所有數據
      debugPrint('🌐 $_tag 並發獲取所有 API 數據');
      final futures = await Future.wait([
        UnifiedChatApiService.getAllUnreadData(),
        getChatRooms(scope: 'posted', forceRefresh: true),
        getChatRooms(scope: 'myworks', forceRefresh: true),
      ]);
      
      final unreadData = futures[0] as Map<String, dynamic>;
      final postedRooms = futures[1] as List<Map<String, dynamic>>;
      final myWorksRooms = futures[2] as List<Map<String, dynamic>>;
      
      debugPrint('✅ $_tag 所有 API 數據獲取完成');
      
      return {
        'unread': unreadData,
        'posted_rooms': postedRooms,
        'myworks_rooms': myWorksRooms,
        'source': 'api',
      };
    } catch (e) {
      debugPrint('❌ $_tag 批量獲取數據失敗: $e');
      rethrow;
    }
  }
  
  /// 清除所有快取
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_unreadCacheKey),
        prefs.remove(_chatRoomsCacheKey),
        prefs.remove(_lastSyncTimeKey),
      ]);
      debugPrint('✅ $_tag 所有快取已清除');
    } catch (e) {
      debugPrint('❌ $_tag 清除快取失敗: $e');
    }
  }
  
  /// 強制同步所有數據
  static Future<void> forceSyncAll() async {
    try {
      debugPrint('$_tag 開始強制同步所有數據');
      await getAllData(forceRefresh: true);
      
      // 更新同步時間
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('✅ $_tag 強制同步完成');
    } catch (e) {
      debugPrint('❌ $_tag 強制同步失敗: $e');
      rethrow;
    }
  }
  
  // ==================== 私有方法 ====================
  
  /// 獲取快取的未讀數據
  static Future<Map<String, dynamic>?> _getCachedUnreadData(
    String scope, {
    bool ignoreExpiry = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_unreadCacheKey}_$scope';
      final cached = prefs.getString(cacheKey);
      
      if (cached == null) return null;
      
      final data = json.decode(cached) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int?;
      
      // 檢查過期時間
      if (!ignoreExpiry && timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        final ageMinutes = age / (1000 * 60);
        
        if (ageMinutes > _cacheExpiryMinutes) {
          debugPrint('🔄 $_tag 快取已過期: ${ageMinutes.toStringAsFixed(1)} 分鐘');
          return null;
        }
      }
      
      return data['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ $_tag 讀取未讀快取失敗: $e');
      return null;
    }
  }
  
  /// 快取未讀數據
  static Future<void> _cacheUnreadData(String scope, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_unreadCacheKey}_$scope';
      
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(cacheKey, json.encode(cacheData));
    } catch (e) {
      debugPrint('❌ $_tag 快取未讀數據失敗: $e');
    }
  }
  
  /// 獲取快取的聊天室列表
  static Future<List<Map<String, dynamic>>?> _getCachedChatRooms(
    String scope, {
    bool ignoreExpiry = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_chatRoomsCacheKey}_$scope';
      final cached = prefs.getString(cacheKey);
      
      if (cached == null) return null;
      
      final data = json.decode(cached) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int?;
      
      // 檢查過期時間
      if (!ignoreExpiry && timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        final ageMinutes = age / (1000 * 60);
        
        if (ageMinutes > _cacheExpiryMinutes) {
          debugPrint('🔄 $_tag 聊天室快取已過期: ${ageMinutes.toStringAsFixed(1)} 分鐘');
          return null;
        }
      }
      
      final rooms = (data['data'] as List?)
          ?.map((r) => Map<String, dynamic>.from(r))
          .toList();
      
      return rooms;
    } catch (e) {
      debugPrint('❌ $_tag 讀取聊天室快取失敗: $e');
      return null;
    }
  }
  
  /// 快取聊天室列表
  static Future<void> _cacheChatRooms(String scope, List<Map<String, dynamic>> rooms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_chatRoomsCacheKey}_$scope';
      
      final cacheData = {
        'data': rooms,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(cacheKey, json.encode(cacheData));
    } catch (e) {
      debugPrint('❌ $_tag 快取聊天室列表失敗: $e');
    }
  }
  
  /// 增量更新未讀快取
  static Future<void> _incrementalUpdateUnreadCache(String roomId, int newCount) async {
    try {
      final scopes = ['all', 'posted', 'myworks'];
      
      for (final scope in scopes) {
        final cached = await _getCachedUnreadData(scope, ignoreExpiry: true);
        if (cached != null) {
          final byRoom = Map<String, dynamic>.from(cached['by_room'] ?? {});
          
          if (newCount == 0) {
            byRoom.remove(roomId);
          } else {
            byRoom[roomId] = newCount;
          }
          
          // 重新計算總數
          final total = byRoom.values.fold<int>(0, (sum, count) => sum + (count as int));
          
          final updatedData = Map<String, dynamic>.from(cached);
          updatedData['by_room'] = byRoom;
          updatedData['total'] = total;
          
          await _cacheUnreadData(scope, updatedData);
        }
      }
      
      debugPrint('✅ $_tag 增量更新未讀快取完成: roomId=$roomId, count=$newCount');
    } catch (e) {
      debugPrint('❌ $_tag 增量更新未讀快取失敗: $e');
    }
  }
  
  /// 獲取快取統計信息
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncTimeKey);
      
      final stats = <String, dynamic>{
        'last_sync': lastSync,
        'cache_keys': <String, bool>{},
      };
      
      final scopes = ['all', 'posted', 'myworks'];
      for (final scope in scopes) {
        final unreadKey = '${_unreadCacheKey}_$scope';
        final roomsKey = '${_chatRoomsCacheKey}_$scope';
        
        stats['cache_keys'][unreadKey] = prefs.containsKey(unreadKey);
        stats['cache_keys'][roomsKey] = prefs.containsKey(roomsKey);
      }
      
      return stats;
    } catch (e) {
      debugPrint('❌ $_tag 獲取快取統計失敗: $e');
      return {};
    }
  }
}
