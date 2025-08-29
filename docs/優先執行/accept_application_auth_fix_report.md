# Accept Application 認證修復報告

## 🔍 問題診斷結果

根據偵錯日誌分析，發現了新的問題：

### 問題描述
```
✅ 準備接受應徵 - Task: 6c8103c1-3642-46e7-a3a9-fc8b78d2e5bf, User: 2, Poster: 1
❌ Accept application failed: Exception: User not authenticated
```

### 根本原因
1. **Token Key 不一致**：`AuthService` 使用 `auth_token` 作為 key，但 `TaskService` 在尋找 `user_token`
2. **認證缺失**：前端調用 `acceptApplication` API 時沒有傳遞 `Authorization` header，但後端需要驗證用戶身份

## 🛠️ 修復方案

### 1. **修復 TaskService API 認證問題**

**修復的方法**：
- `acceptApplication()` - 接受應徵者
- `confirmCompletion()` - 確認完成
- `disagreeCompletion()` - 不同意完成
- `submitReview()` - 提交評論

**位置**：`lib/task/services/task_service.dart`

**修復前**：
```dart
final resp = await http
    .post(
      Uri.parse('${AppConfig.apiBaseUrl}/backend/api/tasks/applications/accept.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    )
    .timeout(const Duration(seconds: 30));
```

**修復後**：
```dart
// 獲取用戶 token
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('auth_token');  // 修正：使用正確的 key
if (token == null) {
  throw Exception('User not authenticated');
}

final resp = await http
    .post(
      Uri.parse('${AppConfig.apiBaseUrl}/backend/api/tasks/applications/accept.php'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    )
    .timeout(const Duration(seconds: 30));
```

### 2. **修復邏輯**
- 從 SharedPreferences 獲取用戶 token（使用正確的 key：`auth_token`）
- 檢查 token 是否存在
- 在請求頭中添加 `Authorization: Bearer $token`
- 提供適當的錯誤處理

## 📊 問題分析

### 後端 API 要求
```php
// 後端需要驗證用戶身份
$auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
  throw new Exception('Authorization header required');
}
$actor_id = TokenValidator::validateAuthHeader($auth_header);
if (!$actor_id) { throw new Exception('Invalid or expired token'); }
```

### 前端調用問題
- `acceptApplication` 方法沒有設置 `Authorization` header
- Token key 不一致：`AuthService` 使用 `auth_token`，但 `TaskService` 尋找 `user_token`
- 其他 API 調用（如 `submitReview`）也沒有設置認證
- 導致後端無法驗證用戶身份，返回 500 錯誤

## 🎯 修復效果

### 修復前的錯誤流程
1. 前端調用 `acceptApplication` API
2. 沒有傳遞 `Authorization` header
3. 後端無法驗證用戶身份
4. 拋出 "Authorization header required" 錯誤
5. 返回 HTTP 500 錯誤

### 修復後的正常流程
1. 前端從 SharedPreferences 獲取用戶 token
2. 在請求頭中添加 `Authorization: Bearer $token`
3. 後端成功驗證用戶身份
4. 執行 accept application 邏輯
5. 返回成功響應

## 📋 預期修復後的偵錯輸出

```
🔍 [ChatDetailPage] _handleAcceptApplication() 開始
  - _task: not null
  - _chatData: not null
  - _room: not null
🔍 [ChatDetailPage] 開始載入當前用戶ID
  - _currentUserId 已存在: 1
🔍 [ChatDetailPage] 檢查聊天室數據
  - _chatData: not null
  - _chatData 內容: [room, task, user_role, chat_partner_info]
🔍 [ChatDetailPage] 開始獲取對手用戶ID
🔍 [ChatDetailPage] _getOpponentUserId() 開始
  - _currentUserId: 1
  - _chatData: not null
  - _room: not null
  - room 內容: [id, task_id, creator_id, participant_id, type, created_at]
  - creatorId (原始): 1 (類型: int)
  - participantId (原始): 2 (類型: int)
  - creator (解析後): 1
  - participant (解析後): 2
  - currentUserId: 1
✅ [ChatDetailPage] 當前用戶是 creator，返回 participant: 2
  - 獲取到的 opponentId: 2
✅ 準備接受應徵 - Task: 6c8103c1-3642-46e7-a3a9-fc8b78d2e5bf, User: 2, Poster: 1
✅ Application accepted successfully
```

## 🚀 測試建議

### 1. **立即測試**
1. 重新啟動 Flutter 應用程式
2. 進入聊天詳情頁面
3. 點擊 accept 按鈕
4. 觀察控制台輸出，確認不再出現 HTTP 500 錯誤

### 2. **驗證修復**
- [ ] `acceptApplication` API 調用成功
- [ ] 任務狀態正確更新為 "in_progress"
- [ ] 應徵者被正確指派
- [ ] 其他應徵被拒絕
- [ ] 系統訊息正確發送

### 3. **認證測試**
- [ ] 用戶已登入時能正常執行
- [ ] 用戶未登入時顯示適當錯誤
- [ ] Token 過期時能正確處理

## 🔧 額外改進建議

### 1. **統一認證處理**
- 為所有需要認證的 API 調用添加 `Authorization` header
- 創建統一的認證處理方法
- 實現自動 token 刷新機制

### 2. **錯誤處理增強**
- 添加更詳細的錯誤訊息
- 實現自動重試機制
- 提供用戶友好的錯誤提示

### 3. **API 調用優化**
- 檢查其他 API 調用是否也需要認證
- 統一 API 調用的格式和錯誤處理
- 添加請求日誌記錄

## 📈 相關 API 檢查

### 需要檢查的其他 API
- `submitReview` - 提交評論
- `getReview` - 獲取評論
- `confirmCompletion` - 確認完成
- `disagreeCompletion` - 不同意完成

### 建議修復順序
1. ✅ `acceptApplication` - 已完成
2. ✅ `submitReview` - 已完成
3. ✅ `confirmCompletion` - 已完成
4. ✅ `disagreeCompletion` - 已完成

---

**修復狀態**: ✅ 已完成  
**測試狀態**: 🔄 待驗證  
**預期效果**: 解決 accept application 的 HTTP 500 認證錯誤
