# Here4Help TODO - 快速索引

## 📊 專案狀態
- **完成度**: 29.2% (19/65 任務)
- **目標**: 7天內完成 100%
- **當前版本**: v3.2.9
- **下個版本**: v3.3.0 (聊天室功能)

## 🚀 今日任務 (Day 2 - 8/9)
- **20**: 聊天室列表頁面優化（收尾）
  - 未讀數聚合與顯示（含 Navbar badge）
  - Posted/My Works 改用真實資料（applications 與 acceptor_id）
  - 任務資訊 Bottom Sheet 最終版（行為與按鈕位置調整）
- **21**: 聊天室詳情頁面（HTTP 先行 + Socket 規劃）  
  - 建立 `chat/rooms/open_or_get.php`、`chat/messages/send.php`
  - /chat/detail 顯示 system message（application_resume）
  - 完成讀取歷史訊息與送出訊息（HTTP 版）
- **26**: 未讀訊息通知系統（MVP）
  - 後端提供未讀快照 API（依任務狀態過濾）
  - 前端整合全域未讀數與清除機制
- **27（部分）**: 資料庫遷移執行
  - 執行 `creator_id` 回填與 `creator_name` 刪除
  - 前端移除殘留 `creator_name` 寫入，全面使用 JOIN 的 `creator_name`
  - 確認 `status_id/status_code` 一致性，修正殘留 `status` 字串引用

## 📋 任務分類

### ✅ 已完成 (19個)
- 1-10: 核心功能完善
- 15-18: 基礎功能修復
- 19: 任務狀態設計文件

### 🔄 進行中 (0個)
- 無

### 📋 待執行 (46個)

#### 🗓️ Day 1 - 聊天室功能 (3個)
- 20: 聊天室列表優化（進度延後至 8/9 收尾）
- 21: Socket.IO 整合（8/9 先做 HTTP 版，Socket 列入規劃）
- 26: 未讀通知系統（8/9 納入 MVP 實作）

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