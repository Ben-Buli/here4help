# Flutter 網頁版聊天系統測試指南

## 前置準備

### 1. 確保服務正在運行

在開始測試前，請確保以下服務都已啟動：

```bash
# 1. 檢查 Socket.IO 服務 (端口 3001)
lsof -i :3001

# 2. 檢查 PHP 服務 (端口 8888)
lsof -i :8888

# 3. 檢查資料庫連線
cd backend/database && php test_connection.php
```

### 2. 啟動 Flutter 網頁版

```bash
# 在專案根目錄執行
flutter run -d chrome --web-port=8080
```

## 測試步驟

### 步驟 1: 登入測試

1. **開啟瀏覽器**
   - 訪問 `http://localhost:8080`
   - 確認 Flutter 應用正常載入

2. **登入流程**
   - 點擊「登入」按鈕
   - 使用測試帳號登入（或註冊新帳號）
   - 確認登入成功，進入主頁面

3. **檢查授權狀態**
   - 打開瀏覽器開發者工具 (F12)
   - 查看 Console 是否有錯誤訊息
   - 確認 token 已正確儲存

### 步驟 2: 聊天列表測試

1. **進入聊天頁面**
   - 點擊底部導航的「聊天」選項
   - 確認進入聊天列表頁面

2. **檢查聊天室載入**
   - 觀察是否顯示現有的聊天室
   - 檢查每個聊天室是否顯示：
     - 任務標題
     - 最後訊息
     - 未讀訊息數量
     - 參與者資訊

3. **API 測試**
   - 打開開發者工具的 Network 標籤
   - 重新整理頁面
   - 查看是否有對 `get_rooms.php` 的 API 呼叫
   - 確認 API 回應狀態為 200

### 步驟 3: 聊天詳情測試

1. **進入聊天室**
   - 點擊任一聊天室
   - 確認進入聊天詳情頁面

2. **檢查訊息載入**
   - 觀察是否顯示歷史訊息
   - 確認訊息格式正確：
     - 發送者名稱
     - 訊息內容
     - 發送時間

3. **發送訊息測試**
   - 在輸入框輸入測試訊息
   - 點擊發送按鈕
   - 確認訊息立即顯示在聊天中
   - 檢查 Network 標籤中的 API 呼叫

### 步驟 4: 即時通訊測試

1. **Socket 連線測試**
   - 打開開發者工具 Console
   - 查看是否有 Socket.IO 連線訊息
   - 確認連線狀態為 "connected"

2. **即時訊息測試**
   - 開啟兩個瀏覽器視窗
   - 使用不同帳號登入
   - 在一個視窗發送訊息
   - 確認另一個視窗即時收到訊息

3. **未讀訊息測試**
   - 在一個視窗發送訊息
   - 在另一個視窗不點擊聊天室
   - 確認聊天列表顯示未讀數量
   - 點擊聊天室後，確認未讀數量歸零

## 故障排除

### 常見問題

1. **CORS 錯誤**
   ```
   Access to XMLHttpRequest at 'http://localhost:8888/here4help/backend/api/chat/get_rooms.php' 
   from origin 'http://localhost:8080' has been blocked by CORS policy
   ```
   
   **解決方案：**
   - 確認 PHP 服務已設定 CORS headers
   - 檢查 `backend/api/chat/` 目錄下的 PHP 檔案是否包含：
     ```php
     header('Access-Control-Allow-Origin: *');
     header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
     header('Access-Control-Allow-Headers: Content-Type, Authorization');
     ```

2. **Socket.IO 連線失敗**
   ```
   WebSocket connection to 'ws://localhost:3001/socket.io/' failed
   ```
   
   **解決方案：**
   - 確認 Socket.IO 服務正在運行
   - 檢查防火牆設定
   - 確認端口 3001 未被佔用

3. **API 認證錯誤**
   ```
   {"success":false,"message":"Server error: Authorization header required"}
   ```
   
   **解決方案：**
   - 確認已正確登入
   - 檢查 token 是否正確儲存
   - 確認 API 呼叫包含 Authorization header

4. **Flutter 網頁載入問題**
   ```
   Failed to load resource: the server responded with a status of 404
   ```
   
   **解決方案：**
   - 確認 Flutter 網頁服務正在運行
   - 檢查端口 8080 是否可用
   - 嘗試使用不同端口：`flutter run -d chrome --web-port=8081`

### 調試技巧

1. **查看 API 呼叫**
   - 打開開發者工具 Network 標籤
   - 篩選 XHR 請求
   - 檢查請求和回應內容

2. **查看 Socket.IO 連線**
   - 在 Console 中輸入：`socket.connected`
   - 查看 Socket.IO 事件日誌

3. **檢查 Flutter 狀態**
   - 使用 Flutter Inspector
   - 查看 Widget 樹結構
   - 檢查狀態管理

## 測試檢查清單

- [ ] Flutter 網頁應用正常載入
- [ ] 登入功能正常
- [ ] 聊天列表頁面載入
- [ ] 聊天室列表顯示正確
- [ ] 進入聊天詳情頁面
- [ ] 歷史訊息載入
- [ ] 發送訊息功能
- [ ] Socket.IO 即時連線
- [ ] 即時訊息接收
- [ ] 未讀訊息計數
- [ ] 跨瀏覽器即時通訊
- [ ] 錯誤處理機制

## 性能測試

1. **載入速度**
   - 測量聊天列表載入時間
   - 測量聊天詳情載入時間
   - 測量訊息發送響應時間

2. **記憶體使用**
   - 監控瀏覽器記憶體使用
   - 長時間使用後檢查記憶體洩漏

3. **網路使用**
   - 監控 API 呼叫頻率
   - 檢查 WebSocket 連線穩定性

## 瀏覽器相容性測試

測試以下瀏覽器：
- [ ] Chrome (推薦)
- [ ] Firefox
- [ ] Safari
- [ ] Edge

## 完成測試

當所有測試項目都通過後，聊天系統就可以正常使用了！

如果遇到問題，請參考故障排除部分或聯繫開發團隊。 