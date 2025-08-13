# Flutter 應用測試聊天系統指南

## 📋 測試前準備

### 1. 啟動後端服務

#### 啟動 Socket.IO 服務
```bash
cd backend/socket
npm install
npm start
```

#### 確認 API 服務運行
確保您的 PHP 後端服務正在運行，並且資料庫連線正常。

### 2. 檢查資料庫狀態
```bash
cd backend/database
php quick_validate.php
```

### 3. 確認配置
檢查 `lib/config/app_config.dart` 中的 API 基礎 URL 是否正確：
```dart
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:8888/here4help/backend/api';
  // 其他配置...
}
```

## 🧪 測試步驟

### 步驟 1: 基本連線測試

#### 1.1 測試資料庫連線
```bash
cd backend/database
php test_connection.php
```

預期輸出：
```
=== 資料庫連線測試 ===
✅ 資料庫連線成功！
📊 資料庫名稱: hero4helpdemofhs_hero4help
📋 表格數量: 6
🎉 所有測試通過！資料庫配置正確。
```

#### 1.2 測試 Socket.IO 服務
```bash
curl http://localhost:3001/health
```

預期輸出：
```json
{
  "ok": true,
  "database": "connected",
  "timestamp": "2025-01-10T..."
}
```

### 步驟 2: API 端點測試

#### 2.1 測試獲取聊天房間
```bash
# 首先獲取用戶 Token（需要先登入）
curl -X GET "http://localhost:8888/here4help/backend/api/chat/get_rooms.php" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

#### 2.2 測試發送訊息
```bash
curl -X POST "http://localhost:8888/here4help/backend/api/chat/send_message.php" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "room_id": "test_room_1",
    "message": "Hello, this is a test message!",
    "task_id": "1"
  }'
```

### 步驟 3: Flutter 應用測試

#### 3.1 啟動 Flutter 應用
```bash
cd /path/to/your/flutter/app
flutter run
```

#### 3.2 登入測試
1. 在應用中登入一個測試帳戶
2. 確認 Token 已正確保存
3. 檢查用戶資訊是否載入

#### 3.3 測試聊天列表頁面
1. 導航到聊天列表頁面
2. 檢查是否顯示聊天房間列表
3. 確認未讀訊息計數是否正確
4. 測試搜尋和篩選功能

#### 3.4 測試聊天詳情頁面
1. 點擊一個聊天房間進入詳情頁面
2. 檢查訊息歷史是否載入
3. 測試發送新訊息
4. 確認即時接收訊息

## 🔍 測試檢查清單

### 基本功能測試
- [ ] 用戶登入和 Token 管理
- [ ] 聊天房間列表載入
- [ ] 訊息歷史載入
- [ ] 發送訊息功能
- [ ] 即時訊息接收
- [ ] 未讀訊息計數
- [ ] 已讀狀態同步

### 錯誤處理測試
- [ ] 網路連線中斷處理
- [ ] 無效 Token 處理
- [ ] 資料庫連線錯誤處理
- [ ] Socket 連線失敗處理
- [ ] 訊息發送失敗處理

### 效能測試
- [ ] 大量訊息載入效能
- [ ] 同時多個聊天室
- [ ] 長時間連線穩定性
- [ ] 記憶體使用情況

## 🐛 常見問題和解決方案

### 問題 1: Socket.IO 連線失敗
**症狀**: 應用顯示"聊天室連線失敗"
**解決方案**:
```bash
# 檢查 Socket 服務是否運行
ps aux | grep node

# 檢查端口是否被佔用
lsof -i :3001

# 重啟 Socket 服務
cd backend/socket
npm start
```

### 問題 2: API 端點返回 404
**症狀**: API 請求返回 404 錯誤
**解決方案**:
```bash
# 檢查 PHP 服務是否運行
ps aux | grep php

# 檢查 Apache/Nginx 配置
# 確認 URL 路徑正確
```

### 問題 3: 資料庫連線失敗
**症狀**: 資料庫相關錯誤
**解決方案**:
```bash
# 檢查 MySQL 服務
brew services list | grep mysql

# 檢查資料庫配置
cat backend/config/database.php

# 測試資料庫連線
cd backend/database
php test_connection.php
```

### 問題 4: 訊息不即時更新
**症狀**: 發送訊息後對方沒有即時收到
**解決方案**:
1. 檢查 Socket.IO 服務狀態
2. 確認房間 ID 正確
3. 檢查用戶權限
4. 查看瀏覽器控制台錯誤

## 📊 測試資料準備

### 創建測試用戶
```sql
INSERT INTO users (username, email, password, created_at) VALUES 
('testuser1', 'test1@example.com', 'hashed_password', NOW()),
('testuser2', 'test2@example.com', 'hashed_password', NOW());
```

### 創建測試任務
```sql
INSERT INTO tasks (title, description, creator_id, status_id, created_at) VALUES 
('測試任務 1', '這是一個測試任務', 1, 1, NOW()),
('測試任務 2', '這是另一個測試任務', 2, 1, NOW());
```

### 創建測試聊天房間
```sql
INSERT INTO chat_rooms (id, task_id, creator_id, participant_id, created_at) VALUES 
('test_room_1', 1, 1, 2, NOW()),
('test_room_2', 2, 2, 1, NOW());
```

## 🔧 調試工具

### 1. 瀏覽器開發者工具
- 檢查網路請求
- 查看 WebSocket 連線狀態
- 監控 Console 錯誤

### 2. Flutter 調試工具
```bash
# 查看詳細日誌
flutter run --verbose

# 檢查網路請求
flutter run --debug
```

### 3. 資料庫監控
```sql
-- 查看聊天訊息
SELECT * FROM chat_messages ORDER BY created_at DESC LIMIT 10;

-- 查看聊天房間
SELECT * FROM chat_rooms;

-- 查看已讀狀態
SELECT * FROM chat_reads;
```

## 📱 移動端測試

### iOS 模擬器測試
```bash
flutter run -d ios
```

### Android 模擬器測試
```bash
flutter run -d android
```

### 實體設備測試
```bash
# 列出可用設備
flutter devices

# 在特定設備上運行
flutter run -d DEVICE_ID
```

## 🎯 測試驗收標準

### 功能完整性
- ✅ 所有聊天功能正常工作
- ✅ 即時通訊穩定可靠
- ✅ 錯誤處理完善
- ✅ 用戶體驗流暢

### 效能要求
- ✅ 訊息發送延遲 < 500ms
- ✅ 頁面載入時間 < 2s
- ✅ 記憶體使用穩定
- ✅ 電池消耗合理

### 安全性
- ✅ 身份驗證有效
- ✅ 權限檢查正確
- ✅ 資料傳輸安全
- ✅ 無敏感資訊洩露

---

**測試完成後，聊天系統就可以正式投入使用！** 🎉

如有任何問題，請參考故障排除部分或聯繫開發團隊。 