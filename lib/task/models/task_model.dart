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
  final String? applicationQuestion;
  final String languageRequirement;
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
    this.applicationQuestion,
    required this.languageRequirement,
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
      applicationQuestion: map['application_question'],
      languageRequirement: map['language_requirement'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
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
      'application_question': applicationQuestion,
      'hashtags': hashtags,
      'language_requirement': languageRequirement,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
