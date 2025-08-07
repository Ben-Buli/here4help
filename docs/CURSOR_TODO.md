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
1. **v3.2.5** - Salary 到 Reward Point 統一修改完成後 ✅
2. **v3.2.6** - 語言名稱顯示優化完成後 ✅
3. **v3.2.7** - TaskCreatePage 功能完善和優化完成後 ✅
4. **v3.2.8** - 使用者頭貼和使用者名稱欄位修復完成後 ✅
5. **v3.3.0** - 所有新功能整合完成後

#### 推送檢查清單：
- [x] 功能測試通過
- [x] 無編譯錯誤
- [x] UI/UX 符合設計要求
- [x] 資料庫整合正常
- [x] 文檔已更新

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

### 7. [✅] 任務資料自動生成
**目標**: 實現任務資料的自動生成功能
**檔案**: `lib/task/services/task_service.dart`
**狀態**: 已完成
**操作**:
- [✅] 實現任務資料自動生成邏輯
- [✅] 確保生成的資料符合實際需求
- [✅] 測試生成功能是否正常

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

## 🆕 最新任務清單 (2024年12月20日)

### 15. [✅] Salary 到 Reward Point 統一修改
**目標**: 將任務中的 `salary` 欄位統一改為 `reward_point`
**檔案**: 
- `lib/task/models/task_model.dart`
- `lib/task/viewmodels/task_form_viewmodel.dart`
- `lib/task/widgets/task_basic_info_section.dart`
- `lib/task/pages/task_create_page.dart`
- `lib/task/pages/task_preview_page.dart`
- `lib/task/pages/task_list_page.dart`
- `lib/task/pages/task_apply_page.dart`
- `lib/task/utils/task_form_validators.dart`
- `lib/chat/pages/chat_list_page.dart`
- `lib/chat/pages/chat_detail_page.dart`
- `backend/api/tasks/create.php`
- `backend/api/tasks/generate-sample-data.php`
- `backend/api/tasks/migrate_salary_to_reward_point.php`
**狀態**: 已完成
**版本**: v3.2.5
**操作**:
- [✅] 修改 TaskModel 中的 salary 欄位為 rewardPoint
- [✅] 更新 TaskFormViewModel 中的相關欄位
- [✅] 修改 UI 組件中的顯示邏輯
- [✅] 更新所有頁面中的引用
- [✅] 修改後端 API 支援新欄位
- [✅] 創建資料庫遷移腳本
- [✅] 確保向後兼容性
**推送資訊**:
```bash
git commit -m "feat: v3.2.5 - Salary to Reward Point Migration

- ✅ 將 salary 欄位統一改為 reward_point
- ✅ 更新所有前端模型和 UI 組件
- ✅ 修改後端 API 支援新欄位
- ✅ 創建資料庫遷移腳本
- ✅ 確保向後兼容性
- ✅ 統一專案和資料庫表述

版本: v3.2.5
日期: 2024-12-20"
```

### 16. [✅] 語言名稱顯示優化
**目標**: 修復語言顯示問題，確保使用英文名稱而不是代碼
**檔案**: 
- `lib/task/pages/task_create_page.dart`
- `lib/task/pages/task_preview_page.dart`
**狀態**: 已完成
**版本**: v3.2.6
**操作**:
- [✅] 修改語言選擇邏輯，使用語言名稱而不是代碼
- [✅] 更新語言顯示邏輯，直接使用語言名稱
- [✅] 修復任務預覽頁面的語言顯示
- [✅] 確保語言名稱正確傳遞和顯示
- [✅] 優化語言省略顯示邏輯
**推送資訊**:
```bash
git commit -m "fix: v3.2.6 - Language Name Display Optimization

- ✅ 修復語言顯示問題，使用英文名稱而不是代碼
- ✅ 更新語言選擇邏輯，存儲語言名稱
- ✅ 優化任務預覽頁面的語言顯示
- ✅ 確保語言名稱正確傳遞和顯示
- ✅ 完善語言省略顯示邏輯

版本: v3.2.6
日期: 2025-08-07"
```

### 17. [✅] TaskCreatePage 功能完善和優化
**目標**: 完善任務創建頁面的功能，包括驗證、主題配色和用戶體驗優化
**檔案**: 
- `lib/task/pages/task_create_page.dart`
- `lib/constants/theme_schemes.dart`
**狀態**: 已完成
**版本**: v3.2.7
**操作**:
- [✅] Reward Point 驗證功能完善
  - 添加數字整數驗證（只能輸入數字且大於0）
  - 將 '/point' 文字改為 '/hour'
  - 使用 `FilteringTextInputFormatter.digitsOnly` 限制輸入
- [✅] Application Questions 機制改進
  - 添加未填寫問題檢查邏輯
  - 只在點擊 "Add Question" 按鈕時才執行驗證
  - 添加 `_showApplicationQuestionErrors` 狀態變量控制錯誤顯示
  - 用戶開始填寫問題時自動清除錯誤提示
- [✅] Application Questions 佔位符文字更新
  - 將佔位符文字改為 "Job seekers must answer questions before applying, helping you screen talents faster"
- [✅] Language Requirements 自動排序功能移除
  - 移除語言選項的自動排序功能
  - 保持語言選項的原始順序
  - 簡化語言選擇邏輯
- [✅] 主題配色系統完善
  - 為 `ThemeScheme` 添加新的顏色屬性
  - 添加 `cardBackground`、`cardBorder`、`inputBackground`、`inputBorder`、`hintText`、`disabledText`、`divider`、`overlay`、`successBackground`、`warningBackground`、`errorBackground` 等屬性
  - 更新所有現有的 `ThemeScheme` 實例以包含新屬性
  - 將 `task_create_page.dart` 中的靜態顏色替換為主題配色
**推送資訊**:
```bash
git commit -m "feat: v3.2.7 - TaskCreatePage Feature Enhancement & Theme Integration

- ✅ Reward Point 驗證功能完善（數字整數驗證，/hour 文字）
- ✅ Application Questions 機制改進（點擊驗證，錯誤狀態控制）
- ✅ Application Questions 佔位符文字更新
- ✅ Language Requirements 自動排序功能移除
- ✅ 主題配色系統完善（新增顏色屬性，替換靜態顏色）
- ✅ 用戶體驗優化（即時反饋，清晰的驗證時機）

版本: v3.2.7
日期: 2025-08-07"
```

### 18. [✅] 使用者頭貼和使用者名稱欄位修復
**目標**: 修復任務創建頁面中使用者頭貼和使用者名稱欄位的讀取問題
**檔案**: 
- `lib/task/pages/task_create_page.dart`
- `lib/auth/services/user_service.dart`
- `lib/auth/models/user_model.dart`
**狀態**: 已完成
**版本**: v3.2.8
**操作**:
- [✅] 修復 `_buildPersonalInfoSection` 方法
  - 正確讀取 `UserService` 中的用戶信息
  - 正確顯示用戶名稱而不是靜態文字
  - 正確處理用戶頭貼顯示
- [✅] 用戶頭貼顯示優化
  - 支援網絡圖片頭貼顯示
  - 正確處理默認頭像的情況
  - 正確處理頭貼載入失敗的情況
- [✅] 用戶名稱顯示優化
  - 從 `UserService` 正確讀取用戶名稱
  - 支援多語言用戶名稱
  - 正確處理用戶名稱為空的情況
- [✅] 錯誤處理完善
  - 正確處理用戶服務未初始化的情況
  - 正確處理用戶信息載入失敗的情況
  - 提供合理的默認值
**推送資訊**:
```bash
git commit -m "fix: v3.2.8 - User Avatar and Name Field Fix

- ✅ 修復使用者頭貼和使用者名稱欄位讀取問題
- ✅ 正確顯示用戶頭貼（支援網絡圖片和默認頭像）
- ✅ 正確顯示用戶名稱（從 UserService 讀取）
- ✅ 完善錯誤處理和默認值處理
- ✅ 優化用戶信息顯示邏輯
- ✅ 更新 CURSOR_TODO.md 進度紀錄

版本: v3.2.8
日期: 2025-08-07"
```

---

## 📊 進度追蹤

### 已完成任務 ✅
- [x] 1. 檢查 task_create_page.dart 重複問題
- [x] 2. 移除 Question num 字樣
- [x] 3. 修復刪除按鈕邏輯
- [x] 4. 修復 Language Requirements 主題配色
- [x] 5. 任務創建流程完善
- [x] 6. 任務大廳排序和篩選功能
- [x] 7. 任務資料自動生成
- [x] 8. Home 頁面資料整合
- [x] 9. 優化 task/create 表單維護
- [x] 10. 修復 💰 emoji 顯示問題
- [x] 15. Salary 到 Reward Point 統一修改 (v3.2.5)
- [x] 16. 語言名稱顯示優化 (v3.2.6)
- [x] 17. TaskCreatePage 功能完善和優化 (v3.2.7)
- [x] 18. 使用者頭貼和使用者名稱欄位修復 (v3.2.8)

### 進行中任務 🔄
- 無

### 待執行任務 📋
- [ ] 19. Profile 頁面功能完善
- [ ] 20. Users 資料表結構確認
- [ ] 21. Security Settings 功能完善
- [ ] 22. 聊天室功能完善
- [ ] 23. 資料庫整合和 API 測試
- [ ] 24. UI/UX 優化

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
│   │   ├── task_create_page.dart    # 任務創建 (2718行)
│   │   └── task_preview_page.dart   # 任務預覽
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
- **新增**: Reward Point 系統統一管理
- **新增**: 用戶信息顯示系統完善

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
9. **向後兼容**: 確保新功能不破壞現有功能

---

## 🎯 完成標準

- [x] 首頁資料整合完成
- [x] 任務創建流程完整
- [x] 任務大廳排序和篩選正常
- [x] Salary 到 Reward Point 統一修改完成
- [ ] 聊天室功能完善
- [ ] 資料庫整合正常
- [ ] UI/UX 優化完成
- [x] TaskCreatePage 架構優化完成
- [ ] Dialog UI 主題風格完成
- [ ] Profile 頁面功能完成
- [ ] Users 資料表結構確認完成
- [ ] Security Settings 功能完成
- [x] 使用者頭貼和使用者名稱欄位修復完成
- [ ] 所有功能測試通過
- [x] 文檔已更新

---

## 🚀 Git 推送指令

### 版本信息
- **版本代號**: v3.2.8
- **版本名稱**: User Avatar and Name Field Fix
- **發布日期**: 2025年8月7日

### 推送指令
```bash
# 1. 檢查當前狀態
git status

# 2. 添加修改的文件（按組別）
# 任務創建頁面使用者信息修復
git add lib/task/pages/task_create_page.dart

# 使用者服務相關文件
git add lib/auth/services/user_service.dart
git add lib/auth/models/user_model.dart

# 文檔更新
git add docs/CURSOR_TODO.md

# 3. 提交修改
git commit -m "fix: v3.2.8 - User Avatar and Name Field Fix

- ✅ 修復使用者頭貼和使用者名稱欄位讀取問題
- ✅ 正確顯示用戶頭貼（支援網絡圖片和默認頭像）
- ✅ 正確顯示用戶名稱（從 UserService 讀取）
- ✅ 完善錯誤處理和默認值處理
- ✅ 優化用戶信息顯示邏輯
- ✅ 更新 CURSOR_TODO.md 進度紀錄

版本: v3.2.8
日期: 2025-08-07"

# 4. 推送到遠程倉庫
git push origin main

# 5. 創建標籤（可選）
git tag -a v3.2.8 -m "Version 3.2.8 - User Avatar and Name Field Fix"
git push origin v3.2.8
```

### 版本推送節點
```bash
# v3.2.5 - Salary 到 Reward Point 統一修改完成後 ✅
git commit -m "feat: v3.2.5 - Salary to Reward Point Migration"

# v3.2.6 - 語言名稱顯示優化完成後 ✅
git commit -m "fix: v3.2.6 - Language Name Display Optimization"

# v3.2.7 - TaskCreatePage 功能完善和優化完成後 ✅
git commit -m "feat: v3.2.7 - TaskCreatePage Feature Enhancement & Theme Integration"

# v3.2.8 - 使用者頭貼和使用者名稱欄位修復完成後 ✅
git commit -m "fix: v3.2.8 - User Avatar and Name Field Fix"

# v3.3.0 - 所有新功能整合完成後
git commit -m "feat: v3.3.0 - Complete Feature Integration"
```

---

## 📚 相關執行指南

### 🏗️ Salary 到 Reward Point 遷移指南
**文件位置**: `backend/api/tasks/migrate_salary_to_reward_point.php`
**目的**: 安全地將資料庫中的 salary 欄位遷移到 reward_point
**適用範圍**: 任務 15 - Salary 到 Reward Point 統一修改
**重要特點**:
- ✅ 自動檢測現有欄位結構
- ✅ 安全的數據遷移流程
- ✅ 向後兼容性支援
- ✅ 可選的欄位清理

**使用方式**:
1. 執行任務 15 時，請先備份資料庫
2. 運行遷移腳本：`php backend/api/tasks/migrate_salary_to_reward_point.php`
3. 按照提示完成遷移
4. 測試所有相關功能

---

*最後更新: 2025年8月7日*
*版本: 3.2.8* 