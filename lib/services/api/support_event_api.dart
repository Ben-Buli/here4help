import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

/// 客服事件 API 服務
class SupportEventApi {
  static String get _baseUrl => '${AppConfig.apiBaseUrl}/support';

  /// 獲取聊天室內事件列表
  static Future<List<Map<String, dynamic>>> getEvents({
    required String chatRoomId,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 獲取事件列表: chatRoomId=$chatRoomId');
      }

      final response = await HttpClientService.get(
        '$_baseUrl/events.php?chat_room_id=$chatRoomId',
      );

      if (kDebugMode) {
        debugPrint('SupportEventApi: 事件列表回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'SupportEventApi: 事件列表獲取成功: ${data['data']['events'].length} 筆');
          }
          return List<Map<String, dynamic>>.from(data['data']['events']);
        } else {
          throw Exception(data['message'] ?? '獲取事件列表失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '獲取事件列表失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 獲取事件列表錯誤: $e');
      }
      rethrow;
    }
  }

  /// 新增事件（僅限管理員）
  static Future<Map<String, dynamic>> createEvent({
    required String chatRoomId,
    required String title,
    required String description,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: 新增事件: chatRoomId=$chatRoomId, title=$title');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/events.php',
        body: {
          'chat_room_id': chatRoomId,
          'title': title,
          'description': description,
        },
      );

      if (kDebugMode) {
        debugPrint('SupportEventApi: 新增事件回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('SupportEventApi: 事件新增成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '新增事件失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '新增事件失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 新增事件錯誤: $e');
      }
      rethrow;
    }
  }

  /// 更新事件狀態
  static Future<Map<String, dynamic>> updateEventStatus({
    required String eventId,
    required String status,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 更新事件狀態: eventId=$eventId, status=$status');
      }

      final response = await HttpClientService.patch(
        '$_baseUrl/events.php',
        body: {
          'event_id': eventId,
          'status': status,
        },
      );

      if (kDebugMode) {
        debugPrint('SupportEventApi: 更新事件狀態回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('SupportEventApi: 事件狀態更新成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '更新事件狀態失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '更新事件狀態失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 更新事件狀態錯誤: $e');
      }
      rethrow;
    }
  }

  /// 客戶結案事件
  static Future<Map<String, dynamic>> closeEvent({
    required String eventId,
    int? rating,
    String? review,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 結案事件: eventId=$eventId, rating=$rating');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/events_close.php',
        body: {
          'event_id': eventId,
          if (rating != null) 'rating': rating,
          if (review != null) 'review': review,
        },
      );

      if (kDebugMode) {
        debugPrint('SupportEventApi: 結案事件回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('SupportEventApi: 事件結案成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '結案事件失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '結案事件失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 結案事件錯誤: $e');
      }
      rethrow;
    }
  }

  /// 提交事件評分
  static Future<Map<String, dynamic>> submitRating({
    required String eventId,
    required int rating,
    String? review,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 提交評分: eventId=$eventId, rating=$rating');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/events_rating.php',
        body: {
          'event_id': eventId,
          'rating': rating,
          if (review != null) 'review': review,
        },
      );

      if (kDebugMode) {
        debugPrint('SupportEventApi: 提交評分回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('SupportEventApi: 評分提交成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '提交評分失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '提交評分失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: 提交評分錯誤: $e');
      }
      rethrow;
    }
  }
}
