# 任務狀態系統遷移指南

> 生成日期：2025-01-18  
> 目標：從硬編碼任務狀態遷移到動態 API 驅動系統

---

## 🎯 遷移概覽

### ✅ 已完成的改進

1. **建立 TaskStatusService** - 動態載入狀態資料
2. **重構 TaskStatus 常量類** - 向後相容的棄用
3. **建立新的 UI 元件** - 狀態選擇器、標籤、進度條
4. **整合應用初始化** - 自動載入狀態資料
5. **更新 TaskService** - 委託給新的狀態服務

### 🔄 遷移步驟

#### 1. 更新 Import 語句

**舊方式：**
```dart
import '../constants/task_status.dart';

// 使用
final displayName = TaskStatus.getDisplayStatus(status);
```

**新方式：**
```dart
import '../services/task_status_service.dart';
import 'package:provider/provider.dart';

// 使用
final statusService = context.read<TaskStatusService>();
final displayName = statusService.getDisplayName(status);
```

#### 2. 替換硬編碼狀態檢查

**舊方式：**
```dart
// 硬編碼狀態檢查
if (task['status'] == 'open') {
  // ...
}

// 硬編碼顏色
final colors = TaskStatus.themedColors(colorScheme);
final statusColor = colors['Open']?.fg;
```

**新方式：**
```dart
// 動態狀態檢查
final statusService = context.read<TaskStatusService>();
final statusModel = statusService.getByCode(task['status_code']);
if (statusModel?.code == 'open') {
  // ...
}

// 動態顏色
final style = statusService.getStatusStyle(task['status_code'], colorScheme);
final statusColor = style.foregroundColor;
```

#### 3. 更新狀態顯示元件

**舊方式：**
```dart
// 手動建立狀態顯示
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: _getStatusColor(status),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Text(TaskStatus.getDisplayStatus(status)),
)
```

**新方式：**
```dart
// 使用新的元件
TaskStatusChip(
  statusIdentifier: task['status_code'] ?? task['status_id'],
  showIcon: true,
  showProgress: true,
)
```

#### 4. 實作狀態選擇功能

**新方式：**
```dart
TaskStatusSelector(
  initialStatusCode: currentStatus,
  onStatusChanged: (newStatus) {
    // 處理狀態變更
    updateTaskStatus(task['id'], newStatus?.code);
  },
)
```

---

## 🛠️ 具體遷移範例

### Chat List Page 遷移

**檔案：** `lib/chat/pages/chat_list_page.dart`

**舊方式：**
```dart
String _displayStatus(Map<String, dynamic> task) {
  final dynamic display = task['status_display'];
  if (display != null && display is String && display.isNotEmpty) {
    return display;
  }
  final dynamic codeOrLegacy = task['status_code'] ?? task['status'];
  final mapped = TaskStatus.statusString[codeOrLegacy] ?? codeOrLegacy;
  return (mapped ?? '').toString();
}
```

**新方式：**
```dart
String _displayStatus(Map<String, dynamic> task) {
  final statusService = context.read<TaskStatusService>();
  
  // 優先使用後端返回的 display_name
  if (task['status_display'] != null && task['status_display'].toString().isNotEmpty) {
    return task['status_display'].toString();
  }
  
  // 使用動態服務解析
  final identifier = task['status_id'] ?? task['status_code'] ?? task['status'];
  return statusService.getDisplayName(identifier);
}
```

### Task List Page 遷移

**檔案：** `lib/task/pages/task_list_page.dart`

**舊方式：**
```dart
// 手動建立狀態篩選器
DropdownButton<String>(
  items: ['open', 'in_progress', 'completed'].map((status) =>
    DropdownMenuItem(
      value: status,
      child: Text(TaskStatus.getDisplayStatus(status)),
    )
  ).toList(),
  onChanged: (status) => filterByStatus(status),
)
```

**新方式：**
```dart
// 使用動態狀態篩選器
TaskStatusFilter(
  selectedStatusCodes: selectedStatuses,
  onChanged: (statuses) => filterByStatuses(statuses),
)
```

---

## 📊 新功能優勢

### 1. 動態狀態管理
- 狀態資料從資料庫動態載入
- 支援新增/修改狀態而無需更新前端
- 統一的狀態邏輯

### 2. 豐富的 UI 元件
- `TaskStatusChip` - 狀態標籤
- `TaskStatusSelector` - 狀態選擇器
- `TaskStatusProgressBar` - 進度條
- `TaskStatusDisplay` - 綜合顯示元件
- `TaskStatusFilter` - 狀態篩選器
- `TaskStatusStats` - 狀態統計圖

### 3. 主題整合
- 自動適配應用主題色彩
- 狀態圖示系統
- 進度顯示

### 4. 向後相容性
- 現有程式碼可繼續運作
- 漸進式遷移
- 棄用警告指導

---

## 🔧 實際應用指南

### 步驟 1：更新現有頁面

1. **聊天列表頁面 (`chat_list_page.dart`)**
   ```dart
   // 替換 _displayStatus 方法
   // 使用 TaskStatusChip 替代手動狀態顯示
   ```

2. **任務列表頁面 (`task_list_page.dart`)**
   ```dart
   // 使用 TaskStatusFilter 替代硬編碼篩選器
   // 使用 TaskStatusChip 顯示狀態
   ```

3. **任務詳情頁面 (`task_detail_page.dart`)**
   ```dart
   // 使用 TaskStatusDisplay 元件
   // 實作狀態編輯功能
   ```

### 步驟 2：測試和驗證

1. **確保狀態服務初始化**
   ```dart
   // 在 main.dart 中確認 TaskStatusService 已註冊
   ```

2. **測試狀態顯示**
   ```dart
   // 檢查各頁面的狀態顯示是否正常
   ```

3. **測試狀態變更**
   ```dart
   // 測試狀態選擇器和更新功能
   ```

### 步驟 3：清理舊程式碼

1. **移除硬編碼常量**（謹慎進行）
2. **更新相關註解**
3. **刪除不再使用的方法**

---

## ⚠️ 注意事項

### 遷移順序
1. 先確保 TaskStatusService 正常運作
2. 逐頁面更新，避免一次性大改
3. 保留舊方法直到完全遷移完成

### 錯誤處理
```dart
// 確保服務已初始化
if (!statusService.isLoaded) {
  // 顯示載入中或錯誤狀態
  return CircularProgressIndicator();
}
```

### 效能考量
- TaskStatusService 使用單例模式
- 狀態資料在應用啟動時載入
- 支援強制重新載入

---

## 🎉 遷移檢查清單

### 核心元件
- [x] TaskStatusService 已建立
- [x] TaskStatus 已重構為向後相容
- [x] UI 元件已建立
- [x] 應用初始化已更新

### 頁面遷移
- [ ] chat_list_page.dart
- [ ] task_list_page.dart  
- [ ] task_detail_page.dart
- [ ] task_create_page.dart

### 功能測試
- [ ] 狀態顯示正確
- [ ] 狀態選擇功能正常
- [ ] 主題色彩適配
- [ ] 進度顯示正確

### 清理工作
- [ ] 移除硬編碼檢查
- [ ] 更新文件註解
- [ ] 刪除不使用的程式碼

---

## 📞 支援資源

- **TaskStatusService 文件**: `lib/services/task_status_service.dart`
- **UI 元件範例**: `lib/widgets/task_status_selector.dart`
- **顯示元件範例**: `lib/task/widgets/task_status_display.dart`
- **後端 API**: `/backend/api/tasks/statuses.php`

**遷移完成後，任務狀態系統將完全動態化，易於維護和擴展！** 🚀

> 生成日期：2025-01-18  
> 目標：從硬編碼任務狀態遷移到動態 API 驅動系統

---

## 🎯 遷移概覽

### ✅ 已完成的改進

1. **建立 TaskStatusService** - 動態載入狀態資料
2. **重構 TaskStatus 常量類** - 向後相容的棄用
3. **建立新的 UI 元件** - 狀態選擇器、標籤、進度條
4. **整合應用初始化** - 自動載入狀態資料
5. **更新 TaskService** - 委託給新的狀態服務

### 🔄 遷移步驟

#### 1. 更新 Import 語句

**舊方式：**
```dart
import '../constants/task_status.dart';

// 使用
final displayName = TaskStatus.getDisplayStatus(status);
```

**新方式：**
```dart
import '../services/task_status_service.dart';
import 'package:provider/provider.dart';

// 使用
final statusService = context.read<TaskStatusService>();
final displayName = statusService.getDisplayName(status);
```

#### 2. 替換硬編碼狀態檢查

**舊方式：**
```dart
// 硬編碼狀態檢查
if (task['status'] == 'open') {
  // ...
}

// 硬編碼顏色
final colors = TaskStatus.themedColors(colorScheme);
final statusColor = colors['Open']?.fg;
```

**新方式：**
```dart
// 動態狀態檢查
final statusService = context.read<TaskStatusService>();
final statusModel = statusService.getByCode(task['status_code']);
if (statusModel?.code == 'open') {
  // ...
}

// 動態顏色
final style = statusService.getStatusStyle(task['status_code'], colorScheme);
final statusColor = style.foregroundColor;
```

#### 3. 更新狀態顯示元件

**舊方式：**
```dart
// 手動建立狀態顯示
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: _getStatusColor(status),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Text(TaskStatus.getDisplayStatus(status)),
)
```

**新方式：**
```dart
// 使用新的元件
TaskStatusChip(
  statusIdentifier: task['status_code'] ?? task['status_id'],
  showIcon: true,
  showProgress: true,
)
```

#### 4. 實作狀態選擇功能

**新方式：**
```dart
TaskStatusSelector(
  initialStatusCode: currentStatus,
  onStatusChanged: (newStatus) {
    // 處理狀態變更
    updateTaskStatus(task['id'], newStatus?.code);
  },
)
```

---

## 🛠️ 具體遷移範例

### Chat List Page 遷移

**檔案：** `lib/chat/pages/chat_list_page.dart`

**舊方式：**
```dart
String _displayStatus(Map<String, dynamic> task) {
  final dynamic display = task['status_display'];
  if (display != null && display is String && display.isNotEmpty) {
    return display;
  }
  final dynamic codeOrLegacy = task['status_code'] ?? task['status'];
  final mapped = TaskStatus.statusString[codeOrLegacy] ?? codeOrLegacy;
  return (mapped ?? '').toString();
}
```

**新方式：**
```dart
String _displayStatus(Map<String, dynamic> task) {
  final statusService = context.read<TaskStatusService>();
  
  // 優先使用後端返回的 display_name
  if (task['status_display'] != null && task['status_display'].toString().isNotEmpty) {
    return task['status_display'].toString();
  }
  
  // 使用動態服務解析
  final identifier = task['status_id'] ?? task['status_code'] ?? task['status'];
  return statusService.getDisplayName(identifier);
}
```

### Task List Page 遷移

**檔案：** `lib/task/pages/task_list_page.dart`

**舊方式：**
```dart
// 手動建立狀態篩選器
DropdownButton<String>(
  items: ['open', 'in_progress', 'completed'].map((status) =>
    DropdownMenuItem(
      value: status,
      child: Text(TaskStatus.getDisplayStatus(status)),
    )
  ).toList(),
  onChanged: (status) => filterByStatus(status),
)
```

**新方式：**
```dart
// 使用動態狀態篩選器
TaskStatusFilter(
  selectedStatusCodes: selectedStatuses,
  onChanged: (statuses) => filterByStatuses(statuses),
)
```

---

## 📊 新功能優勢

### 1. 動態狀態管理
- 狀態資料從資料庫動態載入
- 支援新增/修改狀態而無需更新前端
- 統一的狀態邏輯

### 2. 豐富的 UI 元件
- `TaskStatusChip` - 狀態標籤
- `TaskStatusSelector` - 狀態選擇器
- `TaskStatusProgressBar` - 進度條
- `TaskStatusDisplay` - 綜合顯示元件
- `TaskStatusFilter` - 狀態篩選器
- `TaskStatusStats` - 狀態統計圖

### 3. 主題整合
- 自動適配應用主題色彩
- 狀態圖示系統
- 進度顯示

### 4. 向後相容性
- 現有程式碼可繼續運作
- 漸進式遷移
- 棄用警告指導

---

## 🔧 實際應用指南

### 步驟 1：更新現有頁面

1. **聊天列表頁面 (`chat_list_page.dart`)**
   ```dart
   // 替換 _displayStatus 方法
   // 使用 TaskStatusChip 替代手動狀態顯示
   ```

2. **任務列表頁面 (`task_list_page.dart`)**
   ```dart
   // 使用 TaskStatusFilter 替代硬編碼篩選器
   // 使用 TaskStatusChip 顯示狀態
   ```

3. **任務詳情頁面 (`task_detail_page.dart`)**
   ```dart
   // 使用 TaskStatusDisplay 元件
   // 實作狀態編輯功能
   ```

### 步驟 2：測試和驗證

1. **確保狀態服務初始化**
   ```dart
   // 在 main.dart 中確認 TaskStatusService 已註冊
   ```

2. **測試狀態顯示**
   ```dart
   // 檢查各頁面的狀態顯示是否正常
   ```

3. **測試狀態變更**
   ```dart
   // 測試狀態選擇器和更新功能
   ```

### 步驟 3：清理舊程式碼

1. **移除硬編碼常量**（謹慎進行）
2. **更新相關註解**
3. **刪除不再使用的方法**

---

## ⚠️ 注意事項

### 遷移順序
1. 先確保 TaskStatusService 正常運作
2. 逐頁面更新，避免一次性大改
3. 保留舊方法直到完全遷移完成

### 錯誤處理
```dart
// 確保服務已初始化
if (!statusService.isLoaded) {
  // 顯示載入中或錯誤狀態
  return CircularProgressIndicator();
}
```

### 效能考量
- TaskStatusService 使用單例模式
- 狀態資料在應用啟動時載入
- 支援強制重新載入

---

## 🎉 遷移檢查清單

### 核心元件
- [x] TaskStatusService 已建立
- [x] TaskStatus 已重構為向後相容
- [x] UI 元件已建立
- [x] 應用初始化已更新

### 頁面遷移
- [ ] chat_list_page.dart
- [ ] task_list_page.dart  
- [ ] task_detail_page.dart
- [ ] task_create_page.dart

### 功能測試
- [ ] 狀態顯示正確
- [ ] 狀態選擇功能正常
- [ ] 主題色彩適配
- [ ] 進度顯示正確

### 清理工作
- [ ] 移除硬編碼檢查
- [ ] 更新文件註解
- [ ] 刪除不使用的程式碼

---

## 📞 支援資源

- **TaskStatusService 文件**: `lib/services/task_status_service.dart`
- **UI 元件範例**: `lib/widgets/task_status_selector.dart`
- **顯示元件範例**: `lib/task/widgets/task_status_display.dart`
- **後端 API**: `/backend/api/tasks/statuses.php`

**遷移完成後，任務狀態系統將完全動態化，易於維護和擴展！** 🚀