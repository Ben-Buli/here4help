### Action Bar 按鈕對照表（功能 / 用途 / 前後端映射）

本文件對照 `/chat/detail` 的 Action Bar 各按鈕，說明用途、前端觸發點、後端 API 與副作用（狀態/訊息/日誌）。狀態代碼以 `task_statuses.code` 為準：open / in_progress / pending_confirmation / completed / dispute / cancelled / rejected。

#### 共同前端組件/檔案
- 設定來源：`lib/chat/utils/action_bar_config.dart`（依狀態/角色決定動作）
- ActionBar UI：`lib/chat/widgets/dynamic_action_bar.dart`
- 詳情頁處理：`lib/chat/pages/chat_detail_page.dart`

---

### Accept（指派應徵者）
- 使用時機：creator × open
- 用途：指派此應徵者為任務執行者，任務進入進行中
- 前端
  - 觸發：`_handleAcceptApplication()`（`chat_detail_page.dart`）
  - 服務：`TaskService.acceptApplication()`（已改呼叫 v2 URL）
- 後端
  - API：`backend/api/tasks/applications/accept.php`
  - 副作用：
    - `tasks.participant_id = user_id`
    - 若任務為 open → 切 `in_progress`
    - `task_applications`：當前 `accepted`，其餘 `rejected`
    - 當前聊天室送出 `kind='system'` 系統訊息
    - `user_active_log`：`action='application_accept'`，`field='participant_id'`

---

### Completed（提交完成/送審）
- 使用時機：participant × in_progress
- 用途：將任務提交為待發布者確認
- 前端
  - 觸發：`_handleCompleteTask()`
  - 服務：`TaskService.updateTaskStatus(..., statusCode: 'pending_confirmation')`
- 後端
  - API：`backend/api/tasks/update.php`
  - 副作用：狀態切至 `pending_confirmation`
  - 建議日誌：`user_active_log` → `action='task_mark_done_request'`

---

### Confirm（同意完成）
- 使用時機：creator × pending_confirmation
- 用途：同意任務完成，結算點數與手續費
- 前端
  - Dialog：`ConfirmCompletionDialog`（先 preview 再 confirm）
  - 服務：`TaskService.confirmCompletion(taskId, preview: true/false)`
- 後端
  - API：`backend/api/tasks/confirm_completion.php`（支援 `preview=1`）
  - 副作用：
    - `preview=1`：僅回傳 `{amount, fee_rate, fee, net}` 不更動資料
    - 正式確認：狀態切 `completed`；當前聊天室 `system` 訊息（含金額/費率/淨額）
    - 寫入 `user_active_log` 兩筆：
      - `task_completion_reward`（扣 rwd_pt）
      - `task_completion_fee`（扣 rwd_pt*rate）

---

### Disagree（駁回完成）
- 使用時機：creator × pending_confirmation
- 用途：不同意此次完成，退回進行中
- 前端
  - Dialog：`DisagreeCompletionDialog`（理由必填）
  - 服務：`TaskService.disagreeCompletion(taskId, reason)`
- 後端
  - API：`backend/api/tasks/disagree_completion.php`
  - 副作用：
    - 狀態 `pending_confirmation → in_progress`
    - 當前聊天室 `system` 訊息（含理由）
    - `user_active_log`：`action='disagree_completion'`，`field='status'`

---

### Raise Dispute（發起爭議）
- 使用時機：執行過程狀態（如 in_progress/pending_confirmation）
- 用途：將任務進入爭議，交由管理員處理
- 前端
  - 觸發：`_handleDispute()` → `DisputeDialog`
- 後端
  - API：`backend/api/tasks/dispute.php`
  - 副作用：狀態切 `dispute`，可擴充建立 `task_disputes` 記錄、管理員流程
  - 建議日誌：`user_active_log` → `action='task_dispute_create'`

---

### Report（檢舉）
- 使用時機：所有狀態
- 用途：檢舉聊天/用戶行為
- 前端
  - 服務：`ChatService.reportChat()`
- 後端
  - API：`AppConfig.chatReportUrl`（檢舉 API）
  - 副作用：建立檢舉工單/通知（依系統設計）
  - 建議日誌：`user_active_log` → `action='chat_report_submit'`

---

### Block（封鎖用戶）
- 使用時機：open / cancelled / rejected（其他執行過程使用 Dispute）
- 用途：雙方禁止互動
- 前端
  - 觸發：`_handleBlockUser()`
  - 服務：`ChatService.blockUser(targetUserId, block: true)`
- 後端
  - API：`AppConfig.chatBlockUserUrl`
  - 副作用：寫入 `user_blocks`、限制互動
  - 日誌：`user_active_log` → `action='user_block'`，`metadata={target_user_id}`

---

### Cancel Task（取消任務）
- 使用時機：creator × open
- 用途：取消未開始的任務
- 前端
  - 介面：`PostedTasksWidget` → Delete 按鈕
  - 服務：`TaskService.updateTaskStatus('canceled', statusId: 8)`（或 `status_code='cancelled'` 建議）
- 後端
  - API：`backend/api/tasks/update.php`
  - 副作用：狀態切 `cancelled`
  - 日誌：`user_active_log` → `action='task_cancel'`

---

### Reviews / Paid Info（資訊/評論）
- 使用時機：completed（已完成）
- 用途：顯示付款資訊或評價、或提交評價
- 前端
  - 觸發：`_showPaidInfo()`、`_openReviewDialog()`
- 後端
  - 評價提交：`backend/api/tasks/pay_and_review.php`（或 `submitReview` 相關端點）

---

### Withdraw Application（撤回應徵）
- 使用時機：participant × open（目前不在 `/chat/detail` 顯示；可加入）
- 前端
  - 服務：`TaskService.updateApplicationStatus('withdrawn')`
- 後端
  - API：`backend/api/tasks/applications/update-status.php`
  - 日誌：`user_active_log` → `action='application_withdraw'`

---

### 列表/快取刷新策略（狀態變更後）
- 接受應徵或狀態變更成功後：
  - 當前詳情：更新本地 `_task` 狀態，或 `_initializeChat()` 重新抓取
  - 列表刷新：
    - 發布者：`context.read<ChatListProvider>().checkAndTriggerTabLoad(ChatListProvider.TAB_POSTED_TASKS)`
    - 接案者：`context.read<ChatListProvider>().checkAndTriggerTabLoad(ChatListProvider.TAB_MY_WORKS)`
  - 快取：必要時 `context.read<ChatListProvider>().forceRefreshCache()`

---

### 參考檔案
- 前端
  - `lib/chat/utils/action_bar_config.dart`
  - `lib/chat/widgets/dynamic_action_bar.dart`
  - `lib/chat/pages/chat_detail_page.dart`
  - `lib/task/services/task_service.dart`
  - `lib/chat/services/chat_service.dart`
- 後端
  - `backend/api/tasks/applications/accept.php`
  - `backend/api/tasks/update.php`
  - `backend/api/tasks/confirm_completion.php`
  - `backend/api/tasks/disagree_completion.php`
  - `backend/api/tasks/dispute.php`
  - `backend/api/chat/send_message.php`（系統訊息寫入）


