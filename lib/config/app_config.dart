import 'environment_config_legacy.dart';

class AppConfig {
  // 新通用 API 組裝器：以環境的 apiOrigin + apiPrefix 組裝
  static String api(String path) {
    final origin = EnvironmentConfig.apiOrigin;
    final prefix = EnvironmentConfig.apiPrefix;
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    return '$origin$prefix$path';
  }

  // API 基礎 URL - 從環境配置獲取
  static String get apiBaseUrl => EnvironmentConfig.apiBaseUrl;

  // Socket 伺服器 URL - 從環境配置獲取
  static String get socketUrl => EnvironmentConfig.socketUrl;

  // Google 登入 API 端點
  static String get googleLoginUrl => api('/auth/google-login.php');

  // Apple 登入 API 端點
  static String get appleLoginUrl => api('/auth/apple-login.php');

  // Facebook 登入 API 端點
  static String get facebookLoginUrl => api('/auth/facebook-login.php');

  // 一般登入 API 端點
  static String get loginUrl => api('/auth/login.php');

  static String get registerUrl => api('/auth/register.php');
  static String get registerWithStudentIdUrl =>
      api('/auth/register-with-student-id.php');

  static String get registerOAuthWithStudentIdUrl =>
      api('/auth/register-oauth-with-student-id.php');

  static String get profileUrl => api('/account/profile.php');

  // 任務相關 API
  static String get taskListUrl => api('/tasks/list.php');

  static String get taskCreateUrl => api('/tasks/create.php');

  static String get taskUpdateUrl => api('/tasks/update.php');

  static String get taskStatusesUrl => api('/tasks/statuses.php');

  // 推薦碼相關 API
  static String get referralCodeUrl => api('/referral/get-referral-code.php');

  static String get useReferralCodeUrl =>
      api('/referral/use-referral-code.php');

  static String get referralCodeListUrl =>
      api('/referral/list-referral-codes.php');

  // Applications
  static String get myWorkApplicationsUrl =>
      api('/tasks/applications/my_work_applications.php');

  static String get taskApplicantsUrl =>
      api('/tasks/applications/task_applicants.php');

  static String get postedTaskApplicationsUrl =>
      api('/tasks/applications/posted_task_applications.php');

  static String get applicationApplyUrl => api('/tasks/applications/apply.php');

  static String get applicationApproveUrl =>
      api('/tasks/applications/approve.php');

  static String get applicationRejectUrl =>
      api('/tasks/applications/reject.php');

  static String get applicationApproveUrlV2 =>
      api('/tasks/applications/approve.php');

  // 任務完成相關 API
  static String get taskConfirmCompletionUrl =>
      api('/tasks/confirm_completion.php');

  static String get taskDisagreeCompletionUrl =>
      api('/tasks/disagree_completion.php');

  static String get taskPayAndReviewUrl => api('/tasks/pay_and_review.php');

  // 任務評價相關 API
  static String get taskReviewsSubmitUrl => api('/tasks/reviews_submit.php');

  static String get taskReviewsGetUrl => api('/tasks/reviews_get.php');

  // 聊天相關 API
  static String get chatUploadAttachmentUrl =>
      api('/chat/upload_attachment.php');

  static String get chatReportUrl => api('/chat/report.php');

  static String get chatBlockUserUrl => api('/chat/block_user.php');

  // 客服相關 API
  static String get supportCreateIssueUrl => api('/support/create_issue.php');

  static String get supportEventsUrl => api('/support/events.php');

  static String get supportUserEventsUrl => api('/support/user_events.php');

  static String get supportCloseEventUrl => api('/support/events_close.php');

  static String get supportRatingUrl => api('/support/events_rating.php');

  static String get supportIssuesListUrl => api('/support/issues.php');

  static String get supportClaimUrl => api(
      '/admin/support/issues/{id}/accept'); // 已整合到 Laravel SupportController

  // 靜態內容
  static String get pointPolicyUrl => api('/content/point_policy.php');

  // 大學列表 API
  static String get universitiesListUrl => api('/universities/list.php');

  // 推薦碼驗證 API
  static String get verifyReferralCodeUrl =>
      api('/auth/verify-referral-code.php');

  // 學生證上傳 API
  static String get uploadStudentIdUrl => api('/auth/upload-student-id.php');

  // Chat APIs (MVP)
  static String get unreadByTasksUrl => api('/chat/unreads.php'); // 更新為統一 API
  static String get unreadCountsUrl => api('/chat/unreads.php'); // 新增統一未讀 API
  static String get chatSendMessageUrl => api('/chat/send_message.php');
  static String get chatReadRoomV2Url => api('/chat/read_room_v2.php');
  static String get ensureRoomUrl => api('/chat/ensure_room.php');
}
