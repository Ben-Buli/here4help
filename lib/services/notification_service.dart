import 'dart:async';

/// 未讀訊息通知服務介面
abstract class NotificationService {
  // Streams
  Stream<int> observeTotalUnread();
  Stream<Map<String, int>> observeUnreadByTask();
  Stream<Map<String, int>> observeUnreadByRoom();

  // Commands
  Future<void> markRoomRead(
      {required String roomId, required String upToMessageId});
  Future<void> markTaskRead(
      {required String taskId, required String upToMessageId});
  Future<void> refreshSnapshot();

  // Lifecycle
  Future<void> init({required String userId});
  Future<void> dispose();

  // Persistence (本地)
  Future<void> loadCache();
  Future<void> saveCache();
}

/// 佔位實作：所有未讀皆為 0，用於 UI 先行接線
class NotificationServicePlaceholder implements NotificationService {
  static final NotificationServicePlaceholder _instance =
      NotificationServicePlaceholder._internal();
  factory NotificationServicePlaceholder() => _instance;
  NotificationServicePlaceholder._internal();

  final StreamController<int> _totalUnreadController =
      StreamController<int>.broadcast();
  final StreamController<Map<String, int>> _byTaskController =
      StreamController<Map<String, int>>.broadcast();
  final StreamController<Map<String, int>> _byRoomController =
      StreamController<Map<String, int>>.broadcast();

  Map<String, int> _unreadByTask = const {};
  Map<String, int> _unreadByRoom = const {};
  int _totalUnread = 0;

  @override
  Stream<int> observeTotalUnread() => _totalUnreadController.stream;

  @override
  Stream<Map<String, int>> observeUnreadByTask() => _byTaskController.stream;

  @override
  Stream<Map<String, int>> observeUnreadByRoom() => _byRoomController.stream;

  void _emitAll() {
    _totalUnreadController.add(_totalUnread);
    _byTaskController.add(_unreadByTask);
    _byRoomController.add(_unreadByRoom);
  }

  @override
  Future<void> init({required String userId}) async {
    // 佔位：全部 0
    _unreadByTask = const {};
    _unreadByRoom = const {};
    _totalUnread = 0;
    _emitAll();
  }

  @override
  Future<void> dispose() async {
    await _totalUnreadController.close();
    await _byTaskController.close();
    await _byRoomController.close();
  }

  @override
  Future<void> loadCache() async {
    // 佔位：不做事
  }

  @override
  Future<void> saveCache() async {
    // 佔位：不做事
  }

  @override
  Future<void> markRoomRead(
      {required String roomId, required String upToMessageId}) async {
    // 佔位：不做事，但仍觸發一次廣播以確保 UI 有更新機會
    _emitAll();
  }

  @override
  Future<void> markTaskRead(
      {required String taskId, required String upToMessageId}) async {
    // 佔位：不做事
    _emitAll();
  }

  @override
  Future<void> refreshSnapshot() async {
    // 佔位：全部 0
    _emitAll();
  }
}
