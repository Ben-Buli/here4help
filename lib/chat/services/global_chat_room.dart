import 'package:here4help/chat/models/chat_room_model.dart';
import 'package:here4help/task/services/global_task_list.dart';

class GlobalChatRoom {
  static final GlobalChatRoom _instance = GlobalChatRoom._internal();

  factory GlobalChatRoom() => _instance;

  GlobalChatRoom._internal();

  final List<Map<String, dynamic>> _chatRooms = [];

  Future<void> loadChatRooms() async {
    // 加載聊天房間資料（可從本地存儲或遠端獲取）
    if (_chatRooms.isEmpty) {
      _chatRooms.addAll(chatRoomModel);
    }
  }

  /// 根據 taskId 獲取對應的聊天房間
  List<Map<String, dynamic>> getRoomsByTaskId(String taskId) {
    return _chatRooms.where((room) => room['taskId'] == taskId).toList();
  }

  /// 根據 taskId 獲取對應的任務和聊天房間的 join 效果
  Map<String, dynamic>? getTaskWithRooms(String taskId) {
    final globalTaskList = GlobalTaskList();
    final task = globalTaskList.tasks.firstWhere(
      (task) => task['id'] == taskId,
      orElse: () => <String, dynamic>{},
    );

    if (task == null) return null;

    final rooms = getRoomsByTaskId(taskId);

    return {
      'task': task,
      'rooms': rooms,
    };
  }

  /// 添加新的聊天房間
  void addChatRoom(Map<String, dynamic> chatRoom) {
    _chatRooms.add(chatRoom);
  }

  /// 更新聊天房間資料
  void updateChatRoom(String roomId, Map<String, dynamic> updatedData) {
    final index = _chatRooms.indexWhere((room) => room['id'] == roomId);
    if (index != -1) {
      _chatRooms[index] = updatedData;
    }
  }

  // 移除其他聊天室，保留指定的 roomId
  void removeRoomsByTaskIdExcept(String taskId, String roomId) {
    _chatRooms.removeWhere((room) =>
        room['taskId'] == taskId && room['roomId'] != roomId);
  }

  List<Map<String, dynamic>> get chatRooms => _chatRooms;
}
