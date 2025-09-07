# Socket UI 更新機制優化方案

## 🎯 現有機制分析

### ✅ **已實現的功能**
- Socket 事件監聽：`task_status_update`, `application_status_update`, `block_status_update`
- 自動 UI 更新：接收事件後調用 `_initializeChat()` 重新載入數據
- 狀態同步：Action Bar 和 Task Status Alert Bar 自動顯示最新狀態

### 🔄 **現有更新流程**
```
後端狀態變更 → Socket 事件 → 前端監聽 → _initializeChat() → UI 更新
```

## 🚀 **優化方案**

### **方案一：智能更新（推薦）**

#### **1. 增量更新機制**
```dart
// 在 chat_detail_page.dart 中優化
void _onTaskStatusUpdate(Map<String, dynamic> data) {
  final roomId = data['room_id']?.toString();
  final taskId = data['task_id']?.toString();
  
  if (roomId == _currentRoomId || taskId == _task?['id']?.toString()) {
    // 解析狀態數據
    final statusData = data['status'] as Map<String, dynamic>?;
    
    if (statusData != null) {
      // 🎯 直接更新狀態，避免完整重新載入
      _updateTaskStatusDirectly(statusData);
    } else {
      // 回退到完整重新載入
      _initializeChat();
    }
  }
}

void _updateTaskStatusDirectly(Map<String, dynamic> statusData) {
  setState(() {
    // 更新任務狀態
    if (_task != null) {
      _task!['status'] = statusData;
    }
    
    // 重新計算 Action Bar 配置
    _updateActionBarConfiguration();
    
    // 更新 Alert Bar 狀態
    _updateAlertBarStatus();
  });
  
  // 顯示狀態變更通知
  _showStatusChangeNotification(statusData);
}
```

#### **2. 應徵狀態增量更新**
```dart
void _onApplicationStatusUpdate(Map<String, dynamic> data) {
  final roomId = data['room_id']?.toString();
  final applicationStatus = data['application_status']?.toString();
  
  if (roomId == _currentRoomId && applicationStatus != null) {
    // 🎯 直接更新應徵狀態
    setState(() {
      _applicationStatus = applicationStatus;
      _updateActionBarConfiguration();
    });
    
    _showApplicationStatusChangeNotification(applicationStatus);
  }
}
```

#### **3. 狀態變更通知**
```dart
void _showStatusChangeNotification(Map<String, dynamic> statusData) {
  final statusName = statusData['display_name'] ?? 'Unknown';
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('任務狀態已更新為: $statusName'),
      duration: const Duration(seconds: 2),
      backgroundColor: Theme.of(context).colorScheme.primary,
    ),
  );
}
```

### **方案二：緩存優化**

#### **1. 選擇性數據更新**
```dart
Future<void> _initializeChatSelective({
  bool updateMessages = false,
  bool updateTaskStatus = true,
  bool updateUserInfo = false,
}) async {
  try {
    if (updateTaskStatus) {
      // 只更新任務和狀態相關數據
      await _loadTaskAndStatusData();
    }
    
    if (updateMessages) {
      await _loadChatMessages();
    }
    
    if (updateUserInfo) {
      await _loadUserInfo();
    }
    
    setState(() {
      _updateActionBarConfiguration();
    });
  } catch (e) {
    debugPrint('❌ 選擇性更新失敗: $e');
  }
}
```

#### **2. Socket 事件優化調用**
```dart
void _onTaskStatusUpdate(Map<String, dynamic> data) {
  if (_isRelevantUpdate(data)) {
    // 🎯 只更新必要的數據
    _initializeChatSelective(
      updateTaskStatus: true,
      updateMessages: false,
      updateUserInfo: false,
    );
  }
}
```

### **方案三：UI 響應性優化**

#### **1. 防抖機制**
```dart
Timer? _updateTimer;

void _onTaskStatusUpdate(Map<String, dynamic> data) {
  // 防止短時間內多次更新
  _updateTimer?.cancel();
  _updateTimer = Timer(const Duration(milliseconds: 300), () {
    if (_isRelevantUpdate(data)) {
      _initializeChat();
    }
  });
}
```

#### **2. 載入狀態指示**
```dart
bool _isUpdatingStatus = false;

void _onTaskStatusUpdate(Map<String, dynamic> data) {
  if (_isRelevantUpdate(data)) {
    setState(() {
      _isUpdatingStatus = true;
    });
    
    _initializeChat().then((_) {
      setState(() {
        _isUpdatingStatus = false;
      });
    });
  }
}
```

## 📊 **性能對比**

### **現有方案**
- ✅ 簡單可靠
- ❌ 完整重新載入，性能開銷較大
- ❌ 可能造成 UI 閃爍

### **優化方案一（智能更新）**
- ✅ 性能最佳，只更新必要部分
- ✅ 用戶體驗流暢
- ❌ 實現複雜度較高

### **優化方案二（緩存優化）**
- ✅ 平衡性能和複雜度
- ✅ 減少不必要的網絡請求
- ✅ 實現相對簡單

### **優化方案三（響應性優化）**
- ✅ 改善用戶體驗
- ✅ 防止重複更新
- ✅ 實現簡單

## 🎯 **實施建議**

### **階段一：立即可用（現有機制）**
- 現有的 `_initializeChat()` 機制已經可以工作
- 只需要為缺少的 API 添加 Socket 通知

### **階段二：性能優化**
- 實施方案二（緩存優化）
- 添加防抖機制
- 添加載入狀態指示

### **階段三：高級優化**
- 實施方案一（智能更新）
- 增量狀態更新
- 細粒度 UI 控制

## 🔧 **技術要點**

### **1. 事件過濾**
```dart
bool _isRelevantUpdate(Map<String, dynamic> data) {
  final roomId = data['room_id']?.toString();
  final taskId = data['task_id']?.toString();
  
  return roomId == _currentRoomId || taskId == _task?['id']?.toString();
}
```

### **2. 狀態一致性**
- 確保 Socket 事件和 API 響應的狀態一致
- 使用版本號或時間戳避免舊數據覆蓋新數據

### **3. 錯誤處理**
- Socket 更新失敗時回退到 API 重新載入
- 網絡異常時的優雅降級

### **4. 用戶反饋**
- 狀態變更時的視覺反饋
- 載入過程中的進度指示
- 錯誤狀態的友好提示

這個優化方案可以顯著改善用戶體驗，讓 Action Bar 和 Task Status Alert Bar 的更新更加流暢和即時。
