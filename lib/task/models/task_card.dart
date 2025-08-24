class TaskCard {
  final String taskId;
  final String title;
  final DateTime taskDate;
  final String rewardPoint;
  final int statusId;
  final String statusName;
  final TaskRating? rating;
  final int? applicationId;
  final String? applicationStatus;
  final int? participantId;
  final int? creatorId;
  final bool canRate;

  TaskCard({
    required this.taskId,
    required this.title,
    required this.taskDate,
    required this.rewardPoint,
    required this.statusId,
    required this.statusName,
    this.rating,
    this.applicationId,
    this.applicationStatus,
    this.participantId,
    this.creatorId,
    required this.canRate,
  });

  factory TaskCard.fromJson(Map<String, dynamic> json) {
    TaskRating? taskRating;
    try {
      if (json['creator_rating'] != null) {
        taskRating = TaskRating.fromJson(json['creator_rating']);
      } else if (json['participant_rating'] != null) {
        taskRating = TaskRating.fromJson(json['participant_rating']);
      }
    } catch (e) {
      // Silently handle parsing errors
    }

    return TaskCard(
      taskId: json['task_id'],
      title: json['title'],
      taskDate: DateTime.parse(json['task_date']),
      rewardPoint: json['reward_point'],
      statusId: json['status_id'],
      statusName: json['status_name'],
      rating: taskRating,
      applicationId: json['application_id'],
      applicationStatus: json['application_status'],
      participantId: json['participant_id'],
      creatorId: json['creator_id'],
      canRate: json['can_rate'] ?? false,
    );
  }

  bool get isCompleted => statusId == 5;
  bool get isUnfinished => [1, 2, 3, 4, 6].contains(statusId);
  bool get hasRating => rating != null;
}

class TaskRating {
  final int rating;
  final String comment;
  final RaterInfo rater;
  final String createdAt;

  TaskRating({
    required this.rating,
    required this.comment,
    required this.rater,
    required this.createdAt,
  });

  factory TaskRating.fromJson(Map<String, dynamic> json) {
    return TaskRating(
      rating: json['rating'],
      comment: json['comment'] ?? '',
      rater: RaterInfo.fromJson(json['rater']),
      createdAt: json['created_at'] ?? '',
    );
  }
}

class RaterInfo {
  final int id;
  final String name;
  final String? avatarUrl;
  final bool isYou;

  RaterInfo({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.isYou,
  });

  factory RaterInfo.fromJson(Map<String, dynamic> json) {
    return RaterInfo(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      isYou: json['is_you'] ?? false,
    );
  }
}

class Paged<T> {
  final List<T> items;
  final PaginationInfo pagination;

  Paged({
    required this.items,
    required this.pagination,
  });

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return Paged<T>(
      items: (json['items'] as List).map((item) => fromJsonT(item)).toList(),
      pagination: PaginationInfo.fromJson(json['pagination']),
    );
  }
}

class PaginationInfo {
  final int currentPage;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  PaginationInfo({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'],
      perPage: json['per_page'],
      total: json['total'],
      totalPages: json['total_pages'],
      hasNextPage: json['has_next_page'],
      hasPrevPage: json['has_prev_page'],
    );
  }
}
