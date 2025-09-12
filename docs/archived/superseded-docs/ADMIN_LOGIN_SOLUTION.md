# 管理員後台登入問題解決方案

## 🔍 **問題診斷**

### **原始錯誤**
```json
{
    "success": false,
    "code": "Invalid credentials or insufficient permissions",
    "message": 401,
    "traceId": "68C1794A4B5199491688A",
    "timestamp": "2025-09-10T13:12:42+00:00",
    "server_time": 1757509962
}
```

### **問題原因**
1. **權限要求**: 後端要求用戶 `permission >= 99` 才能登入管理員後台
2. **密碼未知**: 現有管理員用戶的密碼都是加密的，無法直接使用
3. **測試帳號缺失**: 沒有可用的測試管理員帳號

## ✅ **解決方案**

### **1. 創建測試管理員帳號**

我們已經在資料庫中創建了一個測試管理員帳號：

```
Email: admin@here4help.com
Password: admin123
Permission: 99
Status: active
```

### **2. 驗證登入成功**

API測試結果：
```bash
curl -X POST http://localhost:8888/here4help/backend/api/admin/login.php \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@here4help.com","password":"admin123"}'
```

回應：
```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "Login successful",
  "data": {
    "admin": {
      "id": 1000,
      "username": "Test Admin",
      "email": "admin@here4help.com",
      "permission": 99
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "permissions": ["*"]
  }
}
```

## 🎯 **管理員後台登入資訊**

### **測試帳號**
- **Email**: `admin@here4help.com`
- **Password**: `admin123`
- **權限**: 管理員 (permission = 99)

### **現有管理員帳號**
資料庫中還有其他管理員帳號，但密碼未知：
- `linda@test.com` (permission: 99)
- `chris@test.com` (permission: 99)
- `admin@test.com` (permission: 99, status: pending_review)

## 🔧 **如何創建新的管理員帳號**

### **方法1: 直接資料庫操作**
```sql
INSERT INTO users (name, email, password, permission, status, created_at, updated_at)
VALUES (
    'New Admin',
    'newadmin@here4help.com',
    '$2y$12$...',  -- 使用 password_hash('your_password', PASSWORD_DEFAULT)
    99,
    'active',
    NOW(),
    NOW()
);
```

### **方法2: PHP腳本**
```php
<?php
require_once 'config/database.php';

$db = Database::getInstance()->getConnection();
$stmt = $db->prepare('
    INSERT INTO users (name, email, password, permission, status, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, NOW(), NOW())
');
$stmt->execute([
    'Admin Name',
    'admin@example.com',
    password_hash('your_password', PASSWORD_DEFAULT),
    99,
    'active'
]);
?>
```

## 🔐 **權限系統說明**

### **權限等級**
- **99+**: 管理員權限，可以登入管理員後台
- **1-98**: 一般用戶權限
- **0**: 訪客權限
- **負數**: 被封鎖或特殊狀態

### **狀態檢查**
後端會檢查以下條件：
1. `permission >= 99`
2. `permission != -2` (非封鎖狀態)
3. `permission != -4` (非特殊封鎖狀態)
4. `status != 'banned'`

## 🚀 **前端登入測試**

### **1. 啟動開發伺服器**
```bash
cd admin/frontend
npm run dev
```

### **2. 訪問登入頁面**
打開瀏覽器訪問：`http://localhost:5173` (或Vite顯示的端口)

### **3. 使用測試帳號登入**
- **Email**: `admin@here4help.com`
- **Password**: `admin123`

### **4. 檢查登入流程**
1. 打開瀏覽器開發者工具
2. 查看Network標籤
3. 確認API請求正確路由到 `/here4help/backend/api/admin/login.php`
4. 檢查回應狀態和JWT token

## 🔍 **故障排除**

### **常見問題**

#### **1. 401 Unauthorized**
- 檢查用戶權限是否 >= 99
- 確認密碼正確
- 檢查用戶狀態是否為 'active'

#### **2. 404 Not Found**
- 檢查Vite代理配置
- 確認後端服務器運行在 localhost:8888
- 驗證API檔案路徑

#### **3. CORS錯誤**
- 檢查後端CORS設定
- 確認 `Access-Control-Allow-Origin` 標頭

#### **4. 500 Internal Server Error**
- 檢查後端錯誤日誌
- 確認資料庫連線
- 驗證JWT配置

### **調試工具**
- 瀏覽器開發者工具 (Network, Console)
- Postman或curl進行API測試
- 後端錯誤日誌
- 資料庫查詢工具

## 📋 **安全建議**

### **生產環境**
1. **更改預設密碼**: 在生產環境中更改測試帳號密碼
2. **強密碼政策**: 實施強密碼要求
3. **雙因素認證**: 考慮添加2FA
4. **登入日誌**: 記錄所有登入嘗試
5. **會話管理**: 實施適當的會話超時

### **開發環境**
1. **測試帳號隔離**: 確保測試帳號不會影響生產數據
2. **權限最小化**: 只給予必要的權限
3. **定期清理**: 定期清理測試數據

## 📚 **相關文檔**
- `ENVIRONMENT_CONFIG_GUIDE.md` - 環境配置指南
- `API_ROUTING_FIX_PLAN.md` - API路由修復計劃
- `API_ARCHITECTURE_RECOMMENDATION.md` - API架構建議
