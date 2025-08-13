# Cursor 執行指令

## 🎯 當前任務：Here4Help Flutter APP 功能完善

### 📋 執行順序：

#### 5. [ ] 任務創建流程完善
**目標**: 完成任務創建、預覽、送出後在任務大廳刷新
**檔案**: 
- `lib/task/pages/task_create_page.dart`
- `lib/task/pages/task_preview_page.dart`
- `lib/task/pages/task_list_page.dart`

**操作**:
```bash
# 1. 檢查 SharedPreferences 使用
grep -n "SharedPreferences" lib/task/pages/task_create_page.dart
grep -n "SharedPreferences" lib/task/pages/task_preview_page.dart

# 2. 檢查資料流程
grep -n "task_preview\|preview" lib/task/pages/task_create_page.dart
grep -n "task_list\|refresh" lib/task/pages/task_preview_page.dart
```

**具體實現**:
- [ ] 在任務創建頁面送出時，將資料透過 SharedPreferences 傳送到預覽頁面
- [ ] 任務預覽頁面讀取 SharedPreferences 資料並顯示
- [ ] 任務送出後，任務大廳能透過資料庫重新刷新任務清單
- [ ] 確保資料流程：創建 → 預覽 → 送出 → 大廳刷新

#### 6. [ ] 任務大廳排序和篩選功能
**目標**: 實現任務排序和篩選功能
**檔案**: `lib/task/pages/task_list_page.dart`

**操作**:
```bash
# 檢查現有排序邏輯
grep -n "sort\|order" lib/task/pages/task_list_page.dart
grep -n "filter\|篩選" lib/task/pages/task_list_page.dart
```

**具體實現**:
- [ ] 實現排序：更新時間 Desc、狀態 Open（發佈中任務優先）
- [ ] 不顯示發文者所發布的任務（過濾自己的任務）
- [ ] 在下拉選單左側新增可點擊 icon
- [ ] 點擊 icon 後彈出視窗，可快速篩選條件（如顯示狀態）
- [ ] 檢查並更新任務大廳的下拉式選單內容

#### 7. [ ] 任務資料自動生成
**目標**: 為現有 tasks 資料空欄位自動生成符合語境的任務資訊
**檔案**: `lib/task/services/task_service.dart`

**操作**:
```bash
# 檢查現有任務資料結構
grep -n "tasks\|task" lib/task/services/task_service.dart
```

**具體實現**:
- [ ] 檢查現有 tasks 資料的空欄位
- [ ] 自動生成符合語境的任務資訊
- [ ] 填入提供的使用者作為任務發布者
- [ ] 確保生成的資料符合資料庫結構

#### 8. [ ] 聊天室功能完善
**目標**: 聊天室列表和應徵功能
**檔案**: 
- `lib/chat/pages/chat_list_page.dart`
- `lib/chat/pages/chat_detail_page.dart`

**操作**:
```bash
# 檢查聊天室相關功能
grep -n "chat\|Chat" lib/chat/pages/chat_list_page.dart
grep -n "poster\|user" lib/chat/pages/chat_list_page.dart
```

**具體實現**:
- [ ] 聊天室列表會因為新任務增加後，讀取到新的任務
- [ ] 任務應徵送出時，寫進資料庫
- [ ] 對應的聊天室下面新增對應的應徵者資訊
- [ ] 在聊天室列表的 poster 欄位備注：若發文對象為登入使用者，在使用者名稱旁邊備注 `${user_name}(You)` 字樣

#### 9. [ ] 資料庫整合和 API 測試
**目標**: 確保所有功能與資料庫正常整合
**檔案**: 
- `backend/api/tasks/`
- `lib/task/services/`

**操作**:
```bash
# 檢查 API 端點
ls -la backend/api/tasks/
grep -n "api\|API" lib/task/services/task_service.dart
```

**具體實現**:
- [ ] 測試任務創建 API
- [ ] 測試任務列表 API
- [ ] 測試任務應徵 API
- [ ] 測試聊天室 API
- [ ] 確保資料庫表結構正確

#### 10. [ ] UI/UX 優化
**目標**: 改善用戶體驗
**檔案**: 相關頁面檔案

**操作**:
```bash
# 檢查 Layout 使用
grep -n "App_Scaffold\|Scaffold" lib/layout/app_scaffold.dart
grep -n "shell_pages" lib/constants/shell_pages.dart
```

**具體實現**:
- [ ] 確保所有頁面使用 App_Scaffold.dart 作為 Layout
- [ ] 不重複生成 Scaffold()
- [ ] 檢查 shell_pages.dart 設定
- [ ] 優化載入動畫和錯誤處理
- [ ] 改善表單驗證和用戶反饋

### 🔧 關鍵檔案：
- `lib/task/pages/task_create_page.dart` - 任務創建
- `lib/task/pages/task_preview_page.dart` - 任務預覽
- `lib/task/pages/task_list_page.dart` - 任務大廳
- `lib/chat/pages/chat_list_page.dart` - 聊天室列表
- `lib/layout/app_scaffold.dart` - 主要 Layout
- `lib/constants/shell_pages.dart` - 頁面設定

### 🎯 完成標準：
- [ ] 任務創建流程完整（創建 → 預覽 → 送出 → 大廳刷新）
- [ ] 任務大廳排序和篩選正常
- [ ] 聊天室功能完善
- [ ] 資料庫整合正常
- [ ] UI/UX 優化完成

### 📝 執行原則：
- **MVP 方式**：按現有 UI 繼續執行，不造成錯誤
- **Layout 統一**：使用 `App_Scaffold.dart` 作為 Layout，不重複生成 `Scaffold()`
- **進度追蹤**：每次任務完成後更新 `docs/CURSOR_TODO.md`

### 🚀 下一步：
完成後更新 `docs/CURSOR_TODO.md` 中的進度，並準備下一個任務。 