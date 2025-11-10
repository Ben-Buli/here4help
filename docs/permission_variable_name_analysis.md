# Permission 顯示名稱修正 - 變數/常數名稱影響分析

## 🔍 檢查結果

**結論：大部分變數/常數名稱不需要修改，但有一些函數名稱可能需要優化以保持一致性。**

---

## ✅ 不需要修改的常數/變數

### 1. **Flutter App 常數定義** (`lib/services/permission_service.dart`)

這些常數名稱已經與建議的顯示名稱一致，**不需要修改**：

```dart
static const int SUSPENDED_BY_ADMIN = -1;        // ✅ 對應 "Admin Suspended"
static const int SOFT_DELETED_BY_ADMIN = -2;      // ✅ 對應 "Admin Soft Deleted"
static const int SELF_SUSPENDED = -3;             // ✅ 對應 "Self Suspended"
static const int SELF_SOFT_DELETED = -4;          // ✅ 對應 "Self Soft Deleted"
```

**原因：**
- 常數名稱已經清楚表達了操作者（Admin/Self）和操作類型（Suspended/Soft Deleted）
- 這些常數用於邏輯判斷，不影響顯示文字
- 修改常數名稱會影響所有使用這些常數的代碼

---

### 2. **錯誤代碼常數** (`backend/utils/ErrorCodes.php`)

這些是錯誤代碼常數，**不需要修改**：

```php
const ACCOUNT_SUSPENDED = 'E2008';  // ✅ 錯誤代碼，不是 permission 值
const ACCOUNT_DELETED = 'E2009';    // ✅ 錯誤代碼，不是 permission 值
```

**原因：**
- 這些是 API 錯誤代碼，不是 permission 值
- 它們用於錯誤處理，與 permission 顯示名稱無關

---

### 3. **函數名稱（邏輯判斷）**

這些函數名稱用於邏輯判斷，**不需要修改**：

```dart
// lib/services/permission_service.dart
static bool isAccountSuspended(int permission) { ... }  // ✅ 邏輯判斷函數
static bool isAccountDeleted(int permission) { ... }    // ✅ 邏輯判斷函數

// lib/providers/permission_provider.dart
bool isAccountSuspended() { ... }  // ✅ 邏輯判斷函數
bool isAccountDeleted() { ... }    // ✅ 邏輯判斷函數
```

**原因：**
- 這些函數用於邏輯判斷，不影響顯示文字
- 函數名稱清楚表達功能，修改會影響所有調用處

---

## ⚠️ 可能需要優化的函數名稱

### 1. **UI 構建函數** (`lib/system/pages/permission_unvertified_page.dart`)

這些函數名稱與實際的 permission 值對應關係可能需要優化：

| 當前函數名稱 | 對應 Permission | 建議顯示名稱 | 是否需要修改 |
|------------|----------------|------------|------------|
| `_buildRestrictedContent()` | `-1` | Admin Suspended | ⚠️ **建議修改** |
| `_buildSelfDeactivatedContent()` | `-2` | Admin Soft Deleted | ⚠️ **建議修改** |
| `_buildSelfSuspendedContent()` | `-3` | Self Suspended | ✅ 名稱正確 |

**問題分析：**

1. **`_buildRestrictedContent()`** (對應 `-1`):
   - 當前名稱：`Restricted`（受限）
   - 實際含義：`Admin Suspended`（管理員停權）
   - **建議修改為**：`_buildAdminSuspendedContent()`

2. **`_buildSelfDeactivatedContent()`** (對應 `-2`):
   - 當前名稱：`SelfDeactivated`（自行停用）
   - 實際含義：`Admin Soft Deleted`（管理員軟刪除）
   - **建議修改為**：`_buildAdminSoftDeletedContent()`

**注意：**
- 這些函數名稱只影響代碼可讀性，不影響功能
- 修改這些函數名稱需要同時更新所有調用處
- 如果修改，需要更新 `_buildContentByPermission()` 中的調用

---

## 📋 需要更新的返回文字

### 1. **`getPermissionStatus()` 函數** (`lib/services/permission_service.dart`)

這個函數返回的描述文字可能需要更新以匹配新的顯示名稱：

```dart
static String getPermissionStatus(int permission) {
  switch (permission) {
    case SUSPENDED_BY_ADMIN:
      return 'Account suspended by administrator';  // ⚠️ 可能需要更新
    case SOFT_DELETED_BY_ADMIN:
      return 'Account removed by administrator';  // ⚠️ 可能需要更新
    case SELF_SUSPENDED:
      return 'Account self-suspended';            // ✅ 已正確
    case SELF_SOFT_DELETED:
      return 'Account self-removed';              // ⚠️ 可能需要更新
    // ...
  }
}
```

**建議更新：**
- `'Account suspended by administrator'` → `'Account suspended by administrator'`（保持不變，或改為 `'Admin Suspended'`）
- `'Account removed by administrator'` → `'Admin Soft Deleted'`（更明確）
- `'Account self-removed'` → `'Self Soft Deleted'`（更明確）

---

## 🎯 修改建議總結

### **高優先級（建議修改）**

1. **函數名稱優化**（可選，提升代碼可讀性）：
   - `_buildRestrictedContent()` → `_buildAdminSuspendedContent()`
   - `_buildSelfDeactivatedContent()` → `_buildAdminSoftDeletedContent()`

2. **返回文字更新**（可選，提升一致性）：
   - `getPermissionStatus()` 函數中的描述文字

### **低優先級（不需要修改）**

1. ✅ 常數名稱（`SUSPENDED_BY_ADMIN` 等）- 已經正確
2. ✅ 錯誤代碼常數（`ACCOUNT_SUSPENDED` 等）- 與 permission 無關
3. ✅ 邏輯判斷函數名稱（`isAccountSuspended()` 等）- 功能正確

---

## ⚠️ 重要提醒

### **函數名稱修改的影響**

如果決定修改函數名稱，需要：

1. **更新所有調用處**：
   ```dart
   // permission_unvertified_page.dart
   case -1:
     return _buildAdminSuspendedContent();  // 更新調用
   case -2:
     return _buildAdminSoftDeletedContent();  // 更新調用
   ```

2. **確保沒有其他地方引用這些函數**：
   - 這些是私有函數（`_` 開頭），通常只在同一個文件中使用
   - 但仍需要檢查是否有其他地方引用

3. **測試所有相關功能**：
   - 確保修改後的功能正常運作
   - 確保 UI 顯示正確

---

## ✅ 最終建議

### **選項 1：最小修改（推薦）**

只修改顯示文字，**不修改函數名稱**：
- ✅ 更新 `getPermissionText()` 函數的返回值
- ✅ 更新 `getPermissionStatus()` 函數的返回文字
- ❌ 不修改函數名稱（避免不必要的代碼變更）

**優點：**
- 風險最小
- 不影響現有代碼結構
- 只更新顯示文字，符合需求

### **選項 2：完整優化（可選）**

同時修改函數名稱和顯示文字：
- ✅ 更新函數名稱以匹配新的顯示名稱
- ✅ 更新所有顯示文字
- ⚠️ 需要更多測試和驗證

**優點：**
- 代碼可讀性更好
- 函數名稱與實際含義一致
- 長期維護更容易

---

## 📝 結論

**大部分變數/常數名稱不需要修改**，因為：

1. ✅ 常數名稱已經正確（`SUSPENDED_BY_ADMIN` 等）
2. ✅ 錯誤代碼常數與 permission 無關
3. ✅ 邏輯判斷函數名稱功能正確

**只有 UI 構建函數名稱可能需要優化**，但這是可選的，不影響功能。

**建議：優先修改顯示文字，函數名稱優化可以後續進行。**

