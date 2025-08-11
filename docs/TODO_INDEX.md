# Here4Help TODO - 快速索引

## 📊 專案狀態
- **完成度**: 43.1% (28/65 任務)
- **目標**: 7天內完成 100%
- **當前版本**: v3.3.1
- **下個版本**: v3.3.2 (用戶權限系統 / 未讀 UI)

## 🎯 最新進展 (2025/8/11)
### ✅ 完成項目
- **聊天列表載入修復**: 修正 `/chat` 頁面應徵者卡片在 hot restart 和 web 刷新時消失的問題
- **載入狀態優化**: 實現 `_isInitialLoadComplete` 標記來追蹤真正的載入完成狀態
- **UI 體驗改善**: 添加載入進度顯示和重試功能
- **數據持久化**: FutureBuilder 邏輯優化確保數據載入完成後正確顯示 UI
- **聊天訊息持久化**: 完成 `/chat/detail` 訊息保存到 `chat_messages`
- **Socket.IO 整合**: 建立即時聊天基礎架構，支援即時訊息接收/發送
- **聊天室創建優化**: 應徵後使用 `ensure_room` 建立 BIGINT `chat_rooms.id`
- **自動首則訊息**: 應徵成功後前端自動以 `cover_letter`（附回答摘要）呼叫 `chat/send_message.php` 寫入 `chat_messages`，並嘗試透過 Socket 推播
- **My Works 導航回退**: 若該任務下無現成房間，`My Works` 點擊會回退呼叫 `ensure_room` 以目前使用者作為 participant 建立/取得房間，之後持久化並導頁
- **View Resume 強化**: 以 `cover_letter` 作為自我推薦，`answers_json` 以「問題原文」為鍵；支援字串/物件雙格式解析
- **/task/apply 傳輸格式調整**: 前端改傳 `answers: {questionText: answer}`；後端 `apply.php` 僅存 q1..q3 相容回退
- **資料庫同步/清理**:
  - 將舊 `answers_json(q1/q2/q3/introduction)` 轉換為「問題原文」鍵
  - `introduction → cover_letter`（僅 cover 為空時）
  - 為開放中任務自動補 3 題自訂問題
- **聊天室參與者一致化**: 批次將 `chat_rooms.participant_id` 對齊最新 `task_applications.user_id`
- **假資料產生器**: 以新格式批量產生 `task_applications` 假資料

## 🚀 今日任務 (Day 2 - 8/9)
- **21 (Socket 核心)**
  - 建立 Node.js Socket.IO Gateway（auth/rooms/events）
  - 事件：auth/join_room/leave_room/send_message/read_room/typing
  - 推送：unread_total、unread_room
- **26（未讀 MVP）**
  - 後端 `unread_snapshot.php`（冷啟/重連一次性）
  - 前端 Navbar 徽章 + 進房清零
- **20（列表與面板收斂）**
  - Posted/My Works 用真實 API（`applications/list_by_user.php` + `acceptor_id` 規則）
  - 任務資訊 Bottom Sheet 定稿
- **27（部分）**
  - `acceptor_id` 型態與 FK 已處理；清理殘留程式的舊欄位依賴

## 📋 任務分類

### ✅ 已完成 (24個)
- 1-10: 核心功能完善
- 15-18: 基礎功能修復
- 19: 任務狀態設計文件
- 20a: 聊天列表載入修復 (2025/8/11)
- 20b: FutureBuilder 優化 (2025/8/11)
- 21: Socket.IO 整合 (2025/8/11) - 完成即時聊天基礎架構
- 26a: 聊天訊息持久化 (2025/8/11) - 訊息保存到資料庫
- 26b: 聊天室創建優化 (2025/8/11) - 任務應徵後自動創建聊天室

### 🔄 進行中 (2個)
- 26（未讀 UI 整合）
- 22（用戶權限系統）

### 📋 待執行 (41個)

#### 🗓️ Day 1 - 聊天室功能 ✅ 完成
- ~~20: 聊天室列表優化~~ ✅ 已完成 (2025/8/11)
- ~~21: Socket.IO 整合~~ ✅ 已完成 (2025/8/11) - 完成即時聊天架構
- ~~26a: 聊天訊息持久化~~ ✅ 已完成 (2025/8/11) - 訊息保存到資料庫
- 26b: 未讀通知系統 - 基礎架構已完成，待前端 UI 整合

#### 🗓️ Day 2 - 用戶權限 (3個)
- 22: 用戶權限系統
- 27: 資料庫結構優化
- 28: API 端點完善

#### 🗓️ Day 3 - 第三方登入 (4個)
- 52: 資料庫結構擴展
- 53: Google 登入
- 54: Facebook 登入
- 55: Apple ID 登入

#### 🗓️ Day 4 - 個人資料 (5個)
- 23: 個人資料頁面
- 24: 安全設定頁面
- 25: 任務歷史頁面
- 40: 預設頭像功能
- 41: 語言預設

#### 🗓️ Day 5 - 錢包系統 (7個)
- 30: 錢包主題配色
- 31: 官方帳戶資料表
- 32: 點數系統完善
- 33: 優惠券系統
- 34: 儲值功能
- 35: 點數歷史紀錄
- 39: 點數驗證

#### 🗓️ Day 6 - 客服支援 (4個)
- 36: 客服聊天室
- 37: FAQ 系統
- 38: 問題追蹤
- 42: 評分系統

#### 🗓️ Day 7 - 部署整合 (6個)
- 47: cPanel 部署準備
- 48: 資料庫遷移
- 49: 圖片上傳優化
- 50: 部署腳本
- 51: SSL 配置
- 29: UI/UX 優化

## 🎯 優先級策略

### 🔥 第一優先級 (必須完成)
1. 聊天室功能 (v3.3.0)
2. 用戶權限系統 (v3.3.1)
3. 個人資料功能 (v3.3.2)
4. 錢包系統 (v3.3.3)
5. 客服支援 (v3.3.4)

### 🔄 第二優先級 (可延後)
1. 第三方登入 (v3.4.1)
2. cPanel 部署 (v3.4.2)
3. 高級優化 (v3.4.3)

## ⚡ AI 開發指南

### 提示詞模板
```
**任務**: [編號] - [名稱]
**目標**: [具體目標]
**檔案**: [檔案路徑]
**要求**: [具體要求]
**參考**: [相關代碼]
```

### 效率技巧
- 模組化開發
- 代碼重用
- 快速迭代
- 上下文管理

### 模型切換快參（GPT‑5 vs fast）
- 預設 fast；以下情境切 GPT‑5：
  - 架構/跨模組/長上下文
  - 路由/狀態/權限/認證
  - 效能/競態/疑難除錯
- fast 適用：UI 微調、CRUD、樣板、測試/文件、重命名。
- 專案對應：GPT‑5 → `lib/router/app_router.dart`、`lib/auth/services/*`、`lib/chat/pages/*`；其餘日常 → fast。
- 詳細指引：見 `docs/CURSOR_TODO_OPTIMIZED.md` 的「AI 開發策略 > 模型切換指引」。

## 🔐 第三方登入申請
- **Google OAuth**: https://console.cloud.google.com/
- **Facebook Login**: https://developers.facebook.com/
- **Apple Sign-In**: https://developer.apple.com/

## 📞 支援資源
- **Flutter**: https://docs.flutter.dev/
- **PHP**: https://www.php.net/manual/
- **MySQL**: https://dev.mysql.com/doc/

---

**詳細文檔**: [CURSOR_TODO.md](./CURSOR_TODO.md) | [優化版](./CURSOR_TODO_OPTIMIZED.md) 