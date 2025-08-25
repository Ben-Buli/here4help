# Task Apply Page 問題載入修復報告（更新版）

## 🔍 **問題重新分析**

根據用戶反饋，實際的應徵流程使用的是：
- **應徵 API**：`/backend/api/tasks/applications/apply.php`
- **任務載入**：TaskService 使用 `/backend/api/tasks/list.php`

經過進一步分析發現：
1. `list.php` API **已經包含** `application_questions` 欄位
2. TaskService 的 `getTaskById()` 應該能返回包含問題的任務資料
3. 問題可能在於前端沒有正確處理或顯示這些資料

## 📊 **API 資料結構驗證**

### **list.php 中的問題載入邏輯**
```php
// 為每個任務獲取相關的申請問題和應徵人數
foreach ($tasks as &$task) {
    $questionsSql = "SELECT * FROM application_questions WHERE task_id = ?";
    $questions = $db->fetchAll($questionsSql, [$task['id']]);
    $task['application_questions'] = $questions;
    // ...
}
```

### **預期的任務資料格式**
```json
{
  "id": "task-uuid",
  "title": "Task Title",
  "description": "Task Description",
  "application_questions": [
    {
      "id": "question-uuid-1",
      "task_id": "task-uuid",
      "application_question": "What is your experience?",
      "created_at": "2025-01-01 12:00:00",
      "updated_at": "2025-01-01 12:00:00"
    },
    {
      "id": "question-uuid-2", 
      "task_id": "task-uuid",
      "application_question": "Why are you interested?",
      "created_at": "2025-01-01 12:00:00",
      "updated_at": "2025-01-01 12:00:00"
    }
  ]
}
```

## ✅ **修復方案（更新版）**

### **修復1：優化資料載入邏輯**

```dart
Future<Map<String, dynamic>> _loadTask(String taskId) async {
  try {
    // 優先使用 TaskService（list.php 已包含 application_questions）
    final taskService = TaskService();
    await taskService.loadTasks();
    final task = taskService.getTaskById(taskId);
    
    if (task != null) {
      debugPrint('✅ 從 TaskService 載入任務: ${task['title']}');
      debugPrint('✅ Application questions: ${task['application_questions']}');
      return task;
    }
    
    // 備用方案：使用專門的 API
    debugPrint('⚠️ TaskService 中找不到任務，嘗試使用 task_edit_data API');
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/backend/api/tasks/task_edit_data.php?id=$taskId')
    );
    // ... 處理回應
  } catch (e) {
    debugPrint('❌ 載入任務資料失敗: $e');
    return {};
  }
}
```

**改進點**：
1. **優先使用 TaskService**：因為 `list.php` 已經包含問題資料
2. **詳細的除錯輸出**：確認資料載入狀況
3. **雙重保險**：TaskService 失敗時使用 `task_edit_data.php`

### **修復2：保持動態 UI 生成**

UI 部分的修復保持不變：
- 動態生成問題欄位
- 自我介紹非必填，問題回答必填
- 正確的 Resume 資料結構

## 🧪 **測試和除錯**

### **測試步驟1：驗證資料載入**
1. 打開 TaskApplyPage
2. 查看控制台輸出：
   ```
   ✅ 從 TaskService 載入任務: [任務標題]
   ✅ Application questions: [問題陣列]
   ```

### **測試步驟2：驗證 UI 顯示**
1. 確認自我介紹欄位顯示（非必填）
2. 確認所有問題欄位都顯示（必填）
3. 確認問題數量與資料庫中的數量一致

### **測試步驟3：驗證提交流程**
1. 填寫表單並提交
2. 確認聊天室中顯示 Resume 氣泡
3. 點擊 "View Resume" 確認所有問題和回答都正確顯示

## 🔧 **可能的問題排查**

### **如果 TaskService 沒有返回問題**
可能原因：
1. 任務不在當前載入的列表中
2. `list.php` API 有問題
3. 資料庫中沒有對應的問題

**解決方案**：
- 檢查 `list.php` API 回應
- 確認資料庫中有 `application_questions` 資料
- 使用備用的 `task_edit_data.php` API

### **如果問題資料格式不正確**
可能原因：
1. API 返回的資料結構與預期不符
2. 問題欄位名稱不一致

**解決方案**：
- 檢查控制台輸出的資料格式
- 確認 `application_question` 欄位名稱
- 調整前端解析邏輯

## 📋 **API 流程確認**

### **完整的應徵流程**
1. **載入任務**：`TaskService.loadTasks()` → `list.php`
2. **顯示表單**：根據 `application_questions` 動態生成
3. **提交應徵**：`TaskService.applyForTask()` → `apply.php`
4. **建立聊天室**：`ChatService.ensureRoom()`
5. **發送 Resume**：`ChatService.sendMessage(kind='resume')`

### **資料流向**
```
list.php → TaskService → TaskApplyPage → apply.php → ChatService → Resume
```

## 🎯 **修復重點**

1. **確認 TaskService 正常工作**：`list.php` 應該包含問題資料
2. **保持 UI 邏輯不變**：動態生成、必填驗證等
3. **確保 Resume 整合**：與聊天室功能完全匹配
4. **提供備用方案**：`task_edit_data.php` 作為後備

## 🚀 **測試建議**

請測試以下場景並查看控制台輸出：

1. **正常情況**：
   - 任務有 1-3 個問題
   - 確認所有問題都正確顯示
   - 確認提交後 Resume 正確顯示

2. **邊界情況**：
   - 任務沒有問題（只有自我介紹）
   - 任務有很多問題（測試 UI 滾動）

3. **錯誤情況**：
   - 網路錯誤時的備用方案
   - 任務不存在時的處理

**關鍵是查看控制台輸出，確認 `application_questions` 資料是否正確載入！** 🔍
