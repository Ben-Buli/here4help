# Permission 顯示名稱統一計劃

## 📋 顯示名稱格式建議

### 當前狀態

| 數值 | 實際含義 | 當前顯示名稱 | 問題 |
|------|---------|-------------|------|
| **-1** | Admin Suspended | Restricted | 不明確是管理員操作 |
| **-2** | Admin Soft Deleted | Suspended | 不明確是管理員操作，且與 -3 混淆 |
| **-3** | Self Suspended | Banned | 不明確是用戶自行操作 |
| **-4** | Self Soft Deleted | Deleted | 不明確是用戶自行操作 |

### 建議的統一顯示名稱格式

**方案 1：完整格式（推薦）**
- 明確標示操作者和操作類型，與「實際含義」完全一致

| 數值 | 實際含義 | **建議顯示名稱** | 說明 |
|------|---------|----------------|------|
| **99** | Super Admin | Super Admin / Master User | 保持不變 |
| **1** | Verified User | Verified User | 保持不變 |
| **0** | Unverified User | New User in Verification | 保持不變 |
| **-1** | Admin Suspended | **Admin Suspended** | 明確標示管理員停權 |
| **-2** | Admin Soft Deleted | **Admin Soft Deleted** | 明確標示管理員軟刪除 |
| **-3** | Self Suspended | **Self Suspended** | 明確標示用戶自行停權 |
| **-4** | Self Soft Deleted | **Self Soft Deleted** | 明確標示用戶自行軟刪除 |

**優點：**
- ✅ 與「實際含義」完全一致，減少混淆
- ✅ 清晰區分操作者（Admin/Self）和操作類型（Suspended/Soft Deleted）
- ✅ 便於管理員和用戶理解狀態來源

**方案 2：簡化格式（可選）**
- 如果覺得完整格式太長，可以使用簡化版本

| 數值 | 建議顯示名稱（簡化） |
|------|-------------------|
| **-1** | Admin Restricted |
| **-2** | Admin Deleted |
| **-3** | Self Restricted |
| **-4** | Self Deleted |

---

## 📊 需要修改的項目統計

### Vue Admin (`admin/frontend/src/`)

#### 1. **UserEditModal.vue** - 3 處
- **位置**：第 68-74 行
- **類型**：`<option>` 標籤文字
- **需要修改**：
  - `Regular User (0)` → `New User in Verification (0)`
  - `Restricted (-1)` → `Admin Suspended (-1)`
  - `Suspended (-2)` → `Admin Soft Deleted (-2)`
  - `Banned (-3)` → `Self Suspended (-3)`
  - `Deleted (-4)` → `Self Soft Deleted (-4)`

#### 2. **UsersView.vue** - 3 處
- **位置 1**：第 60-65 行（篩選選項註釋）
- **類型**：HTML 註釋
- **需要修改**：
  - `//  被管理員停權` → `//  管理員停權`
  - `//  被管理員軟刪除` → `//  管理員軟刪除`
  - `//  用戶自行停權` → `//  用戶自行停權`
  - `//  用戶自行軟刪除` → `//  用戶自行軟刪除`

- **位置 2**：第 62-65 行（篩選選項文字）
- **類型**：`<option>` 標籤文字
- **需要修改**：同 UserEditModal.vue

- **位置 3**：第 752-760 行（`getPermissionText` 函數）
- **類型**：函數返回值
- **需要修改**：
  - `'Restricted'` → `'Admin Suspended'`
  - `'Suspended'` → `'Admin Soft Deleted'`
  - `'Banned'` → `'Self Suspended'`
  - `'Deleted'` → `'Self Soft Deleted'`

#### 3. **UserDetailView.vue** - 1 處
- **位置**：第 585-594 行（`getPermissionText` 函數）
- **類型**：函數返回值
- **需要修改**：同 UsersView.vue 位置 3

#### 4. **ReferralCodesView.vue** - 1 處
- **位置**：第 263-271 行（`getPermissionText` 函數）
- **類型**：函數返回值
- **需要修改**：
  - `'New User'` → `'New User in Verification'`（統一格式）
  - `'Restricted'` → `'Admin Suspended'`
  - `'Suspended'` → `'Admin Soft Deleted'`
  - `'Banned'` → `'Self Suspended'`
  - `'Deleted'` → `'Self Soft Deleted'`

**Vue Admin 小計：8 處需要修改**

---

### Flutter App (`lib/`)

#### 1. **permission_unvertified_page.dart** - 3 處
- **位置 1**：第 125-154 行（`_buildRestrictedContent` 函數）
- **類型**：硬編碼訊息文字
- **需要修改**：
  - `'Your account has been limited by an administrator...'` → 更新為使用「Admin Suspended」語義

- **位置 2**：第 156-185 行（`_buildSelfDeactivatedContent` 函數）
- **類型**：硬編碼訊息文字
- **需要修改**：
  - `'You have temporarily deactivated your account...'` → 更新為使用「Admin Soft Deleted」語義
  - ⚠️ **注意**：此函數名稱 `_buildSelfDeactivatedContent` 對應 `permission = -2`（Admin Soft Deleted），但名稱暗示是「Self」，需要確認邏輯是否正確

- **位置 3**：第 187-216 行（`_buildSelfSuspendedContent` 函數）
- **類型**：硬編碼訊息文字
- **需要修改**：
  - `'You have temporarily suspended your account...'` → 更新為使用「Self Suspended」語義

#### 2. **login_page.dart** - 2 處
- **位置**：第 180-205 行（錯誤訊息處理）
- **類型**：硬編碼錯誤訊息
- **需要修改**：
  - `'This account has been removed by an administrator...'` → 更新為使用「Admin Soft Deleted」語義
  - `'This account has been deleted and cannot be used...'` → 更新為使用「Self Soft Deleted」語義

#### 3. **profile_page.dart** - 1 處
- **位置**：第 687-690 行（推薦碼顯示邏輯）
- **類型**：硬編碼提示文字
- **需要修改**：
  - `'Pending verification - code will be generated after approval'` → 可選：統一為「New User in Verification」語義

#### 4. **security_page.dart** - 1 處
- **位置**：第 702 行（標題文字）
- **類型**：硬編碼標題
- **需要修改**：
  - `'Account Suspended by Administrator'` → 可選：更新為「Admin Suspended」語義

#### 5. **其他潛在文件** - 約 3-5 處
- `lib/router/guards/permission_guard.dart`：日誌訊息（不影響用戶界面）
- `lib/providers/permission_provider.dart`：註釋和文檔
- `lib/services/permission_service.dart`：註釋和文檔

**Flutter App 小計：7-10 處需要修改（用戶可見）**

---

### Backend (`admin/app/` 和 `backend/api/`)

#### 1. **註釋和文檔** - 約 2-3 處
- `admin/app/Http/Controllers/Admin/UserController.php`：註釋
- `backend/api/auth/login.php`：註釋
- 其他 PHP 文件中的註釋

**Backend 小計：2-3 處（主要是註釋）**

---

## 📈 總計統計

| 項目類別 | 需要修改的項目數量 | 優先級 |
|---------|-----------------|--------|
| **Vue Admin** | **8 處** | 🔴 高（用戶可見） |
| **Flutter App** | **7-10 處** | 🔴 高（用戶可見） |
| **Backend** | **2-3 處** | 🟡 中（主要是註釋） |
| **總計** | **17-21 處** | - |

---

## 🎯 實施建議

### 階段 1：創建統一的顯示名稱映射（推薦）

**Vue Admin：**
創建 `admin/frontend/src/utils/permissionLabels.ts`：
```typescript
export const PERMISSION_LABELS = {
  99: 'Super Admin / Master User',
  1: 'Verified User',
  0: 'New User in Verification',
  '-1': 'Admin Suspended',
  '-2': 'Admin Soft Deleted',
  '-3': 'Self Suspended',
  '-4': 'Self Soft Deleted',
} as const

export function getPermissionLabel(permission: number | null): string {
  if (permission === null || permission === undefined) return 'Unknown'
  if (permission >= 99) return PERMISSION_LABELS[99]
  if (permission >= 1) return PERMISSION_LABELS[1]
  if (permission === 0) return PERMISSION_LABELS[0]
  return PERMISSION_LABELS[String(permission) as keyof typeof PERMISSION_LABELS] || `Level ${permission}`
}
```

**Flutter App：**
創建 `lib/utils/permission_labels.dart`：
```dart
class PermissionLabels {
  static const Map<int, String> labels = {
    99: 'Super Admin / Master User',
    1: 'Verified User',
    0: 'New User in Verification',
    -1: 'Admin Suspended',
    -2: 'Admin Soft Deleted',
    -3: 'Self Suspended',
    -4: 'Self Soft Deleted',
  };

  static String getLabel(int? permission) {
    if (permission == null) return 'Unknown';
    if (permission >= 99) return labels[99]!;
    if (permission >= 1) return labels[1]!;
    if (permission == 0) return labels[0]!;
    return labels[permission] ?? 'Level $permission';
  }
}
```

### 階段 2：逐步替換現有代碼

1. **Vue Admin**：
   - 替換所有 `getPermissionText` 函數為統一的 `getPermissionLabel`
   - 更新所有 `<option>` 標籤文字
   - 更新註釋

2. **Flutter App**：
   - 替換硬編碼的錯誤訊息和提示文字
   - 使用統一的 `PermissionLabels.getLabel()` 方法

3. **Backend**：
   - 更新註釋和文檔

---

## ⚠️ 注意事項

1. **`permission_unvertified_page.dart` 中的函數命名問題**：
   - `_buildSelfDeactivatedContent()` 對應 `permission = -2`（Admin Soft Deleted）
   - 但函數名稱暗示是「Self」，需要確認邏輯是否正確

2. **向後兼容性**：
   - 如果後端 API 返回的權限文字被前端直接使用，需要確保後端也同步更新

3. **測試重點**：
   - 確保所有顯示 permission 的地方都正確更新
   - 確保錯誤訊息和提示文字的一致性
   - 確保管理員操作記錄中的文字也正確顯示

---

## ✅ 建議採用的統一顯示名稱

**最終建議：採用方案 1（完整格式）**

| 數值 | 顯示名稱 |
|------|---------|
| **-1** | Admin Suspended |
| **-2** | Admin Soft Deleted |
| **-3** | Self Suspended |
| **-4** | Self Soft Deleted |

這樣可以：
- 與「實際含義」完全一致
- 清晰區分操作者和操作類型
- 便於管理和維護

