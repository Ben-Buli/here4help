# Here4Help – TODO Dashboard (Auto-generated Prototype)

> 本檔為快速總覽，供每日站立會 / 專案經理快速檢視。完整細節請見：
> • `CURSOR_TODO_OPTIMIZED.md`（開發用簡潔版）
> • `CURSOR_TODO.md`（完整紀錄）

---

## 📊 專案概況

| 指標 | 數值 |
|------|------|
| 完成度 | **46.2 %** (30 / 65) |
| 目前版本 | **v3.3.2** |
| 下一版 | **v3.3.3** – Chat 資料修復 / 圖片預覽優化 |
| 目標 | 8/17 前達成 100 % 完成度 |

---

## 🎯 今日焦點任務（2025-08-12）

| # | 類別 | 任務 | 狀態 | 版本 | 截止 |
|---|------|------|------|------|------|
| 1 | Chat | 未讀徽章整合 | ⏳ 進行中 | 3.3.3 | 8/13 |
| 2 | Payment | Pay / Confirm 點數轉移 | 🟡 待辦 | 3.3.3 | 8/13 |
| 3 | Permission | RBAC Middleware | 🟡 待辦 | 3.3.4 | 8/14 |
| 4 | API | Report 圖片上傳 | 🟡 待辦 | 3.3.4 | 8/14 |
| 5 | Deployment | cPanel 腳本自動化 | 🟡 待辦 | 3.3.6 | 8/15 |

> 狀態 Icon：✅ 已完成 ⏳ 進行中 🟡 待辦 ❗ 阻塞

---

## 🔄 版本里程碑

| 版本 | 目標日期 | 主要內容 | 完成度 |
|-------|----------|----------|--------|
| v3.3.2 | 8/12 | Chat API 修復 / 頭像與圖片優化 | ✅ |
| v3.3.3 | 8/13 | 未讀徽章 + Chat Data Clean | ⏳ 46 % |
| v3.3.4 | 8/14 | Permission + Review Flow | 🟡 10 % |
| v3.3.5 | 8/15 | Wallet / Payment 完成 | 🟡 0 % |
| v3.3.6 | 8/15 | cPanel 部署腳本 | 🟡 0 % |
| v3.3.7 | 8/17 | TestFlight 上架 & End-to-End QA | 🟡 0 % |

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