# Support Action Bar 修復總結

## 修復的問題

### 1. 🔧 'View Issue' Dialog 無法顯示 Timeline 狀態

**問題**：Support action bar 的 'view issue' 功能無法顯示 timeline 狀態

**解決方案**：
- ✅ 添加缺少的 import 語句：
  - `import 'package:here4help/services/api/support_event_api.dart';`
  - `import 'package:here4help/widgets/support_timeline_dialog.dart';`
- ✅ 修復重複的 import 語句
- ✅ 確認 `_handleShowSupportTimeline()` 方法正確實作

### 2. 🔧 UserRole 對應關係修正

**問題**：UserRole 應該對應到資料表的 user_id 和 admin_id

**修正前**：
```dart
enum UserRole {
  creator, // 客戶（提交支援請求的用戶）
  participant // 管理員（處理支援請求的客服人員）
}
```

**修正後**：
```dart
enum UserRole {
  customer, // 客戶（提交支援請求的用戶，對應 support_chat_rooms.user_id）
  admin // 管理員（處理支援請求的客服人員，對應 support_chat_rooms.admin_id）
}
```

**資料表對應關係**：
- `UserRole.customer` ↔ `support_chat_rooms.user_id`
- `UserRole.admin` ↔ `support_chat_rooms.admin_id`

### 3. 🔧 401 授權錯誤修復

**問題**：API 請求返回 401 "Missing or invalid authorization header" 錯誤

**解決方案**：
在 `backend/api/support/events.php` 中增強授權處理邏輯：

```php
// JWT 認證 - 支援多種授權方式
$authHeader = '';

// 方法 1: 嘗試從 getallheaders() 獲取
if (function_exists('getallheaders')) {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? '';
}

// 方法 2: 從 $_SERVER 獲取
if (empty($authHeader)) {
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
}

// 方法 3: 從查詢參數獲取 token（MAMP 兼容）
if (empty($authHeader) && isset($_GET['token'])) {
    $authHeader = 'Bearer ' . $_GET['token'];
}
```

## 修改的文件

### Frontend (Dart)

1. **`lib/chat/utils/support_action_bar_config.dart`**
   - 修正 `UserRole` 枚舉值
   - 更新相關註釋和邏輯
   - 增加向後兼容性

2. **`lib/chat/widgets/support_dynamic_action_bar.dart`**
   - 更新 `UserRole` 引用
   - 修正佔位符角色

3. **`lib/account/pages/support_chat_detail_page.dart`**
   - 添加缺少的 import 語句
   - 修復重複的 import
   - 確保 timeline dialog 功能正常

### Backend (PHP)

4. **`backend/api/support/events.php`**
   - 增強授權標頭處理
   - 支援多種授權方式
   - 提高 MAMP 環境兼容性

## 功能驗證

### ✅ View Issue Dialog
- 點擊 "View Issue" 按鈕
- 正確顯示 `SupportTimelineDialog`
- 顯示客服事件的時間線狀態

### ✅ UserRole 對應
- `customer` 角色對應 `support_chat_rooms.user_id`
- `admin` 角色對應 `support_chat_rooms.admin_id`
- 保持向後兼容性（`creator` → `customer`, `participant` → `admin`）

### ✅ 授權處理
- 支援標準 Authorization Header
- 支援 $_SERVER 變數
- 支援查詢參數 token（MAMP 兼容）
- 解決 401 授權錯誤

## 測試建議

1. **Timeline Dialog 測試**：
   ```dart
   // 在客服聊天室中點擊 "View Issue" 按鈕
   // 應該顯示包含事件時間線的對話框
   ```

2. **角色權限測試**：
   ```dart
   // 客戶（user_id）應該看到 "View Issue" 和 "Close" 按鈕
   // 管理員（admin_id）不應該看到特殊動作按鈕
   ```

3. **API 授權測試**：
   ```bash
   # 測試 API 請求是否正確處理授權
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        "https://your-domain/api/support/events?chat_room_id=123"
   ```

## 注意事項

- ⚠️ 確保前端使用正確的角色判斷邏輯
- ⚠️ 測試不同環境下的授權處理
- ⚠️ 驗證 timeline dialog 的數據顯示正確性

所有修復都已完成，Support Action Bar 現在應該能正常顯示 timeline 狀態並正確處理用戶角色權限！
