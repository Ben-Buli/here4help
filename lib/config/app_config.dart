import 'environment_config.dart';

class AppConfig {
  // API 基礎 URL - 從環境配置獲取
  static String get apiBaseUrl => EnvironmentConfig.apiBaseUrl;

  // Socket 伺服器 URL - 從環境配置獲取
  static String get socketUrl => EnvironmentConfig.socketUrl;

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
    return '$apiBaseUrl/backend/api/account/profile.php';
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
  static String get myWorkApplicationsUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/my_work_applications.php';
  }

  static String get taskApplicantsUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/task_applicants.php';
  }

  static String get postedTaskApplicationsUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/posted_task_applications.php';
  }

  static String get applicationApplyUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/apply.php';
  }

  static String get applicationApproveUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/approve.php';
  }

  static String get applicationRejectUrl {
    return '$apiBaseUrl/backend/api/tasks/applications/reject.php';
  }

  // 任務完成相關 API
  static String get taskConfirmCompletionUrl {
    return '$apiBaseUrl/backend/api/tasks/confirm_completion.php';
  }

  static String get taskDisagreeCompletionUrl {
    return '$apiBaseUrl/backend/api/tasks/disagree_completion.php';
  }

  static String get taskPayAndReviewUrl {
    return '$apiBaseUrl/backend/api/tasks/pay_and_review.php';
  }

  // 任務評價相關 API
  static String get taskReviewsSubmitUrl {
    return '$apiBaseUrl/backend/api/tasks/reviews/submit.php';
  }

  static String get taskReviewsGetUrl {
    return '$apiBaseUrl/backend/api/tasks/reviews/get.php';
  }

  // 聊天相關 API
  static String get chatUploadAttachmentUrl {
    return '$apiBaseUrl/backend/api/chat/upload_attachment.php';
  }

  static String get chatReportUrl {
    return '$apiBaseUrl/backend/api/chat/report.php';
  }

  static String get chatBlockUserUrl {
    return '$apiBaseUrl/backend/api/chat/block_user.php';
  }

  // 大學列表 API
  static String get universitiesListUrl {
    return '$apiBaseUrl/backend/api/universities/list.php';
  }

  // 推薦碼驗證 API
  static String get verifyReferralCodeUrl {
    return '$apiBaseUrl/backend/api/auth/verify-referral-code.php';
  }

  // 學生證上傳 API
  static String get uploadStudentIdUrl {
    return '$apiBaseUrl/backend/api/auth/upload-student-id.php';
  }

  // Chat APIs (MVP)
  static String get unreadByTasksUrl =>
      '$apiBaseUrl/backend/api/chat/unread_by_tasks.php';
  static String get chatSendMessageUrl =>
      '$apiBaseUrl/backend/api/chat/send_message.php';
  static String get chatReadRoomV2Url =>
      '$apiBaseUrl/backend/api/chat/read_room_v2.php';
  static String get ensureRoomUrl =>
      '$apiBaseUrl/backend/api/chat/ensure_room.php';
}
