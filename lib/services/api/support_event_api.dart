import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

/// 客服事件 API 服務
class SupportEventApi {
  /// 建立客服事件（整合 API）
  static Future<Map<String, dynamic>> createIssue({
    required String title,
    required String description,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('SupportEventApi: create issue: title=$title');
      }

      final response = await HttpClientService.post(
        AppConfig.supportCreateIssueUrl,
        body: {
          'title': title,
          'description': description,
        },
      );

      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: create issue response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'SupportEventApi: create issue success: ${data['data']}');
          }
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Create issue failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Create issue failed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: create issue error: $e');
      }
      rethrow;
    }
  }

  /// 獲取用戶的所有客服事件
  static Future<List<Map<String, dynamic>>> getUserEvents() async {
    try {
      if (kDebugMode) {
        debugPrint('SupportEventApi: get user events');
      }

      final response = await HttpClientService.get(
        AppConfig.supportUserEventsUrl,
      );

      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: get user events response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'SupportEventApi: get user events success: ${data['data']['events'].length} 筆');
          }
          return List<Map<String, dynamic>>.from(data['data']['events']);
        } else {
          throw Exception(data['message'] ?? 'Get user events failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Get user events failed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: get user events error: $e');
      }
      rethrow;
    }
  }

  /// 獲取聊天室內事件列表
  static Future<List<Map<String, dynamic>>> getEvents({
    required String chatRoomId,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('SupportEventApi: get events: chatRoomId=$chatRoomId');
      }

      final response = await HttpClientService.get(
        '${AppConfig.supportEventsUrl}?chat_room_id=$chatRoomId',
      );

      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: get events response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'SupportEventApi: get events success: ${data['data']['events'].length} 筆');
          }
          return List<Map<String, dynamic>>.from(data['data']['events']);
        } else {
          throw Exception(data['message'] ?? 'Get events failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Get events failed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: get events error: $e');
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
            'SupportEventApi: create event: chatRoomId=$chatRoomId, title=$title');
      }

      final response = await HttpClientService.post(
        AppConfig.supportEventsUrl,
        body: {
          'chat_room_id': chatRoomId,
          'title': title,
          'description': description,
        },
      );

      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: create event response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'SupportEventApi: create event success: ${data['data']}');
          }
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Create event failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Create event failed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: create event error: $e');
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
        debugPrint(
            'SupportEventApi: update event status: eventId=$eventId, status=$status');
      }

      final response = await HttpClientService.patch(
        AppConfig.supportEventsUrl,
        body: {
          'event_id': eventId,
          'status': status,
        },
      );

      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: update event status response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'SupportEventApi: update event status success: ${data['data']}');
          }
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Update event status failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Update event status failed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: update event status error: $e');
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
        debugPrint(
            'SupportEventApi: close event: eventId=$eventId, rating=$rating');
      }

      final response = await HttpClientService.post(
        AppConfig.supportCloseEventUrl,
        body: {
          'event_id': eventId,
          if (rating != null) 'rating': rating,
          if (review != null) 'review': review,
        },
      );

      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: close event response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('SupportEventApi: close event success: ${data['data']}');
          }
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Close event failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Close event failed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: close event error: $e');
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
        debugPrint(
            'SupportEventApi: submit rating: eventId=$eventId, rating=$rating');
      }

      final response = await HttpClientService.post(
        AppConfig.supportRatingUrl,
        body: {
          'event_id': eventId,
          'rating': rating,
          if (review != null) 'review': review,
        },
      );

      if (kDebugMode) {
        debugPrint(
            'SupportEventApi: submit rating response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'SupportEventApi: submit rating success: ${data['data']}');
          }
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Submit rating failed');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Submit rating failed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportEventApi: submit rating error: $e');
      }
      rethrow;
    }
  }
}
