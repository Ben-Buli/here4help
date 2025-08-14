class AppConfig {
  // 環境設定
  static const bool isDevelopment = true; // 開發時設為 true，正式環境設為 false

  // API 基礎 URL
  static const String devApiBaseUrl = 'http://localhost:8888/here4help';
  static const String prodApiBaseUrl = 'https://hero4help.demofhs.com';

  // 獲取當前環境的 API 基礎 URL
  static String get apiBaseUrl {
    return isDevelopment ? devApiBaseUrl : prodApiBaseUrl;
  }

  // Google 登入 API 端點
  static String get googleLoginUrl {
    return '$apiBaseUrl/backend/api/auth/google-login.php';
  }

  // 一般登入 API 端點
  static String get loginUrl {
    return '$apiBaseUrl/backend/api/auth/login.php';
  }

  static String get registerUrl {
    return '$apiBaseUrl/backend/api/auth/register.php';
  }

  static String get profileUrl {
    return '$apiBaseUrl/backend/api/auth/profile.php';
  }

  // 任務相關 API
  static String get taskListUrl {
    return '$apiBaseUrl/backend/api/tasks/list.php';
  }

  static String get taskCreateUrl {
    return '$apiBaseUrl/backend/api/tasks/create.php';
  }

  static String get taskUpdateUrl {
    return '$apiBaseUrl/backend/api/tasks/update.php';
  }

  static String get taskStatusesUrl {
    return '$apiBaseUrl/backend/api/tasks/statuses.php';
  }

  // 推薦碼相關 API
  static String get referralCodeUrl {
    return '$apiBaseUrl/backend/api/referral/get-referral-code.php';
  }

  static String get useReferralCodeUrl {
    return '$apiBaseUrl/backend/api/referral/use-referral-code.php';
  }

  static String get referralCodeListUrl {
    return '$apiBaseUrl/backend/api/referral/list-referral-codes.php';
  }

  // Applications
  static String get applicationsListByUserUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/list_by_user.php';
  }

  static String get applicationsListByTaskUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/list_by_task.php';
  }

  static String get applicationApplyUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/apply.php';
  }

  static String get applicationApplyWithChatUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/apply_with_chat.php';
  }

  static String get applicationApproveUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/approve.php';
  }

  static String get applicationRejectUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/reject.php';
  }

  // Socket Gateway
  static String get devSocketUrl => 'http://localhost:3001';
  static String get prodSocketUrl => 'https://hero4help.demofhs.com:3001';
  static String get socketUrl => isDevelopment ? devSocketUrl : prodSocketUrl;

  // Chat APIs (MVP)
  static String get unreadSnapshotUrl =>
      '$apiBaseUrl/backend/api/chat/unread_snapshot.php';
  static String get chatSendMessageUrl =>
      '$apiBaseUrl/backend/api/chat/send_message.php';
  static String get chatReadRoomUrl =>
      '$apiBaseUrl/backend/api/chat/read_room.php';
  static String get ensureRoomUrl =>
      '$apiBaseUrl/backend/api/chat/ensure_room.php';
  static String get chatUploadAttachmentUrl =>
      '$apiBaseUrl/backend/api/chat/upload_attachment.php';

  // Chat - Reports & Blocks
  static String get chatReportUrl => '$apiBaseUrl/backend/api/chat/report.php';
  static String get chatBlockUserUrl =>
      '$apiBaseUrl/backend/api/chat/block_user.php';

  // Chat - Aggregated APIs (Performance Optimized)
  static String get postedTasksWithApplicantsUrl =>
      '$apiBaseUrl/backend/api/chat/get_posted_tasks_with_applicants.php';

  // Task Favorites APIs
  static String get taskFavoritesToggleUrl =>
      '$apiBaseUrl/backend/api/tasks/favorites/toggle.php';
  static String get taskFavoritesListUrl =>
      '$apiBaseUrl/backend/api/tasks/favorites/list.php';

  // Tasks - Completion & Reviews & Payment
  static String get taskConfirmCompletionUrl =>
      '$apiBaseUrl/backend/api/tasks/confirm_completion.php';
  static String get taskDisagreeCompletionUrl =>
      '$apiBaseUrl/backend/api/tasks/disagree_completion.php';
  static String get taskPayAndReviewUrl =>
      '$apiBaseUrl/backend/api/tasks/pay_and_review.php';
  static String get taskReviewsSubmitUrl =>
      '$apiBaseUrl/backend/api/tasks/reviews_submit.php';
  static String get taskReviewsGetUrl =>
      '$apiBaseUrl/backend/api/tasks/reviews_get.php';
}
