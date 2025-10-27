# Permission Level 設計說明

## Permission Level 數值設計

Permission Level 是一個整數值，用於控制用戶在系統中的權限和狀態。

### 數值範圍和含義

| 數值 | 類型 | 顯示名稱 | 顏色 | 描述 |
|------|------|---------|------|------|
| **≥ 99** | Admin (Super) | Super Admin | 🟣 Purple | 超級管理員，擁有最高權限 |
| **1-98** | Admin | Admin | 🔵 Blue | 管理員，擁有管理權限 |
| **0** | User (Verified) | User | 🟢 Green | 已驗證用戶，正常權限 |
| **-1** | Restricted | Restricted | 🟡 Yellow | 受限用戶，部分功能受限 |
| **-2** | Suspended | Suspended | 🟡 Yellow | 暫停帳號，暫時無法使用 |
| **-3** | Banned | Banned | 🔴 Red | 已封禁，無法使用系統 |
| **-4** | Deleted | Deleted | 🔴 Red | 已刪除帳號 |

### 設計邏輯

#### 正數（Admin 級別）
- **≥ 99**: 超級管理員，擁有所有權限
- **1-98**: 管理員，擁有部分管理權限

#### 0（正常用戶）
- **0**: 已驗證的正常用戶
- 初始註冊時為 0（未驗證）
- 通過學生證驗證後設為 1（已驗證）

#### 負數（受限級別）
- **-1**: 受限用戶（部分功能受限）
- **-2**: 暫停用戶（暫時禁用）
- **-3**: 封禁用戶（永久禁用）
- **-4**: 已刪除用戶（軟刪除）

### 前端顯示邏輯

#### getPermissionBadgeClass() 函數
```typescript
if (permission >= 99) return 'bg-purple-100 text-purple-800'      // Super Admin
if (permission >= 1) return 'bg-blue-100 text-blue-800'           // Admin
if (permission === 0) return 'bg-green-100 text-green-800'          // User
if (permission >= -1) return 'bg-yellow-100 text-yellow-800'      // Restricted/Suspended
if (permission >= -3) return 'bg-red-100 text-red-800'            // Banned/Deleted
```

#### getPermissionText() 函數
```typescript
if (permission >= 99) return 'Super Admin'
if (permission >= 1) return 'Admin'
if (permission === 0) return 'User'
if (permission === -1) return 'Restricted'
if (permission === -2) return 'Suspended'
if (permission === -3) return 'Banned'
if (permission === -4) return 'Deleted'
```

### 後端驗證

#### 允許的數值範圍
```php
'permission' => 'required|integer|in:-4,-3,-2,-1,0,1,99'
```

#### 特殊邏輯

1. **審核流程**：
   - 初始註冊：`permission = 0`（未驗證）
   - 審核通過：`permission = 1`（已驗證用戶）
   - 審核拒絕：`permission = -1`（受限用戶）

2. **檢查未驗證狀態**：
   ```php
   if (!$user || $user->permission !== 0) {
       return response()->json([
           'success' => false,
           'message' => 'User not found or not in unverified status'
       ], 400);
   }
   ```

### 使用場景

#### 1. 用戶註冊
- 初始 `permission = 0`
- 需要等待學生證審核

#### 2. 學生證審核
- **Approve**：`permission = 1`
- **Reject**：`permission = -1`

#### 3. 管理員操作
- 可以修改用戶權限級別
- 可以提升為管理員（`permission ≥ 1`）
- 可以限制用戶（`permission < 0`）

#### 4. 用戶狀態管理
- **正常使用**：`permission = 1`
- **受限**：`permission = -1`
- **暫停**：`permission = -2`
- **封禁**：`permission = -3`
- **刪除**：`permission = -4`

### 數據遷移示例

```sql
-- 將未驗證用戶設為受限
UPDATE users SET permission = -1 WHERE permission = 0 AND verification_status = 'rejected';

-- 將已驗證用戶設為正常用戶
UPDATE users SET permission = 1 WHERE permission = 0 AND verification_status = 'approved';

-- 將管理員設為超級管理員
UPDATE users SET permission = 99 WHERE permission >= 1 AND role = 'super_admin';
```

### API 使用示例

#### 更新用戶權限
```php
POST /api/admin/users/{id}/permission
{
    "permission": 1,
    "reason": "Student verification approved"
}
```

#### 審核學生證
```php
POST /api/admin/users/{id}/review
{
    "decision": "approve",
    "new_permission": 1,
    "notes": "Student verification documents are valid"
}
```

### 前端使用示例

#### 檢查用戶權限
```typescript
// 檢查是否為未驗證用戶
const isUnverified = user.permission === 0

// 檢查是否為已驗證用戶
const isVerified = user.permission >= 1

// 檢查是否為受限用戶
const isRestricted = user.permission < 0
```

#### 顯示審核按鈕
```vue
<!-- 僅當 permission = 0 時顯示審核按鈕 -->
<button 
  v-if="user.permission === 0" 
  @click="openReviewModal"
  class="admin-button-primary"
>
  Review Verification
</button>
```

### 安全考慮

1. **超級管理員**（≥ 99）擁有最高權限，謹慎授予
2. **管理員**（1-98）有管理權限，但受限於角色設定
3. **負數權限**（< 0）限制用戶功能，用於懲罰機制
4. **審核流程**必須經過管理員審核，不能自行提升權限

### 最佳實踐

1. **初始註冊**：設為 `0`（未驗證）
2. **審核通過**：設為 `1`（已驗證）
3. **審核拒絕**：設為 `-1`（受限）
4. **違規處理**：根據嚴重程度設為 `-2`、`-3` 或 `-4`
5. **管理員提升**：根據需要設為 `1-98` 或 `≥ 99`

## 總結

Permission Level 是一個簡單但強大的數值系統：
- **正數**（1-99）：管理員級別
- **0**：正常用戶
- **負數**（-1 到 -4）：受限級別

設計特點：
- 易於理解和維護
- 提供清晰的權限層級
- 支持靈活的狀態管理
- 前端和後端邏輯一致
