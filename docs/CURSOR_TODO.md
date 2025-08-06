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
**目標**: 實現任務排序和篩選功能
**檔案**: `lib/task/pages/task_list_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 實現排序：更新時間 Desc、狀態 Open（發佈中任務優先）
- [✅] 不顯示發文者所發布的任務（過濾自己的任務）
- [✅] 在下拉選單左側新增可點擊 icon
- [✅] 點擊 icon 後彈出視窗，可快速篩選條件（如顯示狀態）
- [✅] 檢查並更新任務大廳的下拉式選單內容

### 7. [ ] 任務資料自動生成
**目標**: 為現有 tasks 資料空欄位自動生成符合語境的任務資訊
**檔案**: `lib/task/services/task_service.dart`
**操作**:
- [ ] 檢查現有 tasks 資料的空欄位
- [ ] 自動生成符合語境的任務資訊
- [ ] 填入提供的使用者作為任務發布者

---

## 🆕 最新任務清單 (2024年12月19日更新)

### 8. [✅] Home 頁面資料整合
**目標**: 確認 Home 頁面介面對應到資料庫資料
**檔案**: 
- `lib/home/pages/home_page.dart`
- `lib/auth/services/user_service.dart`
- `lib/task/services/task_service.dart`
**狀態**: 已完成
**操作**:
- [✅] 整合使用者名稱和頭像顯示（從資料庫獲取）
- [✅] 實現統整對應該使用者所完成的任務評價（滿分五顆星評價）
- [✅] 用括弧備注該使用者完成的任務評論數量
- [✅] 實現四個成就系統：
  - [✅] 會員點數
  - [✅] 任務完成數量（該使用者完成任務總數）
  - [✅] 五星數量統計（統計該使用者獲得的滿分總數）
  - [✅] 評價系統（滿分 5.0 小數平均一位數）

### 9. [✅] 優化 task/create 表單維護
**目標**: 讓表單更好維護
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 重構表單結構，提高可維護性
- [✅] 統一表單驗證邏輯
- [✅] 優化表單組件重用性
- [✅] 改善錯誤處理和用戶反饋
- [✅] 統一主題配色使用
- [✅] 修復 task preview HTTP 422 錯誤（缺少 description 欄位）
- [✅] 添加 description 輸入欄位
- [✅] 更新驗證邏輯

### 10. [✅] 修復 💰 emoji 顯示問題
**目標**: 修復任務創建頁面中 💰 emoji 不顯示的問題
**檔案**: `lib/task/pages/task_create_page.dart`
**狀態**: 已完成
**操作**:
- [✅] 增加 💰 emoji 字體大小從 16 到 24
- [✅] 確保容器有足夠高度（48px）
- [✅] 修正文字對齊和行高
- [✅] 統一所有相關元素的高度
- [✅] 測試 emoji 顯示是否正常

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

### 進行中任務 🔄
- 無

### 待執行任務 📋
- [ ] 7. 任務資料自動生成
- [ ] 11. 聊天室功能完善
- [ ] 12. 資料庫整合和 API 測試
- [ ] 13. UI/UX 優化

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
│   │   ├── task_create_page.dart    # 任務創建
│   │   └── task_preview_page.dart   # 任務預覽
│   └── services/
│       └── task_service.dart        # 任務服務
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

### 技術要點
- 使用 SharedPreferences 傳遞資料
- 資料庫整合和 API 調用
- App_Scaffold.dart 作為統一 Layout
- shell_pages.dart 管理頁面設定
- MVP 方式完成，不破壞現有 UI

---

## 📝 注意事項

1. **執行順序**: 必須按照編號順序執行
2. **備份**: 執行前先備份重要檔案
3. **測試**: 每個任務完成後都要測試
4. **文檔**: 及時更新相關文檔
5. **提交**: 完成後及時提交到 Git
6. **MVP**: 按現有 UI 繼續執行，不造成錯誤
7. **Layout**: 使用 App_Scaffold.dart，不重複生成 Scaffold()

---

## 🎯 完成標準

- [x] 首頁資料整合完成
- [x] 任務創建流程完整
- [x] 任務大廳排序和篩選正常
- [ ] 聊天室功能完善
- [ ] 資料庫整合正常
- [ ] UI/UX 優化完成
- [ ] 所有功能測試通過
- [x] 文檔已更新

---

## 🚀 Git 推送指令

### 版本信息
- **版本代號**: v3.1.0
- **版本名稱**: Task Create UI Enhancement & Emoji Fix
- **發布日期**: 2024年12月19日

### 推送指令
```bash
# 1. 檢查當前狀態
git status

# 2. 添加所有修改
git add .

# 3. 提交修改
git commit -m "feat: v3.1.0 - Task Create UI Enhancement & Emoji Fix

- ✅ 修復 💰 emoji 顯示問題（字體大小、容器高度、文字對齊）
- ✅ 優化 task/create 表單維護和結構
- ✅ 統一表單驗證邏輯和錯誤處理
- ✅ 修復 Language Requirements 主題配色
- ✅ 完善任務創建流程（創建 → 預覽 → 送出 → 大廳刷新）
- ✅ 實現任務大廳排序和篩選功能
- ✅ 整合 Home 頁面資料（用戶資訊、成就統計）
- ✅ 移除重複的 Application Questions 區塊
- ✅ 修復刪除按鈕邏輯和問題編號顯示

版本: v3.1.0
日期: 2024-12-19"

# 4. 推送到遠程倉庫
git push origin main

# 5. 創建標籤（可選）
git tag -a v3.1.0 -m "Version 3.1.0 - Task Create UI Enhancement & Emoji Fix"
git push origin v3.1.0
```

---

*最後更新: 2024年12月19日*
*版本: 3.1.0* 