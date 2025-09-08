# ChatDetailPage 任務狀態 Bar 現有架構分析

## 🔍 **架構概覽**

ChatDetailPage 的任務狀態顯示系統採用多層次、組件化的設計架構，主要由以下核心組件組成：

### **核心組件架構**
```
ChatDetailPage
├── DynamicActionBar (狀態顯示 + 操作按鈕)
│   ├── StatusBar (_buildStatusBar) - 狀態條顯示
│   └── ActionBar (_buildActionBar) - 操作按鈕區域
├── ActionBarConfigManager (配置管理)
│   ├── 任務狀態解析 (parseTaskStatus)
│   ├── 用戶角色解析 (parseUserRole)
│   ├── 動作配置 (getActionsForStatus)
│   └── 視覺配置 (getStatusColor, getStatusIcon)
└── Socket 實時更新系統
    ├── _onTaskStatusUpdate (任務狀態更新)
    └── _onApplicationStatusUpdate (應徵狀態更新)
```

## 📋 **詳細組件分析**

### **1. DynamicActionBar - 核心顯示組件**

**位置**: `lib/chat/widgets/dynamic_action_bar.dart`

**功能**: 動態渲染狀態條和操作按鈕

**關鍵特性**:
```dart
class DynamicActionBar extends StatelessWidget {
  final TaskStatus taskStatus;        // 任務狀態
  final UserRole userRole;           // 用戶角色  
  final String? applicationStatus;    // 應徵狀態
  final bool showStatusBar;          // 是否顯示狀態條
  final String? statusDisplayName;   // 狀態顯示名稱
  final double? progressRatio;       // 進度比例
  final String? colorScheme;         // 配色方案 ('posted_tasks' | 'my_works')
  // ... 其他屬性
}
```

**狀態條渲染**:
```dart
Widget _buildStatusBar(BuildContext context) {
  final statusColor = ActionBarConfigManager.getStatusColor(taskStatus);
  final statusIcon = ActionBarConfigManager.getStatusIcon(taskStatus);
  
  return Container(
    // 🎨 狀態條視覺設計
    decoration: BoxDecoration(
      color: statusColor.withOpacity(0.1),
      border: Border(top: BorderSide(color: statusColor.withOpacity(0.3))),
    ),
    child: Row(
      children: [
        Icon(statusIcon, color: statusColor),
        Text(statusDisplayName ?? _getDefaultStatusName(taskStatus)),
        // 📊 進度條顯示
        if (progressRatio != null && progressRatio! > 0)
          LinearProgressIndicator(value: progressRatio),
      ],
    ),
  );
}
```

### **2. ActionBarConfigManager - 配置管理核心**

**位置**: `lib/chat/utils/action_bar_config.dart`

**核心枚舉定義**:
```dart
enum TaskStatus {
  open,                    // 開放中
  inProgress,             // 進行中
  pendingConfirmation,    // 待確認
  completed,              // 已完成
  dispute,                // 糾紛中
  cancelled,              // 已取消
  rejected                // 已拒絕
}

enum UserRole {
  creator,                // 任務創建者
  participant             // 任務參與者
}
```

**狀態解析邏輯**:
```dart
static TaskStatus parseTaskStatus(String? statusCode) {
  switch (statusCode?.toLowerCase()) {
    case 'open': return TaskStatus.open;
    case 'in_progress': return TaskStatus.inProgress;
    case 'pending_confirmation': return TaskStatus.pendingConfirmation;
    case 'completed': return TaskStatus.completed;
    case 'dispute': return TaskStatus.dispute;
    case 'cancelled': case 'canceled': return TaskStatus.cancelled;
    case 'rejected': return TaskStatus.rejected;
    default: return TaskStatus.open;
  }
}
```

**動態配色系統**:
```dart
static Color getStatusColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.open: return Colors.blue;
    case TaskStatus.inProgress: return Colors.orange;
    case TaskStatus.pendingConfirmation: return Colors.amber;
    case TaskStatus.completed: return Colors.green;
    case TaskStatus.dispute: return Colors.red;
    case TaskStatus.cancelled:
    case TaskStatus.rejected: return Colors.grey;
  }
}
```

**動作配置邏輯** (部分展示):
```dart
static List<ActionBarAction> getActionsForStatus({
  required TaskStatus status,
  required UserRole userRole,
  // ... 其他參數
}) {
  final actions = <ActionBarAction>[];
  
  switch (status) {
    case TaskStatus.open:
      if (userRole == UserRole.creator) {
        actions.add(ActionBarAction(
          id: 'accept',
          label: 'Accept',
          icon: Icons.check,
          onTap: actionCallbacks['accept'] ?? () {},
        ).withConfirmation(
          title: 'Accept Application',
          content: 'Are you sure you want to assign this applicant?',
        ));
      }
      break;
    // ... 其他狀態配置
  }
  
  return actions;
}
```

### **3. ChatDetailPage 集成邏輯**

**位置**: `lib/chat/pages/chat_detail_page.dart` (約第3081-3102行)

**狀態 Bar 渲染調用**:
```dart
// Action Bar 區域
if (_showActionBar && (_task != null || _isSupportRoom))
  _isSupportRoom
    ? _buildSupportActionBar()
    : DynamicActionBar(
        taskStatus: ActionBarConfigManager.parseTaskStatus(_task!['status']?['code']),
        userRole: ActionBarConfigManager.parseUserRole(_userRole),
        actionCallbacks: _buildActionCallbacks(),
        applicationStatus: _task?['application']?['status'],
        // 🔒 封鎖狀態處理
        isBlocked: _isBlocked,
        isBlockedByMe: _isBlockedByMe,
        isBlockedByTarget: _isBlockedByTarget,
        hasExistingReview: _hasExistingReview,
        showStatusBar: true,
        // 🎯 動態狀態顯示名稱
        statusDisplayName: _getStatusDisplayNameForUserRole(),
        // 📊 進度比例
        progressRatio: double.tryParse(_task!['status']?['progress_ratio']?.toString() ?? '0'),
        backgroundColor: _glassNavColor(context),
        // 🎨 角色相關配色方案
        colorScheme: _getColorSchemeForUserRole(),
      ),
```

**角色相關狀態顯示邏輯**:
```dart
/// 根據用戶角色獲取狀態顯示名稱
String? _getStatusDisplayNameForUserRole() {
  switch (_userRole.toLowerCase()) {
    case 'creator':
      // 🏗️ 發布者：顯示任務狀態（來自 tasks.status）
      return _task?['status']?['display_name'];
      
    case 'participant':
      // 👷 應徵者：顯示應徵狀態（來自 task_applications.status）
      final applicationStatus = _task?['application_status']?.toString();
      
      if (applicationStatus != null && applicationStatus.isNotEmpty) {
        return ApplicationStatusUtils.getDisplayName(applicationStatus);
      }
      // 備用方案：使用任務狀態
      return _task?['status']?['display_name'];
      
    default:
      return _task?['status']?['display_name'];
  }
}

/// 根據用戶角色獲取配色方案
String _getColorSchemeForUserRole() {
  switch (_userRole.toLowerCase()) {
    case 'creator':
      return 'posted_tasks'; // 發布者使用 Posted Tasks 配色
    case 'participant':
      return 'my_works';     // 應徵者使用 My Works 配色
    default:
      return 'posted_tasks';
  }
}
```

## 🚀 **實時更新機制**

### **Socket 事件監聽**
```dart
// 設置 Socket 監聽器 (約第1393-1395行)
_socketService.onTaskStatusUpdate = _onTaskStatusUpdate;
_socketService.onApplicationStatusUpdate = _onApplicationStatusUpdate;
_socketService.onBlockStatusUpdate = _onBlockStatusUpdate;
```

### **任務狀態實時更新**
```dart
/// 處理任務狀態更新 - 純局部更新版本
void _onTaskStatusUpdate(Map<String, dynamic> data) {
  debugPrint('📋 Task status update received: $data');
  
  // 檢查是否為當前聊天室的任務
  final roomId = data['room_id']?.toString();
  final taskId = data['task_id']?.toString();
  
  if (roomId == _currentRoomId || taskId == _task?['id']?.toString()) {
    // ⚡ 1. 立即更新本地任務狀態（即時性）
    _updateTaskStatusLocally(data);
    
    // 📢 2. 顯示狀態變更通知
    final statusData = data['status'] as Map<String, dynamic>?;
    if (statusData != null) {
      _showTaskStatusChangeNotification(statusData);
    }
    
    // 🔄 3. 通知 Provider 刷新聊天列表
    _notifyProviderRefresh();
  }
}

/// 立即更新本地任務狀態
void _updateTaskStatusLocally(Map<String, dynamic> data) {
  if (!mounted) return;
  
  final statusData = data['status'] as Map<String, dynamic>?;
  if (statusData == null) return;
  
  setState(() {
    if (_task != null) {
      // 🎯 更新任務狀態
      _task!['status'] = statusData;
      
      // ⚙️ 同步更新相關的計算屬性
      _updateDerivedStates();
    }
  });
}
```

### **應徵狀態實時更新**
```dart
/// 處理應徵狀態更新
void _onApplicationStatusUpdate(Map<String, dynamic> data) {
  // 類似邏輯，更新應徵狀態
  _updateApplicationStatusLocally(data);
  _showApplicationStatusChangeNotification(applicationStatus);
  _notifyProviderRefresh();
}

/// 立即更新本地應徵狀態
void _updateApplicationStatusLocally(Map<String, dynamic> data) {
  setState(() {
    if (_task != null) {
      _task!['application'] = {
        'status': applicationStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  });
}
```

## 🎨 **視覺設計特色**

### **雙角色適配設計**
- **Creator (發布者)**: 基於 `tasks.status_id` 的 Posted Tasks 配色
- **Participant (應徵者)**: 基於 `task_applications.status` 的 My Works 配色

### **進度視覺化**
- 線性進度條顯示任務完成百分比
- 動態顏色映射不同狀態階段
- 圓形圖標與狀態文字組合

### **玻璃擬態效果**
```dart
backgroundColor: _glassNavColor(context), // 玻璃導航顏色
```

## ⚡ **性能優化特點**

### **純局部更新策略**
- ❌ 移除全量刷新：不再呼叫 `_initializeChat()`
- ✅ 本地狀態立即更新：`setState()` 局部重繪
- ✅ 後台同步：`_notifyProviderRefresh()` 保持列表同步

### **智能倒數計時**
```dart
/// 更新衍生狀態（如倒數計時等）
void _updateDerivedStates() {
  final statusCode = _task!['status']?['code'];
  
  // 🕒 智能倒數計時控制
  if (statusCode == 'pending_confirmation') {
    _startCountdownIfNeeded();
  } else {
    _stopCountdown();
  }
}
```

## 🔧 **可擴展性設計**

### **動作配置擴展**
- 支援確認對話框：`withConfirmation()`
- 支援破壞性動作：`asDestructive()`
- 動態動作過濾：基於狀態、角色、封鎖等條件

### **狀態通知系統**
- 任務狀態變更通知
- 應徵狀態變更通知
- 封鎖狀態變更通知
- 統一的 SnackBar 通知機制

### **主題適配能力**
- 支援自定義配色方案
- 適配深色/淺色主題
- 響應系統主題變更

## 📊 **架構優勢**

### **✅ 優點**
1. **組件化設計**: 清晰的職責分離
2. **實時響應**: Socket 驅動的即時更新
3. **雙角色支持**: Creator/Participant 差異化體驗
4. **性能優化**: 局部更新策略
5. **擴展性強**: 易於添加新狀態和動作
6. **視覺一致**: 統一的配色和圖標系統

### **⚠️ 潛在改進空間**
1. **狀態管理複雜**: 多個狀態源（task status, application status）
2. **配置集中度**: ActionBarConfigManager 承載過多邏輯
3. **類型安全**: 部分動態類型轉換可能出錯
4. **測試覆蓋**: 複雜的狀態轉換邏輯需要更多測試

## 📈 **總結評估**

ChatDetailPage 的任務狀態 Bar 架構是一個**成熟、功能完整的系統**，具有以下特徵：

- 🏗️ **架構清晰**: 分層設計，職責明確
- ⚡ **響應迅速**: 實時更新，用戶體驗佳
- 🎨 **視覺豐富**: 多樣化的狀態表達
- 🔧 **高度可配**: 支援多角色、多狀態場景
- 📱 **移動優化**: 適合觸控操作

這個架構為任務狀態的可視化和交互提供了堅實的基礎，支撐了複雜的任務生命週期管理需求。
