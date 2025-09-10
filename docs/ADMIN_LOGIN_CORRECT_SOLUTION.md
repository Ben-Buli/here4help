# 管理員後台登入正確解決方案

## 🎯 **問題根源發現**

### **架構誤解**
之前我錯誤地認為管理員帳號存儲在 `users` 資料表中（`permission >= 99`），但實際上：

- **`users` 資料表**: 存儲App用戶，`permission = 99` 只是最高權限用戶
- **`admins` 資料表**: 存儲管理員後台專用帳號
- **`admin_roles` 資料表**: 定義管理員角色權限

### **正確的資料表結構**

#### **admins 資料表**
```sql
CREATE TABLE admins (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role_id BIGINT UNSIGNED,
    status ENUM('active','reset','inactive','suspended') DEFAULT 'active',
    last_login TIMESTAMP NULL,
    login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

#### **admin_roles 資料表**
```sql
CREATE TABLE admin_roles (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    permissions JSON
);
```

## ✅ **修復實施**

### **1. 修復管理員登入API**

**檔案**: `backend/api/admin/login.php`

**主要修改**:
```php
// 修復前：查詢 users 資料表
$stmt = $db->prepare("
    SELECT id, name, email, password, permission, status, created_at, updated_at
    FROM users 
    WHERE email = ? AND permission >= 99 AND permission != -2 AND permission != -4
");

// 修復後：查詢 admins 資料表
$stmt = $db->prepare("
    SELECT a.id, a.username, a.full_name, a.email, a.password, a.role_id, a.status, 
           a.created_at, a.updated_at, ar.name as role_name
    FROM admins a
    LEFT JOIN admin_roles ar ON a.role_id = ar.id
    WHERE a.email = ? AND a.status = 'active'
");
```

### **2. 修復管理員資訊API**

**檔案**: `backend/api/admin/me.php`

**主要修改**:
```php
// 修復前：查詢 users 資料表
$stmt = $db->prepare("
    SELECT id, name, email, permission, status, created_at, updated_at
    FROM users 
    WHERE id = ? AND permission >= 99
");

// 修復後：查詢 admins 資料表
$stmt = $db->prepare("
    SELECT a.id, a.username, a.full_name, a.email, a.role_id, a.status, 
           a.created_at, a.updated_at, a.last_login, ar.name as role_name
    FROM admins a
    LEFT JOIN admin_roles ar ON a.role_id = ar.id
    WHERE a.id = ? AND a.status = 'active'
");
```

### **3. 更新JWT Token結構**

**修復前**:
```php
$tokenPayload = [
    'user_id' => $admin['id'],
    'admin_id' => $admin['id'],
    'email' => $admin['email'],
    'permission' => $admin['permission'],
    'type' => 'admin'
];
```

**修復後**:
```php
$tokenPayload = [
    'user_id' => $admin['id'],
    'admin_id' => $admin['id'],
    'email' => $admin['email'],
    'role_id' => $admin['role_id'],
    'role_name' => $admin['role_name'],
    'type' => 'admin'
];
```

## 🔐 **現有管理員帳號**

### **可用帳號列表**
```
ID  Username     Email                    Role ID  Status  Password
1   admin        admin@here4help.com      1        active  admin123
2   moderator    moderator@here4help.com  N/A      active  (未知)
3   developer    developer@here4help.com  N/A      active  (未知)
7   testadmin    test@here4help.com       2        active  (未知)
8   測試帳號      hero4help_admin@test.com 1        active  (未知)
```

### **管理員角色**
```
Role ID 1: super_admin
Role ID 2: admin  
Role ID 3: developer
Role ID 4: moderator
Role ID 5: support
```

## 🧪 **測試結果**

### **登入API測試**
```bash
curl -X POST http://localhost:8888/here4help/backend/api/admin/login.php \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@here4help.com","password":"admin123"}'
```

**成功回應**:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "admin": {
      "id": 1,
      "username": "admin",
      "full_name": "Admin Buli",
      "email": "admin@here4help.com",
      "role": {
        "id": 1,
        "name": "super_admin",
        "display_name": "Super_admin",
        "permissions": ["*"]
      },
      "status": "active",
      "role_id": 1
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "permissions": ["users.list", "users.view", "users.edit", ...]
  }
}
```

## 🚀 **前端登入測試**

### **正確的登入資訊**
- **Email**: `admin@here4help.com`
- **Password**: `admin123`
- **角色**: Super Admin (role_id: 1)

### **登入流程**
1. 啟動管理員後台: `cd admin/frontend && npm run dev`
2. 訪問: `http://localhost:5173`
3. 使用上述帳號登入
4. 檢查瀏覽器開發者工具確認API請求成功

## 🔧 **其他需要修復的API**

以下API也需要類似的修復（從 `users` 改為 `admins` 資料表）：

1. **`backend/api/admin/logout.php`** - 管理員登出
2. **其他管理員專用API** - 需要驗證管理員身份的端點

### **修復模式**
```php
// 統一的管理員驗證邏輯
function validateAdmin($adminId) {
    $db = Database::getInstance()->getConnection();
    $stmt = $db->prepare("
        SELECT a.id, a.username, a.email, a.role_id, ar.name as role_name
        FROM admins a
        LEFT JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.id = ? AND a.status = 'active'
    ");
    $stmt->execute([$adminId]);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}
```

## 📊 **架構對比**

| 項目 | 修復前 | 修復後 |
|------|--------|--------|
| **資料表** | `users` (錯誤) | `admins` (正確) |
| **權限檢查** | `permission >= 99` | `role_id + status = 'active'` |
| **角色系統** | 簡單數字權限 | 完整角色管理 |
| **專用性** | 混合App用戶 | 專用管理員帳號 |

## 🎯 **重要認知**

### **資料表分離的意義**
1. **`users`**: App用戶資料，包含一般用戶和高權限用戶
2. **`admins`**: 管理員後台專用帳號，完全獨立的認證系統
3. **安全性**: 管理員帳號與App用戶完全隔離，提升安全性

### **權限系統設計**
- **App用戶**: 使用 `permission` 數字等級 (0-99)
- **管理員**: 使用 `role_id` 對應 `admin_roles` 的角色系統

## 📋 **後續建議**

### **1. 統一管理員API**
建立統一的管理員驗證中間件，確保所有管理員API都使用正確的資料表。

### **2. 角色權限細化**
完善 `admin_roles` 資料表的權限系統，實現細粒度的權限控制。

### **3. 安全性增強**
- 實施登入失敗鎖定機制
- 添加雙因素認證
- 記錄管理員操作日誌

### **4. 文檔更新**
更新所有相關文檔，明確區分App用戶和管理員帳號的差異。

## 📚 **相關文檔**
- `ENVIRONMENT_CONFIG_GUIDE.md` - 環境配置指南
- `API_ARCHITECTURE_RECOMMENDATION.md` - API架構建議
