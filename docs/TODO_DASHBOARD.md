# Here4Help – TODO Dashboard (Auto-generated Prototype)

> 本檔為快速總覽，供每日站立會 / 專案經理快速檢視。完整細節請見：
> • `CURSOR_TODO_OPTIMIZED.md`（開發用簡潔版）
> • `CURSOR_TODO.md`（完整紀錄）

---

## 📊 專案概況

| 指標 | 數值 |
|------|------|
| 完成度 | **52.3 %** (34 / 65) |
| 目前版本 | **v3.3.3** |
| 下一版 | **v3.3.4** – Permission + Review Flow |
| 目標 | 8/17 前達成 100 % 完成度 |

---

## 🎯 今日焦點任務（2025-08-14）

| # | 類別 | 任務 | 狀態 | 版本 | 截止 |
|---|------|------|------|------|------|
| 1 | Auth | Token 格式檢測邏輯修復 | ✅ 已完成 | 3.3.3 | 8/14 |
| 2 | API | Authorization header 傳遞問題 | ✅ 已完成 | 3.3.3 | 8/14 |
| 3 | Chat | My Works 分頁數據顯示修復 | ✅ 已完成 | 3.3.3 | 8/14 |
| 4 | Chat | 未讀徽章整合 | ⏳ 進行中 | 3.3.3 | 8/15 |
| 5 | Payment | Pay / Confirm 點數轉移 | 🟡 待辦 | 3.3.4 | 8/15 |

> 狀態 Icon：✅ 已完成 ⏳ 進行中 🟡 待辦 ❗ 阻塞

---

## 🔄 版本里程碑

| 版本 | 目標日期 | 主要內容 | 完成度 |
|-------|----------|----------|--------|
| v3.3.2 | 8/12 | Chat API 修復 / 頭像與圖片優化 | ✅ |
| v3.3.3 | 8/14 | Token 修復 + Auth Header + My Works 數據 | ⏳ 85 % |
| v3.3.4 | 8/15 | Permission + Review Flow | 🟡 10 % |
| v3.3.5 | 8/16 | Wallet / Payment 完成 | 🟡 0 % |
| v3.3.6 | 8/16 | cPanel 部署腳本 | 🟡 0 % |
| v3.3.7 | 8/17 | TestFlight 上架 & End-to-End QA | 🟡 0 % |

---

## 📝 今日完成項目（2025-08-14）

### ✅ Token 格式檢測邏輯修復
- **問題**：前端誤判 base64 編碼的 token 為 JWT 格式
- **原因**：base64 編碼後的字符串恰好以 `eyJ` 開頭
- **解決**：修改前端檢測邏輯，增加 JWT 結構驗證（檢查是否有三個用 `.` 分隔的部分）

### ✅ Authorization header 傳遞問題
- **問題**：MAMP 環境下 PHP 無法讀取 Authorization header
- **原因**：Apache 配置問題，Authorization header 無法傳遞給 PHP
- **解決**：創建 `.htaccess` 文件，使用 `SetEnvIf` 指令傳遞 header

### ✅ My Works 分頁數據顯示修復
- **問題**：資料庫有 7 筆應徵記錄，但前端只顯示 2 則任務
- **原因**：`_composeMyWorks` 方法依賴複雜的數據匹配邏輯
- **解決**：簡化邏輯，直接使用 API 返回的應徵數據，轉換為任務格式

---

## 📝 更新流程

1. 編輯 / 變更 `CURSOR_TODO.md` 後，手動更新此檔或執行待實作的自動化腳本。
2. 推送版本：
   ```bash
   git add docs/TODO_DASHBOARD.md docs/CURSOR_TODO*.md docs/TODO_INDEX.md
   git commit -m "docs: update TODO dashboard"
   git push origin <branch>
   ```

---

> 💡 **下一步**：可撰寫簡易 Dart / Node 腳本，解析 `CURSOR_TODO.md` Checkbox 狀態，自動覆寫本檔並更新完成度百分比。