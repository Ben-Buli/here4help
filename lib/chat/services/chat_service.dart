import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final String _baseUrl = AppConfig.apiBaseUrl;

  /// 獲取用戶的聊天房間列表
  Future<Map<String, dynamic>> getChatRooms({
    String? taskId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (taskId != null) {
        queryParams['task_id'] = taskId;
      }

      final uri = Uri.parse('$_baseUrl/backend/api/chat/get_rooms.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '獲取聊天房間失敗');
        }
      } else {
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('獲取聊天房間失敗: $e');
    }
  }

  /// 獲取聊天房間的訊息
  Future<Map<String, dynamic>> getMessages({
    required String roomId,
    int limit = 50,
    int? beforeId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final queryParams = <String, String>{
        'room_id': roomId,
        'limit': limit.toString(),
      };

      if (beforeId != null) {
        queryParams['before_id'] = beforeId.toString();
      }

      final uri = Uri.parse('$_baseUrl/backend/api/chat/get_messages.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '獲取訊息失敗');
        }
      } else {
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('獲取訊息失敗: $e');
    }
  }

  /// 發送訊息
  Future<Map<String, dynamic>> sendMessage({
    required String roomId,
    required String message,
    String? taskId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/backend/api/chat/send_message.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'room_id': roomId,
          'message': message,
          if (taskId != null) 'task_id': taskId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '發送訊息失敗');
        }
      } else {
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('發送訊息失敗: $e');
    }
  }

  /// 確保聊天房間存在
  Future<Map<String, dynamic>> ensureRoom({
    required String taskId,
    required int creatorId,
    required int participantId,
    String type = 'application',
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/backend/api/chat/ensure_room.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'task_id': taskId,
          'creator_id': creatorId,
          'participant_id': participantId,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '創建聊天房間失敗');
        }
      } else {
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('創建聊天房間失敗: $e');
    }
  }

  /// 標記房間為已讀
  Future<Map<String, dynamic>> markRoomAsRead({
    required String roomId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/backend/api/chat/read_room.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'room_id': roomId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '標記已讀失敗');
        }
      } else {
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('標記已讀失敗: $e');
    }
  }

  /// 獲取未讀訊息快照
  Future<Map<String, dynamic>> getUnreadSnapshot() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/backend/api/chat/unread_snapshot.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '獲取未讀訊息失敗');
        }
      } else {
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('獲取未讀訊息失敗: $e');
    }
  }

  /// 格式化訊息時間
  String formatMessageTime(String timeString) {
    try {
      final dateTime = DateTime.parse(timeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}天前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}小時前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}分鐘前';
      } else {
        return '剛剛';
      }
    } catch (e) {
      return timeString;
    }
  }

  /// 檢查用戶是否有權限訪問聊天房間
  bool canAccessRoom(Map<String, dynamic> room, int userId) {
    final creatorId = room['creator_id'] as int?;
    final participantId = room['participant_id'] as int?;

    return creatorId == userId || participantId == userId;
  }

  /// 獲取聊天房間的對方用戶資訊
  Map<String, dynamic>? getOtherUser(
      Map<String, dynamic> room, int currentUserId) {
    if (room['creator_id'] == currentUserId) {
      return {
        'id': room['participant_id'],
        'name': room['participant_name'],
        'avatar': room['participant_avatar'],
      };
    } else if (room['participant_id'] == currentUserId) {
      return {
        'id': room['creator_id'],
        'name': room['creator_name'],
        'avatar': room['creator_avatar'],
      };
    }
    return null;
  }
}
