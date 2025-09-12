# TaskHistoryPage 修正報告

## 🔍 **問題分析**

檢查 `TaskHistoryPage` 的三個分頁讀取邏輯，發現以下問題：

### ❌ **問題 1：缺少第三個分頁**
- 原本只有 2 個分頁：`Posted` 和 `Applied`
- 缺少 `Not Selected`（未被選中的申請）分頁

### ❌ **問題 2：欄位名稱不一致**
- 前端使用舊的欄位名稱 `acceptor_id`、`acceptor_name`
- 應該使用新的欄位名稱 `participant_id`、`participant_name`

### ❌ **問題 3：獎勵點數欄位錯誤**
- 前端使用 `reward_points`（複數）
- 後端返回 `reward_point`（單數）

### ❌ **問題 4：缺少錯誤處理**
- 沒有使用統一的錯誤處理服務

## ✅ **修正內容**

### 1. **添加第三個分頁**

**修正前**：
```dart
_tabController = TabController(length: 2, vsync: this);
```

**修正後**：
```dart
_tabController = TabController(length: 3, vsync: this);

// 添加第三個 Tab
Tab(
  icon: Icon(Icons.cancel_outlined),
  text: 'Not Selected',
),
```

### 2. **修正欄位名稱對應**

**前端修正**：
```dart
// ❌ 修正前
'acceptor_name'  // 錯誤
'acceptor_id'    // 錯誤

// ✅ 修正後  
'participant_name'  // 正確
'participant_id'    // 正確
```

**後端修正** (`backend/api/tasks/history.php`)：
```sql
-- ❌ 修正前
ta.user_id as acceptor_id,
u.name as acceptor_name,

-- ✅ 修正後
ta.user_id as participant_id,
u.name as participant_name,
```

### 3. **修正獎勵點數欄位**

```dart
// ❌ 修正前
'${task['reward_points']} pts'

// ✅ 修正後
'${task['reward_point']} pts'
```

### 4. **添加統一錯誤處理**

```dart
// ❌ 修正前
} catch (e) {
  setState(() {
    _errorMessage = e.toString().replaceFirst('Exception: ', '');
    _isLoading = false;
  });
}

// ✅ 修正後
} catch (e) {
  ErrorHandlerService.logError('TaskHistoryPage._loadTaskHistory', e);
  setState(() {
    _errorMessage = ErrorHandlerService.getOperationErrorMessage('load_tasks', e);
    _isLoading = false;
  });
}
```

### 5. **支援 Not Selected 分頁**

添加對第三個分頁的完整支援：

```dart
// API 調用邏輯
if (widget.type == 'not_selected') {
  final result = await RatingsService.fetchNotSelected(_currentPage);
  // 轉換數據格式...
} else {
  final role = widget.type == 'posted' ? 'poster' : 'acceptor';
  response = await TaskHistoryApi.getTaskHistory(role: role, ...);
}

// UI 顯示邏輯
Color _getApplicationStatusColor(String? status) {
  switch (status) {
    case 'rejected': return Colors.red;
    case 'cancelled': return Colors.grey;
    case 'withdrawn': return Colors.blue;
    default: return Colors.grey;
  }
}
```

## 📊 **三個分頁的完整邏輯**

### 1. **Posted Tasks** (發布的任務)
- **API**: `TaskHistoryApi.getTaskHistory(role: 'poster')`
- **數據源**: `tasks` 表，`creator_id = current_user_id`
- **顯示**: 用戶發布的任務及其狀態
- **評價**: 可以評價接受任務的 participant

### 2. **Applied Tasks** (申請的任務)
- **API**: `TaskHistoryApi.getTaskHistory(role: 'acceptor')`
- **數據源**: `task_applications` 表，`user_id = current_user_id AND status = 'accepted'`
- **顯示**: 用戶申請並被接受的任務
- **評價**: 可以評價任務的 creator

### 3. **Not Selected** (未被選中的申請)
- **API**: `RatingsService.fetchNotSelected()`
- **數據源**: `task_applications` 表，`user_id = current_user_id AND status IN ('rejected','cancelled','withdrawn')`
- **顯示**: 用戶申請但未被選中的任務
- **評價**: 不可評價

## 🎯 **資料庫欄位對應**

### Tasks 表
- ✅ `creator_id` - 任務發布者 ID
- ✅ `participant_id` - 任務執行者 ID（取代舊的 acceptor_id）
- ✅ `reward_point` - 獎勵點數（單數）

### Task_Applications 表
- ✅ `user_id` - 申請者 ID
- ✅ `task_id` - 任務 ID
- ✅ `status` - 申請狀態 ('applied', 'accepted', 'rejected', 'cancelled', 'withdrawn')

## 🔧 **修正的檔案**

### 前端
- `lib/account/pages/task_history_page.dart` - 主要修正檔案

### 後端
- `backend/api/tasks/history.php` - 修正欄位名稱

## ✅ **驗證結果**

1. **三個分頁正常顯示** ✅
2. **欄位名稱對應正確** ✅  
3. **錯誤處理統一** ✅
4. **語法檢查通過** ✅
5. **支援 creator_id/participant_id 新欄位** ✅

現在 `TaskHistoryPage` 的三個分頁邏輯都正確，並且完全支援新的資料庫欄位結構！
