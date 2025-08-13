# 任務狀態設計文件

> 說明：本檔聚焦任務狀態、頁面行為與視覺規範。聊天室即時通訊協議、未讀聚合規則、狀態變更事件與自動完成（7日倒數）等技術細節，請參考 `docs/chat/CHAT_PROTOCOL.md`。

## 📊 任務狀態種類總覽

### 1. **Open (開放中)**
- **資料庫狀態**: `open`
- **顯示狀態**: `Open`
- **進度**: 0% (0.0)
- **顏色**: 藍色系
- **描述**: 任務已發布，等待應徵者申請

**功能設計**：
- **聊天室列表頁面**：
  - 顯示所有應徵者列表
  - 外層任務卡片：點擊顯示任務資訊懸浮視窗（Edit/Delete 移至懸浮視窗）
  - 內層應徵者卡片：根據角色視角決定滑動功能
  - 未讀訊息統計：計算所有應徵者的未讀訊息
  - 總未讀徽章顯示在右上角

- **聊天室詳情頁面**：
  - 可進行對話
  - 顯示應徵者資訊和履歷
  - 底部操作按鈕：Accept（接受應徵者）
  - 接受後狀態變更為 "In Progress"

### 2. **In Progress (進行中)**
- **資料庫狀態**: `in_progress`
- **顯示狀態**: `In Progress`
- **進度**: 25% (0.25)
- **顏色**: 橘色系
- **描述**: 任務已被接受，正在執行中

**功能設計**：
- **聊天室列表頁面**：
  - 只顯示已選擇的應徵者
  - 外層任務卡片：點擊顯示任務資訊懸浮視窗
  - 內層應徵者卡片：根據角色視角決定滑動功能
  - 未讀訊息統計：計算進行中任務的未讀訊息

- **聊天室詳情頁面**：
  - 可進行對話
  - 底部操作按鈕：Pay（支付）、Silence（靜音）、Complaint（投訴）、Block（封鎖）

### 3. **Pending Confirmation (等待確認)**
- **資料庫狀態**: `pending_confirmation`
- **顯示狀態**: `Pending Confirmation`
- **進度**: 50% (0.5)
- **顏色**: 紫色系
- **描述**: 任務已完成，等待海報確認

**功能設計**：
- **聊天室列表頁面**：
  - 顯示倒數計時器（7天倒數）
  - 只顯示已選擇的應徵者
  - 未讀訊息統計：計算確認狀態的未讀訊息
  - 管理員權限（99）：顯示快速倒數按鈕（提前至5秒）

- **聊天室詳情頁面**：
  - 顯示倒數計時器
  - 可進行對話
  - 底部操作按鈕：Confirm（確認完成）、Complaint（投訴）
  - 倒數結束後自動變更為 "Completed"
  - 管理員權限（99）：顯示快速倒數按鈕

### 4. **Completed (已完成)**
- **資料庫狀態**: `completed`
- **顯示狀態**: `Completed`
- **進度**: 100% (1.0)
- **顏色**: 綠色系
- **描述**: 任務已完成並確認

**功能設計**：
- **聊天室列表頁面**：
  - 顯示已完成任務
  - 未讀訊息統計：不計算已完成任務的未讀訊息

- **聊天室詳情頁面**：
  - 對話功能已停用
  - 底部操作按鈕：Paid（已支付）、Reviews（評價）

### 5. **Applying (申請中)**
- **資料庫狀態**: `applying`
- **顯示狀態**: `Applying`
- **進度**: 0% (0.0)
- **顏色**: 淺綠色系
- **描述**: 應徵者已申請，等待海報回應

**功能設計**：
- **聊天室詳情頁面**：
  - 顯示等待海報回應的提示訊息
  - 底部操作按鈕：Complaint（投訴）、Block（封鎖）

### 6. **Rejected (被拒絕)**
- **資料庫狀態**: `rejected`
- **顯示狀態**: `Rejected`
- **進度**: 100% (1.0)
- **顏色**: 藍灰色系
- **描述**: 應徵者申請被拒絕

**功能設計**：
- **聊天室詳情頁面**：
  - 顯示被拒絕的提示訊息
  - 對話功能已停用
  - 底部操作按鈕：Complaint（投訴）

### 7. **Dispute (爭議中)**
- **資料庫狀態**: `dispute`
- **顯示狀態**: `Dispute`
- **進度**: 75% (0.75)
- **顏色**: 棕色系
- **描述**: 任務發生爭議，需要處理

**功能設計**：
- **聊天室詳情頁面**：
  - 可進行對話
  - 底部操作按鈕：Complaint（投訴）

---

## 🎯 頁面功能對應表

### **聊天室列表頁面 (`chat_list_page.dart`)**

| 狀態 | 外層卡片 | 內層卡片（發布者視角） | 內層卡片（執行者視角） | 未讀統計 | 特殊功能 |
|------|----------|----------------------|----------------------|----------|----------|
| Open | 點擊懸浮視窗 | ✅ Accept/Reject | ❌ 無滑動功能 | ✅ 計算所有應徵者 | 總未讀徽章 |
| In Progress | 點擊懸浮視窗 | ✅ Read | ❌ 無滑動功能 | ✅ 計算進行中 | - |
| Pending Confirmation | 點擊懸浮視窗 | ✅ Read | ❌ 無滑動功能 | ✅ 計算確認狀態 | 倒數計時器 + 管理員快速倒數 |
| Completed | 點擊懸浮視窗 | ✅ Read | ❌ 無滑動功能 | ❌ 不計算 | - |
| Dispute | 點擊懸浮視窗 | ✅ Read | ❌ 無滑動功能 | ✅ 計算爭議中 | - |

### **聊天室詳情頁面 (`chat_detail_page.dart`)**

#### **任務發布者 (Creator) 視角**

| 狀態 | 對話功能 | 底部按鈕 | 特殊功能 | 輸入框狀態 | 提示訊息 |
|------|----------|----------|----------|------------|----------|
| Open | ✅ 可對話 | Accept | 查看履歷 | ✅ 啟用 | - |
| In Progress | ✅ 可對話 | Pay, Silence, Complaint, Block | - | ✅ 啟用 | - |
| Pending Confirmation | ✅ 可對話 | Confirm, Complaint | 倒數計時器 + 管理員快速倒數 | ✅ 啟用 | 請盡快確認任務完成 |
| Completed | ❌ 不可對話 | Paid, Reviews | - | ❌ 停用 | 任務已完成 |
| Dispute | ✅ 可對話 | Complaint | - | ✅ 啟用 | - |

#### **任務執行者 (Acceptor) 視角**

| 狀態 | 對話功能 | 底部按鈕 | 特殊功能 | 輸入框狀態 | 提示訊息 |
|------|----------|----------|----------|------------|----------|
| Applying | ✅ 可對話 | Complaint, Block | - | ✅ 啟用 | 等待海報回應您的申請 |
| In Progress | ✅ 可對話 | Completed, Complaint, Block | - | ✅ 啟用 | - |
| Pending Confirmation | ✅ 可對話 | Complaint | 倒數計時器 | ✅ 啟用 | 等待海報確認任務完成 |
| Completed | ❌ 不可對話 | Reviews, Complaint | - | ❌ 停用 | 任務已完成 |
| Rejected | ❌ 不可對話 | Complaint | - | ❌ 停用 | 很抱歉，您的申請被拒絕 |

---

## 🎨 視覺設計規範

### **狀態配色系統物件格式**

```dart
class TaskStatusColors {
  final Color primary;
  final Color background;
  final Color text;
  final Color progressBar;
  
  const TaskStatusColors({
    required this.primary,
    required this.background,
    required this.text,
    required this.progressBar,
  });
}

class TaskStatusTheme {
  static const Map<String, TaskStatusColors> colors = {
    'open': TaskStatusColors(
      primary: Color(0xFF1976D2),      // Colors.blue[800]
      background: Color(0xFFE3F2FD),   // Colors.blue[50]
      text: Color(0xFF1976D2),         // Colors.blue[800]
      progressBar: Color(0xFF90CAF9),  // Colors.blue[200]
    ),
    'in_progress': TaskStatusColors(
      primary: Color(0xFFF57C00),      // Colors.orange[800]
      background: Color(0xFFFFF3E0),   // Colors.orange[50]
      text: Color(0xFFF57C00),         // Colors.orange[800]
      progressBar: Color(0xFFFFCC80),  // Colors.orange[200]
    ),
    'pending_confirmation': TaskStatusColors(
      primary: Color(0xFF7B1FA2),      // Colors.purple[800]
      background: Color(0xFFF3E5F5),   // Colors.purple[50]
      text: Color(0xFF7B1FA2),         // Colors.purple[800]
      progressBar: Color(0xFFCE93D8),  // Colors.purple[200]
    ),
    'completed': TaskStatusColors(
      primary: Color(0xFF424242),      // Colors.grey[800]
      background: Color(0xFFEEEEEE),   // Colors.grey[200]
      text: Color(0xFF424242),         // Colors.grey[800]
      progressBar: Color(0xFF81C784),  // Colors.lightGreen[200]
    ),
    'applying': TaskStatusColors(
      primary: Color(0xFF388E3C),      // Colors.lightGreen[800]
      background: Color(0xFFE8F5E8),   // Colors.lightGreen[50]
      text: Color(0xFF388E3C),         // Colors.lightGreen[800]
      progressBar: Color(0xFFA5D6A7),  // Colors.lightGreen[200]
    ),
    'rejected': TaskStatusColors(
      primary: Color(0xFF546E7A),      // Colors.blueGrey[800]
      background: Color(0xFFECEFF1),   // Colors.blueGrey[200]
      text: Color(0xFF546E7A),         // Colors.blueGrey[800]
      progressBar: Color(0xFFB0BEC5),  // Colors.blueGrey[200]
    ),
    'dispute': TaskStatusColors(
      primary: Color(0xFF5D4037),      // Colors.brown[800]
      background: Color(0xFFEFEBE9),   // Colors.brown[50]
      text: Color(0xFF5D4037),         // Colors.brown[800]
      progressBar: Color(0xFFBCAAA4),  // Colors.brown[200]
    ),
  };
}
```

### **主題配色對應**

#### **Meta Business Theme**
```dart
class MetaBusinessTaskStatusTheme {
  static const Map<String, TaskStatusColors> colors = {
    'open': TaskStatusColors(
      primary: Color(0xFF6B46C1),      // Purple
      background: Color(0xFFF3F4F6),   // Light gray
      text: Color(0xFF6B46C1),         // Purple
      progressBar: Color(0xFFC4B5FD),  // Light purple
    ),
    'in_progress': TaskStatusColors(
      primary: Color(0xFFF59E0B),      // Amber
      background: Color(0xFFFFFBEB),   // Light amber
      text: Color(0xFFF59E0B),         // Amber
      progressBar: Color(0xFFFCD34D),  // Light amber
    ),
    'pending_confirmation': TaskStatusColors(
      primary: Color(0xFF7C3AED),      // Violet
      background: Color(0xFFF5F3FF),   // Light violet
      text: Color(0xFF7C3AED),         // Violet
      progressBar: Color(0xFFC4B5FD),  // Light violet
    ),
    'completed': TaskStatusColors(
      primary: Color(0xFF059669),      // Emerald
      background: Color(0xFFECFDF5),   // Light emerald
      text: Color(0xFF059669),         // Emerald
      progressBar: Color(0xFF6EE7B7),  // Light emerald
    ),
    'applying': TaskStatusColors(
      primary: Color(0xFF10B981),      // Emerald
      background: Color(0xFFECFDF5),   // Light emerald
      text: Color(0xFF10B981),         // Emerald
      progressBar: Color(0xFF6EE7B7),  // Light emerald
    ),
    'rejected': TaskStatusColors(
      primary: Color(0xFF6B7280),      // Gray
      background: Color(0xFFF9FAFB),   // Light gray
      text: Color(0xFF6B7280),         // Gray
      progressBar: Color(0xFFD1D5DB),  // Light gray
    ),
    'dispute': TaskStatusColors(
      primary: Color(0xFF92400E),      // Amber
      background: Color(0xFFFFFBEB),   // Light amber
      text: Color(0xFF92400E),         // Amber
      progressBar: Color(0xFFFCD34D),  // Light amber
    ),
  };
}
```

#### **Standard Theme**
```dart
class StandardTaskStatusTheme {
  static const Map<String, TaskStatusColors> colors = {
    'open': TaskStatusColors(
      primary: Color(0xFF1976D2),      // Blue
      background: Color(0xFFE3F2FD),   // Light blue
      text: Color(0xFF1976D2),         // Blue
      progressBar: Color(0xFF90CAF9),  // Light blue
    ),
    'in_progress': TaskStatusColors(
      primary: Color(0xFFF57C00),      // Orange
      background: Color(0xFFFFF3E0),   // Light orange
      text: Color(0xFFF57C00),         // Orange
      progressBar: Color(0xFFFFCC80),  // Light orange
    ),
    'pending_confirmation': TaskStatusColors(
      primary: Color(0xFF7B1FA2),      // Purple
      background: Color(0xFFF3E5F5),   // Light purple
      text: Color(0xFF7B1FA2),         // Purple
      progressBar: Color(0xFFCE93D8),  // Light purple
    ),
    'completed': TaskStatusColors(
      primary: Color(0xFF424242),      // Grey
      background: Color(0xFFEEEEEE),   // Light grey
      text: Color(0xFF424242),         // Grey
      progressBar: Color(0xFF81C784),  // Light green
    ),
    'applying': TaskStatusColors(
      primary: Color(0xFF388E3C),      // Light green
      background: Color(0xFFE8F5E8),   // Light green background
      text: Color(0xFF388E3C),         // Light green
      progressBar: Color(0xFFA5D6A7),  // Light green
    ),
    'rejected': TaskStatusColors(
      primary: Color(0xFF546E7A),      // Blue grey
      background: Color(0xFFECEFF1),   // Light blue grey
      text: Color(0xFF546E7A),         // Blue grey
      progressBar: Color(0xFFB0BEC5),  // Light blue grey
    ),
    'dispute': TaskStatusColors(
      primary: Color(0xFF5D4037),      // Brown
      background: Color(0xFFEFEBE9),   // Light brown
      text: Color(0xFF5D4037),         // Brown
      progressBar: Color(0xFFBCAAA4),  // Light brown
    ),
  };
}
```

#### **Morandi Blue Theme**
```dart
class MorandiBlueTaskStatusTheme {
  static const Map<String, TaskStatusColors> colors = {
    'open': TaskStatusColors(
      primary: Color(0xFF7B8A95),      // Morandi blue
      background: Color(0xFFF8FAFC),   // Light morandi blue
      text: Color(0xFF7B8A95),         // Morandi blue
      progressBar: Color(0xFFB8C5D1),  // Light morandi blue
    ),
    'in_progress': TaskStatusColors(
      primary: Color(0xFF9BA8B4),      // Morandi gray blue
      background: Color(0xFFF8FAFC),   // Light morandi blue
      text: Color(0xFF9BA8B4),         // Morandi gray blue
      progressBar: Color(0xFFB8C5D1),  // Light morandi blue
    ),
    'pending_confirmation': TaskStatusColors(
      primary: Color(0xFF8B9A9F),      // Morandi teal
      background: Color(0xFFF8FAFC),   // Light morandi blue
      text: Color(0xFF8B9A9F),         // Morandi teal
      progressBar: Color(0xFFB8C5D1),  // Light morandi blue
    ),
    'completed': TaskStatusColors(
      primary: Color(0xFF7B8A95),      // Morandi blue
      background: Color(0xFFF8FAFC),   // Light morandi blue
      text: Color(0xFF7B8A95),         // Morandi blue
      progressBar: Color(0xFFB8C5D1),  // Light morandi blue
    ),
    'applying': TaskStatusColors(
      primary: Color(0xFF8FBC8F),      // Morandi green
      background: Color(0xFFF8FAFC),   // Light morandi blue
      text: Color(0xFF8FBC8F),         // Morandi green
      progressBar: Color(0xFFB8C5D1),  // Light morandi blue
    ),
    'rejected': TaskStatusColors(
      primary: Color(0xFF9BA8B4),      // Morandi gray blue
      background: Color(0xFFF8FAFC),   // Light morandi blue
      text: Color(0xFF9BA8B4),         // Morandi gray blue
      progressBar: Color(0xFFB8C5D1),  // Light morandi blue
    ),
    'dispute': TaskStatusColors(
      primary: Color(0xFFB56576),      // Morandi pink
      background: Color(0xFFF8FAFC),   // Light morandi blue
      text: Color(0xFFB56576),         // Morandi pink
      progressBar: Color(0xFFB8C5D1),  // Light morandi blue
    ),
  };
}
```

### **進度條設計**

| 狀態 | 進度值 | 顏色 | 顯示文字 |
|------|--------|------|----------|
| Open | 0.0 | 主題對應顏色 | Open (0%) |
| In Progress | 0.25 | 主題對應顏色 | In Progress (25%) |
| Pending Confirmation | 0.5 | 主題對應顏色 | Pending Confirmation (50%) |
| Completed | 1.0 | 主題對應顏色 | Completed (100%) |
| Dispute | 0.75 | 主題對應顏色 | Dispute (75%) |

---

## 🔄 狀態轉換流程

### **主要狀態轉換**

1. **Open** → **In Progress** (海報接受應徵者)
2. **In Progress** → **Pending Confirmation** (應徵者完成任務)
3. **Pending Confirmation** → **Completed** (海報確認完成)
4. **Applying** → **In Progress** (海報接受申請)
5. **Applying** → **Rejected** (海報拒絕申請)

### **狀態轉換觸發條件**

| 轉換 | 觸發條件 | 觸發者 | 目標狀態 |
|------|----------|--------|----------|
| Open → In Progress | 海報點擊 "Accept" | 海報 (Creator) | In Progress |
| In Progress → Pending Confirmation | 應徵者點擊 "Completed" | 應徵者 (Acceptor) | Pending Confirmation |
| Pending Confirmation → Completed | 海報點擊 "Confirm" 或倒數結束 | 海報/系統 | Completed |
| Applying → In Progress | 海報點擊 "Accept" | 海報 (Creator) | In Progress |
| Applying → Rejected | 海報點擊 "Reject" | 海報 (Creator) | Rejected |

---

## 📝 功能設計要點

### **聊天室列表頁面**

1. **外層任務卡片**：
   - 所有狀態：點擊顯示任務資訊懸浮視窗
   - Edit/Delete 功能移至懸浮視窗
   - 移除外層滑動效果

2. **內層應徵者卡片**：
   - **發布者視角**：可左右滑動（Accept/Reject 或 Read）
   - **執行者視角**：無滑動功能（任務交易介面，不支援消極操作）
   - 未讀訊息徽章顯示

3. **未讀統計**：
   - 計算邏輯：根據狀態和應徵者數量
   - 顯示位置：右上角總未讀徽章

### **聊天室詳情頁面**

1. **對話功能**：
   - 根據狀態決定是否可對話
   - 訊息時間戳記
   - 打字指示器

2. **底部操作按鈕**：
   - 根據狀態和用戶角色動態顯示
   - 按鈕功能明確對應狀態轉換

3. **倒數計時器**：
   - Pending Confirmation：7天倒數
   - 管理員權限（99）：快速倒數按鈕（提前至5秒）

4. **提示訊息**：
   - 根據狀態顯示對應提示
   - 幫助用戶了解當前狀態

### **管理員快速倒數功能**

1. **權限檢查**：用戶權限為 99 時顯示
2. **功能位置**：
   - 聊天室列表頁面：Pending Confirmation 狀態的任務卡片
   - 聊天室詳情頁面：Pending Confirmation 狀態的底部操作區
3. **功能效果**：點擊後立即將倒數時間設為 5 秒
4. **視覺設計**：使用管理員專用顏色和圖標

---

## 🔧 技術實現要點

### **狀態管理**

1. **資料庫狀態**：使用統一的狀態字串
2. **顯示狀態**：通過 TaskStatus 類別轉換
3. **狀態驗證**：確保狀態轉換的合法性
4. **角色判斷**：根據 tasks 表的 creator_id 和當前用戶 ID 判斷角色

### **未讀訊息統計**

1. **計算邏輯**：
   - Open：所有應徵者的未讀訊息總和
   - In Progress：進行中任務的未讀訊息
   - Pending Confirmation：確認狀態的未讀訊息
   - Completed：不計算未讀訊息

2. **更新機制**：
   - 即時更新未讀統計
   - 點擊聊天室後清除未讀

### **倒數計時器**

1. **實現方式**：使用 Ticker 類別
2. **時間設定**：
   - Pending Confirmation：7天
3. **自動完成**：倒數結束後自動變更狀態
4. **管理員快速倒數**：權限 99 用戶可提前倒數至 5 秒

### **角色視角判斷**

```dart
enum TaskRole {
  creator,  // 任務發布者
  acceptor, // 任務執行者
  none,     // 無關用戶
}

class TaskRoleHelper {
  static TaskRole getTaskRole(String taskId, String currentUserId) {
    // 根據 tasks 表的 creator_id 判斷角色
    // 實現邏輯：查詢 task 的 creator_id，與當前用戶 ID 比較
    // 如果 creator_id == currentUserId，則為 creator
    // 否則為 acceptor
  }
}
```

### **滑動功能邏輯**

#### **發布者視角 (Creator)**
- **Open 狀態**：左滑 Accept，右滑 Reject
- **In Progress 狀態**：左滑 Read，右滑 Hide
- **Pending Confirmation 狀態**：左滑 Read，右滑 Hide
- **Completed 狀態**：左滑 Read，右滑 Hide
- **Dispute 狀態**：左滑 Read，右滑 Hide

#### **執行者視角 (Acceptor)**
- **所有狀態**：無滑動功能
- **原因**：任務交易介面，不支援消極操作（隱藏、刪除、已讀）
- **設計理念**：專注於任務完成和溝通，避免不必要的操作干擾

### **管理員快速倒數功能實現**

```dart
class AdminCountdownHelper {
  static bool isAdmin(int userPermission) {
    return userPermission == 99;
  }
  
  static void quickCountdown(BuildContext context, String taskId) {
    if (isAdmin(currentUserPermission)) {
      // 將倒數時間設為 5 秒
      final newEndTime = DateTime.now().add(const Duration(seconds: 5));
      // 更新資料庫中的倒數時間
      _updateTaskCountdown(taskId, newEndTime);
      // 重新啟動倒數計時器
      _restartCountdown(taskId);
    }
  }
}
```

---

## 🚀 優化建議

1. **狀態一致性**：確保資料庫狀態和顯示狀態的一致性
2. **倒數計時器**：統一倒數時間設定（7天）
3. **未讀統計**：優化未讀訊息的計算邏輯
4. **滑動功能**：根據角色視角決定滑動功能
5. **狀態顏色**：統一狀態顏色主題，使用主題配色系統
6. **用戶體驗**：優化狀態轉換的用戶體驗和提示訊息
7. **管理員功能**：完善管理員快速倒數功能的用戶體驗

---

*最後更新: 2025年8月8日*
*版本: 3.0* 