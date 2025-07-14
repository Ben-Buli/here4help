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
}

class TaskModel {
  final String id;
  final String? creatorName;
  final String? acceptorId;
  final String title;
  final String description;
  final String salary;
  final String location;
  final String taskDate;
  final String status;
  final String creatorConfirmed;
  final String acceptorConfirmed;
  final String? cancelReason;
  final String? failReason;
  final String languageRequirement;
  final List<ApplicationQuestionModel>? applicationQuestions;
  final List<String>? hashtags;
  final String createdAt;
  final String updatedAt;

  TaskModel({
    required this.id,
    this.creatorName,
    this.acceptorId,
    required this.title,
    required this.description,
    required this.salary,
    required this.location,
    required this.taskDate,
    required this.status,
    required this.creatorConfirmed,
    required this.acceptorConfirmed,
    this.cancelReason,
    this.failReason,
    required this.languageRequirement,
    this.applicationQuestions,
    this.hashtags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'],
      creatorName: map['creator_name'],
      acceptorId: map['acceptor_id'],
      title: map['title'],
      description: map['description'],
      salary: map['salary'],
      location: map['location'],
      taskDate: map['task_date'],
      status: map['status'],
      creatorConfirmed: map['creator_confirmed'],
      acceptorConfirmed: map['acceptor_confirmed'],
      cancelReason: map['cancel_reason'],
      failReason: map['fail_reason'],
      languageRequirement: map['language_requirement'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      hashtags:
          map['hashtags'] != null ? List<String>.from(map['hashtags']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creator_name': creatorName,
      'acceptor_id': acceptorId,
      'title': title,
      'description': description,
      'salary': salary,
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
