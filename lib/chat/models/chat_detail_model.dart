class ChatDetailModel {
  final int id;
  final int applierId;
  final int posterId;
  final int taskId;
  final String? message; // 正式版會使用 串連多筆聊天記錄
  final String applierReplyResmue; // 應徵者的回覆簡介
  final String? applierAvatarUrl;
  final String status; // 例如 "pending", "accepted", "rejected"

  ChatDetailModel({
    required this.id,
    required this.applierId,
    required this.posterId,
    required this.taskId,
    required this.applierReplyResmue,
    this.message,
    this.applierAvatarUrl,
    required this.status,
  });
}
