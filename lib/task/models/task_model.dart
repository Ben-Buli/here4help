// 新增獨立的 ApplicationQuestion model
class ApplicationQuestionModel {
  final String id;
  final String taskId;
  final String applicationQuestion;
  final String? applierReply;

  ApplicationQuestionModel({
    required this.id,
    required this.taskId,
    required this.applicationQuestion,
    this.applierReply,
  });

  factory ApplicationQuestionModel.fromMap(Map<String, dynamic> map) {
    return ApplicationQuestionModel(
      id: map['id'],
      taskId: map['task_id'],
      applicationQuestion: map['application_question'],
      applierReply: map['applier_reply'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'application_question': applicationQuestion,
      'applier_reply': applierReply,
    };
  }

  ApplicationQuestionModel copyWith({
    String? id,
    String? taskId,
    String? applicationQuestion,
    String? applierReply,
  }) {
    return ApplicationQuestionModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      applicationQuestion: applicationQuestion ?? this.applicationQuestion,
      applierReply: applierReply ?? this.applierReply,
    );
  }
}

class TaskModel {
  final String id;
  final String? creatorName;
  final String? participantId;
  final String title;
  final String description;
  final String rewardPoint;
  final String location;
  final String taskDate;
  final String status;
  final String? creatorConfirmed;
  final String? acceptorConfirmed;
  final String? cancelReason;
  final String? failReason;
  final String? languageRequirement;
  final String? hashtags;
  final String createdAt;
  final String updatedAt;

  TaskModel({
    required this.id,
    this.creatorName,
    this.participantId,
    required this.title,
    required this.description,
    required this.rewardPoint,
    required this.location,
    required this.taskDate,
    required this.status,
    this.creatorConfirmed,
    this.acceptorConfirmed,
    this.cancelReason,
    this.failReason,
    this.languageRequirement,
    this.hashtags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      creatorName: map['creator_name'],
      participantId: map['participant_id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      rewardPoint:
          map['reward_point'] ?? map['salary'] ?? '0', // 支援舊的 salary 欄位
      location: map['location'] ?? '',
      taskDate: map['task_date'] ?? '',
      status: map['status'] ?? '',
      creatorConfirmed: map['creator_confirmed'],
      acceptorConfirmed: map['acceptor_confirmed'],
      cancelReason: map['cancel_reason'],
      failReason: map['fail_reason'],
      languageRequirement: map['language_requirement'],
      hashtags: map['hashtags'],
      createdAt: map['created_at'] ?? '',
      updatedAt: map['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_name': creatorName,
      'participant_id': participantId,
      'title': title,
      'description': description,
      'reward_point': rewardPoint,
      'location': location,
      'task_date': taskDate,
      'status': status,
      'creator_confirmed': creatorConfirmed,
      'acceptor_confirmed': acceptorConfirmed,
      'cancel_reason': cancelReason,
      'fail_reason': failReason,
      'language_requirement': languageRequirement,
      'hashtags': hashtags,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
