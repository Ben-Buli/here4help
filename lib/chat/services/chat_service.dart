import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/services/media/cross_platform_image_service.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:here4help/services/http_client_service.dart';

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

      final uri = Uri.parse(AppConfig.api('/chat/get_rooms.php'))
          .replace(queryParameters: queryParams);

      final response = await HttpClientService.get(uri.toString());

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

      final uri = Uri.parse(AppConfig.api('/chat/get_messages.php'))
          .replace(queryParameters: queryParams);

      final response = await HttpClientService.get(uri.toString());

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
    String kind = 'text', // 新增 kind 參數
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final response = await HttpClientService.post(
        AppConfig.api('/chat/send_message.php'),
        body: {
          'room_id': roomId,
          'message': message,
          'kind': kind,
          if (taskId != null) 'task_id': taskId,
        },
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

  /// 上傳聊天附件（跨平台）
  Future<Map<String, dynamic>> uploadAttachment({
    required String roomId,
    required ImageResult image,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      // 使用跨平台圖片服務上傳
      final imageService = CrossPlatformImageService();
      return await imageService.uploadImage(
        image: image,
        uploadUrl: AppConfig.chatUploadAttachmentUrl,
        token: token,
        fieldName: 'file',
        additionalFields: {
          'room_id': roomId,
        },
      );
    } catch (e) {
      throw Exception('上傳失敗: $e');
    }
  }

  /// 從相機選擇並上傳聊天圖片
  Future<Map<String, dynamic>> pickAndUploadFromCamera(String roomId) async {
    final imageService = CrossPlatformImageService();
    final image = await imageService.pickFromCamera(
      config: ImageValidationConfig.chat,
    );

    if (image == null) {
      throw Exception('未選擇圖片');
    }

    return await uploadAttachment(roomId: roomId, image: image);
  }

  /// 從相簿選擇並上傳聊天圖片
  Future<Map<String, dynamic>> pickAndUploadFromGallery(String roomId) async {
    final imageService = CrossPlatformImageService();
    final image = await imageService.pickFromGallery(
      config: ImageValidationConfig.chat,
    );

    if (image == null) {
      throw Exception('未選擇圖片');
    }

    return await uploadAttachment(roomId: roomId, image: image);
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

      final response = await HttpClientService.post(
        AppConfig.api('/chat/ensure_room.php'),
        body: {
          'task_id': taskId,
          'creator_id': creatorId,
          'participant_id': participantId,
          'type': type,
        },
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

      final response = await HttpClientService.post(
        AppConfig.api('/chat/read_room_v2.php'),
        body: {
          'room_id': roomId,
        },
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

  /// 獲取未讀訊息快照 (使用新的角色邏輯 API)
  Future<Map<String, dynamic>> getUnreadSnapshot() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final response = await HttpClientService.get(
        AppConfig.api('/chat/unread_by_tasks.php?scope=all'),
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

  /// 檢查用戶是否已經檢舉過聊天室
  Future<Map<String, dynamic>> checkReportStatus({
    required String roomId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final queryParams = <String, String>{
        'room_id': roomId,
      };

      final uri = Uri.parse('$_baseUrl/backend/api/chat/check_report.php')
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
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
        throw Exception(data['message'] ?? '檢查檢舉狀態失敗');
      } else {
        throw Exception('HTTP ${response.statusCode}: 檢查檢舉狀態失敗');
      }
    } catch (e) {
      throw Exception('檢查檢舉狀態失敗: $e');
    }
  }

  /// 檢舉聊天（含證據上傳占位，實際檔案上傳改為後續 API）
  Future<Map<String, dynamic>> reportChat({
    required String roomId,
    required String reason,
    String? description,
    List<String>? evidenceTempNames,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final uri = Uri.parse(AppConfig.chatReportUrl);
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'room_id': roomId,
          'reason': reason,
          if (description != null) 'description': description,
          if (evidenceTempNames != null) 'evidence': evidenceTempNames,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
        throw Exception(data['message'] ?? '檢舉失敗');
      } else {
        throw Exception('HTTP ${response.statusCode}: 檢舉失敗');
      }
    } catch (e) {
      throw Exception('檢舉失敗: $e');
    }
  }

  /// 封鎖/解除封鎖使用者
  Future<Map<String, dynamic>> blockUser({
    required int targetUserId,
    required bool block,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final uri = Uri.parse(AppConfig.chatBlockUserUrl);
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'target_user_id': targetUserId,
          'block': block ? 1 : 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
        throw Exception(data['message'] ?? '封鎖操作失敗');
      } else {
        throw Exception('HTTP ${response.statusCode}: 封鎖操作失敗');
      }
    } catch (e) {
      throw Exception('封鎖操作失敗: $e');
    }
  }

  /// 獲取聊天室詳細數據（聚合 API）
  Future<Map<String, dynamic>> getChatDetailData({
    required String roomId,
  }) async {
    try {
      debugPrint('🔍 [ChatService] 開始獲取聊天室詳細數據');
      debugPrint('  - roomId: $roomId');

      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('❌ [ChatService] 沒有找到 token，用戶未登入');
        throw Exception('未登入');
      }

      debugPrint('✅ [ChatService] 找到 token: ${token.substring(0, 10)}...');

      final queryParams = <String, String>{
        'room_id': roomId,
      };

      final uri = Uri.parse(AppConfig.api('/chat/get_chat_detail_data.php'))
          .replace(queryParameters: queryParams);

      // debugPrint('🌐 [ChatService] 請求 URL: $uri');

      // final headers = {
      //   'Authorization': 'Bearer $token',
      //   'Content-Type': 'application/json',
      // };

      // debugPrint('📤 [ChatService] 請求標頭: $headers');

      final response = await HttpClientService.get(uri.toString());

      debugPrint('📥 [ChatService] 回應狀態碼: ${response.statusCode}');
      // debugPrint('📥 [ChatService] 回應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ [ChatService] 成功獲取聊天室數據');
          return data['data'];
        } else {
          debugPrint('❌ [ChatService] API 返回錯誤: ${data['message']}');
          throw Exception(data['message'] ?? '獲取聊天室詳細數據失敗');
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ [ChatService] 授權失敗，可能需要重新登入');
        throw Exception('授權失敗，請重新登入');
      } else if (response.statusCode == 403) {
        debugPrint('❌ [ChatService] 沒有權限訪問此聊天室');
        throw Exception('您沒有權限訪問此聊天室');
      } else if (response.statusCode == 404) {
        debugPrint('❌ [ChatService] 聊天室不存在');
        throw Exception('聊天室不存在');
      } else {
        debugPrint('❌ [ChatService] 網路錯誤: ${response.statusCode}');
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 [ChatService] 獲取聊天室詳細數據失敗: $e');
      throw Exception('獲取聊天室詳細數據失敗: $e');
    }
  }

  /// 檢查聊天室對應的應徵狀態
  Future<String?> getApplicationStatus({
    required String roomId,
    required String taskId,
    required int participantId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final queryParams = <String, String>{
        'room_id': roomId,
        'task_id': taskId,
        'participant_id': participantId.toString(),
      };

      final uri = Uri.parse(
              AppConfig.api('/tasks/applications/get_application_status.php'))
          .replace(queryParameters: queryParams);

      final response = await HttpClientService.get(uri.toString());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']?['status'] as String?;
        } else {
          // 如果沒有找到應徵記錄，返回 null
          if (data['message']?.contains('not found') == true) {
            return null;
          }
          throw Exception(data['message'] ?? '獲取應徵狀態失敗');
        }
      } else if (response.statusCode == 404) {
        // 沒有找到應徵記錄
        return null;
      } else {
        throw Exception('網路錯誤: ${response.statusCode}');
      }
    } catch (e) {
      // 如果發生錯誤，返回 null 讓 Accept 按鈕正常顯示
      debugPrint('獲取應徵狀態失敗: $e');
      return null;
    }
  }

  /// 撤銷應徵申請
  Future<Map<String, dynamic>> withdrawApplication({
    required String taskId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final uri = Uri.parse(AppConfig.api('/tasks/applications/withdraw.php'));
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'task_id': taskId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
        throw Exception(data['message'] ?? '撤銷應徵申請失敗');
      } else {
        throw Exception('HTTP ${response.statusCode}: 撤銷應徵申請失敗');
      }
    } catch (e) {
      throw Exception('撤銷應徵申請失敗: $e');
    }
  }
}
