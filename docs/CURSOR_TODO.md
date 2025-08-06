# Cursor TODO 執行清單

## 📋 使用說明

### 🎯 目的
此文件專門供 Cursor AI 按照順序執行任務，避免因對話長度限制而中斷。

### 🔄 執行方式
1. **複製此文件內容**到 Cursor 對話中
2. **按照編號順序執行**每個任務
3. **完成後標記** ✅ 或更新狀態
4. **繼續下一個任務**

### 📝 任務格式
- `[ ]` = 待執行
- `[🔄]` = 進行中  
- `[✅]` = 已完成
- `[❌]` = 已取消或失敗

### 🎯 執行原則
- **MVP 方式**：按現有 UI 繼續執行，不造成錯誤
- **Layout 統一**：使用 `App_Scaffold.dart` 作為 Layout，不重複生成 `Scaffold()`
- **進度追蹤**：每次任務完成後更新此文件
- **對話銜接**：中斷後可根據進度繼續執行

### 🚀 版本推送節點規劃
**重要**：每次完成階段性任務後，請在確認執行無誤後進行版本推送，確保保留正確版本。

#### 版本推送時機：
1. **v3.2.1** - TaskCreatePage 基礎架構準備完成後
2. **v3.2.2** - TaskCreatePage 組件拆分完成後
3. **v3.2.3** - TaskCreatePage 通用組件和優化完成後
4. **v3.2.4** - TaskCreatePage 整合和測試完成後
5. **v3.3.0** - 所有新功能整合完成後

#### 推送檢查清單：
- [ ] 功能測試通過
- [ ] 無編譯錯誤
- [ ] UI/UX 符合設計要求
- [ ] 資料庫整合正常
- [ ] 文檔已更新

---

## 🚀 當前執行清單

### 1. [✅] 檢查 task_create_page.dart 重複問題
**目標**: 移除重複的 Application Questions 區塊
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 搜尋重複的 `_buildApplicationQuestionsCard` 方法
- [✅] 移除重複方法，只保留 `_buildQuestionsSection`
- [✅] 確認沒有重複渲染問題

### 2. [✅] 移除 Question num 字樣
**目標**: 移除重複的問題編號顯示
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 找到 `Question ${index + 1}` 字樣
- [✅] 移除或替換為空字串
- [✅] 只保留 Q-01、Q-02 等標籤

### 3. [✅] 修復刪除按鈕邏輯
**目標**: 確保刪除按鈕正確對應到點擊的資料
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 檢查 `_removeApplicationQuestion` 方法
- [✅] 確認 index 參數正確傳遞
- [✅] 測試刪除功能是否正常

### 4. [✅] 修復 Language Requirements 主題配色
**目標**: 將靜態顏色改為動態主題色
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 找到所有 `AppColors.primary` 引用
- [✅] 替換為 `theme.primary`
- [✅] 確認主題變化時顏色會更新

---

## 🆕 新任務清單 (2024年12月19日)

### 5. [✅] 任務創建流程完善
**目標**: 完成任務創建、預覽、送出後在任務大廳刷新
**檔案**: 
- `lib/task/pages/task_create_page.dart`
- `lib/task/pages/task_preview_page.dart`
- `lib/task/pages/task_list_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 在任務創建頁面送出時，將資料透過 SharedPreferences 傳送到預覽頁面
- [✅] 任務預覽頁面讀取 SharedPreferences 資料並顯示
- [✅] 任務送出後，任務大廳能透過資料庫重新刷新任務清單
- [✅] 確保資料流程：創建 → 預覽 → 送出 → 大廳刷新

### 6. [✅] 任務大廳排序和篩選功能
**目標**: 實現任務大廳的排序和篩選功能
**檔案**: `lib/task/pages/task_list_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 實現按時間排序功能
- [✅] 實現按地點篩選功能
- [✅] 實現按語言篩選功能
- [✅] 實現按狀態篩選功能

### 7. [ ] 任務資料自動生成
**目標**: 實現任務資料的自動生成功能
**檔案**: `lib/task/services/task_service.dart`
**狀態**: 待執行
**操作**:
- [ ] 實現任務資料自動生成邏輯
- [ ] 確保生成的資料符合實際需求
- [ ] 測試生成功能是否正常

### 8. [✅] Home 頁面資料整合
**目標**: 整合 Home 頁面的資料顯示
**檔案**: `lib/home/pages/home_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 整合用戶資料顯示
- [✅] 整合任務統計資料
- [✅] 確保資料更新及時

### 9. [✅] 優化 task/create 表單維護
**目標**: 優化任務創建表單的維護性
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 優化表單驗證邏輯
- [✅] 改善錯誤處理機制
- [✅] 提升用戶體驗

### 10. [✅] 修復 💰 emoji 顯示問題
**目標**: 修復薪資顯示中的 emoji 問題
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 修復 💰 emoji 顯示問題
- [✅] 確保薪資顯示正常

---

## 🏗️ TaskCreatePage 重構專案 (v3.2.x 系列)

### 11. [✅] TaskCreatePage 基礎架構準備 (v3.2.1)
**目標**: 建立重構所需的基礎架構
**檔案**: 
- `lib/task/viewmodels/task_form_viewmodel.dart`
- `lib/task/widgets/`
- `lib/task/utils/`
**狀態**: 已完成
**版本**: v3.2.1
**操作**:
- [✅] 創建目錄結構 (`widgets/`, `viewmodels/`, `utils/`)
- [✅] 創建 `TaskFormViewModel` 類別
- [✅] 實現狀態管理邏輯
- [✅] 創建新的重構版本頁面
**推送資訊**:
```bash
git commit -m "refactor: v3.2.1 - TaskCreatePage Foundation Architecture

- ✅ 創建目錄結構 (widgets/, viewmodels/, utils/)
- ✅ 創建 TaskFormViewModel 類別
- ✅ 實現狀態管理邏輯
- ✅ 創建新的重構版本頁面
- ✅ 基礎架構準備完成

版本: v3.2.1
日期: 2024-12-19"
```

### 12. [✅] TaskCreatePage 組件拆分 (v3.2.2)
**目標**: 將大型組件拆分為小型可重用組件
**檔案**: `lib/task/widgets/`
**狀態**: 已完成
**版本**: v3.2.2
**操作**:
- [✅] 拆分 `WarningMessageCard` 組件
- [✅] 拆分 `SubmitTaskButton` 組件
- [✅] 拆分 `TaskPosterInfoCard` 組件
- [✅] 拆分 `TaskTimeSection` 組件
- [✅] 拆分 `TaskBasicInfoSection` 組件
- [✅] 拆分 `LanguageRequirementSection` 組件
- [✅] 拆分 `ApplicationQuestionsSection` 組件
**推送資訊**:
```bash
git commit -m "refactor: v3.2.2 - TaskCreatePage Component Extraction

- ✅ 拆分 WarningMessageCard 組件
- ✅ 拆分 SubmitTaskButton 組件
- ✅ 拆分 TaskPosterInfoCard 組件
- ✅ 拆分 TaskTimeSection 組件
- ✅ 拆分 TaskBasicInfoSection 組件
- ✅ 拆分 LanguageRequirementSection 組件
- ✅ 拆分 ApplicationQuestionsSection 組件
- ✅ 組件拆分完成

版本: v3.2.2
日期: 2024-12-19"
```

### 13. [✅] TaskCreatePage 通用組件和優化 (v3.2.3)
**目標**: 創建通用組件和工具類
**檔案**: 
- `lib/task/widgets/form_card.dart`
- `lib/task/utils/task_form_validators.dart`
- `lib/task/utils/user_avatar_helper.dart`
**狀態**: 已完成
**版本**: v3.2.3
**操作**:
- [✅] 創建 `FormCard` 通用組件
- [✅] 創建 `TaskFormValidators` 工具類
- [✅] 創建 `UserAvatarHelper` 助手類
- [✅] 優化代碼結構和可重用性
**推送資訊**:
```bash
git commit -m "refactor: v3.2.3 - TaskCreatePage Utility Components

- ✅ 創建 FormCard 通用組件
- ✅ 創建 TaskFormValidators 工具類
- ✅ 創建 UserAvatarHelper 助手類
- ✅ 優化代碼結構和可重用性
- ✅ 通用組件和優化完成

版本: v3.2.3
日期: 2024-12-19"
```

### 14. [✅] TaskCreatePage 整合和測試 (v3.2.4)
**目標**: 整合所有組件並進行測試
**檔案**: `lib/task/pages/task_create_page_refactored.dart`
**狀態**: 已完成
**版本**: v3.2.4
**操作**:
- [✅] 整合所有新組件
- [✅] 確保組件間通信正確
- [✅] 主題優化完成
- [✅] 性能優化完成
- [✅] 重構完成
**推送資訊**:
```bash
git commit -m "refactor: v3.2.4 - TaskCreatePage Integration & Testing

- ✅ 整合所有新組件
- ✅ 確保組件間通信正確
- ✅ 主題優化完成
- ✅ 性能優化完成
- ✅ 重構完成

版本: v3.2.4
日期: 2024-12-19"
```

**總結報告**: [TASK_CREATE_PAGE_REFACTORING_SUMMARY_REPORT.md](./TASK_CREATE_PAGE_REFACTORING_SUMMARY_REPORT.md)

---

## 📊 進度追蹤

### 已完成任務 ✅
- [x] 1. 檢查 task_create_page.dart 重複問題
- [x] 2. 移除 Question num 字樣
- [x] 3. 修復刪除按鈕邏輯
- [x] 4. 修復 Language Requirements 主題配色
- [x] 5. 任務創建流程完善
- [x] 6. 任務大廳排序和篩選功能
- [x] 8. Home 頁面資料整合
- [x] 9. 優化 task/create 表單維護
- [x] 10. 修復 💰 emoji 顯示問題
- [x] 11. TaskCreatePage 基礎架構準備 (v3.2.1)
- [x] 12. TaskCreatePage 組件拆分 (v3.2.2)
- [x] 13. TaskCreatePage 通用組件和優化 (v3.2.3)
- [x] 14. TaskCreatePage 整合和測試 (v3.2.4)

### 進行中任務 🔄
- 無

### 待執行任務 📋
- [ ] 7. 任務資料自動生成
- [ ] 16. Dialog UI 主題風格優化
- [ ] 17. Profile 頁面功能完善
- [ ] 18. Users 資料表結構確認
- [ ] 19. Security Settings 功能完善
- [ ] 20. 聊天室功能完善
- [ ] 21. 資料庫整合和 API 測試
- [ ] 22. UI/UX 優化

---

## 🔧 技術細節

### 頁面架構
```
路由 → 檔案 → 中文名稱
/home → home_page.dart → 首頁
/task → task_list_page.dart → 任務大廳頁面
/task/create → task_create_page.dart → 任務創建頁面
/task/create/preview → task_preview_page.dart → 任務創建預覽頁面
/chat → chat_list_page.dart → 聊天室列表頁面
/account → account_page.dart → 帳戶頁面
/account/profile → profile_page.dart → 個人資料頁面
/account/security → security_page.dart → 安全設定頁面
```

### 關鍵檔案結構
```
lib/
├── home/
│   └── pages/
│       └── home_page.dart           # 首頁
├── task/
│   ├── pages/
│   │   ├── task_list_page.dart      # 任務大廳
│   │   ├── task_create_page.dart    # 任務創建 (2542行，需重構)
│   │   └── task_preview_page.dart   # 任務預覽
│   ├── widgets/                     # 新增：TaskCreatePage 拆分組件
│   │   ├── task_poster_info_card.dart
│   │   ├── task_basic_info_section.dart
│   │   ├── task_time_section.dart
│   │   ├── application_questions_section.dart
│   │   ├── language_requirement_section.dart
│   │   ├── warning_message_card.dart
│   │   ├── submit_task_button.dart
│   │   └── form_card.dart
│   ├── viewmodels/                  # 新增：狀態管理
│   │   └── task_form_viewmodel.dart
│   ├── utils/                       # 新增：工具類
│   │   ├── task_form_validators.dart
│   │   └── user_avatar_helper.dart
│   └── services/
│       └── task_service.dart        # 任務服務
├── account/
│   ├── pages/
│   │   ├── account_page.dart        # 帳戶頁面
│   │   ├── profile_page.dart        # 個人資料頁面
│   │   └── security_page.dart       # 安全設定頁面
│   └── services/
├── chat/
│   ├── pages/
│   │   ├── chat_list_page.dart      # 聊天室列表
│   │   └── chat_detail_page.dart    # 聊天室詳情
│   └── services/
├── layout/
│   └── app_scaffold.dart            # 主要 Layout
└── constants/
    └── shell_pages.dart             # 頁面設定
```

### 資料流程
1. **首頁資料**: user_service → home_page (用戶資訊、成就統計)
2. **任務創建**: task_create_page → SharedPreferences → task_preview_page
3. **任務送出**: task_preview_page → 資料庫 → task_list_page 刷新
4. **任務應徵**: task_apply_page → 資料庫 → chat_list_page 更新
5. **聊天室**: chat_list_page → chat_detail_page
6. **個人資料**: profile_page → 資料庫更新 → user_service 刷新
7. **安全設定**: security_page → 資料庫更新 → 權限驗證

### 技術要點
- 使用 SharedPreferences 傳遞資料
- 資料庫整合和 API 調用
- App_Scaffold.dart 作為統一 Layout
- shell_pages.dart 管理頁面設定
- MVP 方式完成，不破壞現有 UI
- 權限系統整合（99/1/0/-1/-2）
- 主題系統統一管理

---

## 📝 注意事項

1. **執行順序**: 必須按照編號順序執行
2. **備份**: 執行前先備份重要檔案
3. **測試**: 每個任務完成後都要測試
4. **文檔**: 及時更新相關文檔
5. **提交**: 完成後及時提交到 Git
6. **MVP**: 按現有 UI 繼續執行，不造成錯誤
7. **Layout**: 使用 App_Scaffold.dart，不重複生成 Scaffold()
8. **版本推送**: 每完成階段性任務後進行版本推送

---

## 🎯 完成標準

- [x] 首頁資料整合完成
- [x] 任務創建流程完整
- [x] 任務大廳排序和篩選正常
- [ ] 聊天室功能完善
- [ ] 資料庫整合正常
- [ ] UI/UX 優化完成
- [ ] TaskCreatePage 架構優化完成
- [ ] Dialog UI 主題風格完成
- [ ] Profile 頁面功能完成
- [ ] Users 資料表結構確認完成
- [ ] Security Settings 功能完成
- [ ] 所有功能測試通過
- [x] 文檔已更新

---

## 🚀 Git 推送指令

### 版本信息
- **版本代號**: v3.2.0
- **版本名稱**: TaskCreatePage Architecture Optimization
- **發布日期**: 2024年12月19日

### 推送指令
```bash
# 1. 檢查當前狀態
git status

# 2. 添加所有修改
git add .

# 3. 提交修改
git commit -m "feat: v3.2.0 - TaskCreatePage Architecture Optimization

- ✅ 整合 TaskCreatePage 優化執行紀錄到 CURSOR_TODO.md
- ✅ 按優先級排序優化任務（Widget拆分 > 狀態管理 > 主題優化 > 驗證器模組化 > 工具類優化）
- ✅ 新增 TaskCreatePage 架構優化清單（11-15項任務）
- ✅ 新增 UI/UX 優化清單（16-19項任務）
- ✅ 新增版本推送節點規劃
- ✅ 更新檔案結構規劃和技術細節
- ✅ 準備 TaskCreatePage 重構工作

版本: v3.2.0
日期: 2024-12-19"

# 4. 推送到遠程倉庫
git push origin main

# 5. 創建標籤（可選）
git tag -a v3.2.0 -m "Version 3.2.0 - TaskCreatePage Architecture Optimization"
git push origin v3.2.0
```

### 版本推送節點
```bash
# v3.2.1 - Dialog UI 主題風格完成後
git commit -m "feat: v3.2.1 - Dialog UI Theme Integration"

# v3.2.2 - Profile 頁面功能完成後
git commit -m "feat: v3.2.2 - Profile Page Functionality"

# v3.2.3 - Users 資料表結構確認完成後
git commit -m "feat: v3.2.3 - Users Table Structure & Permissions"

# v3.2.4 - Security Settings 功能完成後
git commit -m "feat: v3.2.4 - Security Settings Implementation"

# v3.3.0 - 所有新功能整合完成後
git commit -m "feat: v3.3.0 - Complete Feature Integration"
```

---

## 📚 相關執行指南

### 🏗️ TaskCreatePage 重構執行指南
**文件位置**: [docs/TASK_CREATE_PAGE_REFACTORING_GUIDE.md](./TASK_CREATE_PAGE_REFACTORING_GUIDE.md)
**目的**: 詳細記錄 TaskCreatePage 重構的執行順序和注意事項
**適用範圍**: 任務 11 - TaskCreatePage Widget 拆分
**重要特點**:
- ✅ 按階段分組的詳細執行步驟
- ✅ 每個步驟都有明確的目標和備注
- ✅ 版本推送節點規劃
- ✅ 中斷恢復指南
- ✅ 完成標準和質量要求

**使用方式**:
1. 執行任務 11 時，請先閱讀此指南
2. 按照指南中的順序逐步執行
3. 每完成一個階段都要更新狀態和進行版本推送
4. 如果執行中斷，可以根據備注快速恢復

---

*最後更新: 2024年12月19日*
*版本: 3.2.0* 