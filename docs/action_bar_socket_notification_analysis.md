# Action Bar 功能 Socket 通知狀況分析

## 📊 現有功能 Socket 通知狀況

### ✅ **已有 Socket 通知的功能**

#### 1. **Accept 接受應徵** (`accept.php`)
- ✅ **任務狀態更新**: `task_status_update` (open → in_progress)
- ✅ **應徵狀態更新**: `application_status_update` (applied → accepted)
- ✅ **通知對象**: 任務創建者 + 應徵者
- ✅ **實現完整**: 使用 SocketNotifier 類別

#### 2. **Confirm 確認完成** (`confirm_completion.php`)
- ✅ **任務狀態更新**: `task_status_update` (pending_confirmation → completed)
- ✅ **通知對象**: 任務創建者 + 執行者
- ✅ **實現完整**: 使用 SocketNotifier 類別

#### 3. **Block 封鎖用戶** (`block_user.php`)
- ✅ **封鎖狀態更新**: `block_status_update`
- ✅ **通知對象**: 封鎖方 + 被封鎖方
- ✅ **實現完整**: 直接使用 cURL 發送通知

### ❌ **缺少 Socket 通知的功能**

#### 1. **Withdraw 撤銷應徵** (`applications/update-status.php`)
- ❌ **缺少通知**: 撤銷後對方不知道狀態變化
- 🔄 **影響**: 任務創建者看不到應徵者撤銷，Action Bar 不會更新

#### 2. **Disagree 不同意完成** (`disagree_completion.php`)
- ❌ **缺少通知**: 狀態回退 (pending_confirmation → in_progress)
- 🔄 **影響**: 執行者不知道被拒絕，Action Bar 顯示錯誤狀態

#### 3. **Complete 標記完成** (`update.php`)
- ❌ **缺少通知**: 狀態變更 (in_progress → pending_confirmation)
- 🔄 **影響**: 任務創建者不知道執行者已標記完成

#### 4. **Pay 付款** (`pay_and_review.php`)
- ❌ **缺少通知**: 付款後狀態可能變化
- 🔄 **影響**: 執行者不知道已收到付款

#### 5. **Dispute 爭議處理** (`dispute.php`)
- ❌ **缺少通知**: 爭議狀態變更
- 🔄 **影響**: 雙方不知道爭議狀態變化

#### 6. **Reject 拒絕應徵** (`applications/reject.php`)
- ❌ **缺少通知**: 拒絕應徵狀態變更
- 🔄 **影響**: 應徵者不知道被拒絕

## 🔧 調整建議

### **階段一：修復 SocketNotifier 類別**

#### **1. 修復語法錯誤**
```php
// 修復 notifyApplicationStatusUpdate 方法中的語法錯誤
public function notifyApplicationStatusUpdate($taskId, $roomId, $applicationStatus, $userIds = []) {
    $eventData = [  // 缺少這一行
        'event' => 'application_status_update',
        'data' => [
            'task_id' => $taskId,
            'room_id' => $roomId,
            'application_status' => $applicationStatus,
            'timestamp' => date('Y-m-d H:i:s'),
        ]
    ];
    
    $this->sendSocketEvent($eventData, $userIds);
}
```

### **階段二：為缺少通知的功能添加 Socket 通知**

#### **1. Withdraw 撤銷應徵**
```php
// 在 applications/update-status.php 中添加
if ($newStatus === 'withdrawn') {
    try {
        $socketNotifier = SocketNotifier::getInstance();
        $userIds = $socketNotifier->getTaskUserIds($application['task_id']);
        $room = $db->fetch("SELECT id FROM chat_rooms WHERE task_id = ?", [$application['task_id']]);
        $roomId = $room ? $room['id'] : null;
        
        $socketNotifier->notifyApplicationStatusUpdate(
            $application['task_id'], 
            $roomId, 
            'withdrawn', 
            $userIds
        );
    } catch (Exception $e) {
        error_log("Socket notification failed: " . $e->getMessage());
    }
}
```

#### **2. Disagree 不同意完成**
```php
// 在 disagree_completion.php 中添加
try {
    $socketNotifier = SocketNotifier::getInstance();
    $userIds = $socketNotifier->getTaskUserIds($task_id);
    $room = $db->fetch("SELECT id FROM chat_rooms WHERE task_id = ?", [$task_id]);
    $roomId = $room ? $room['id'] : null;
    
    $statusData = [
        'code' => 'in_progress',
        'display_name' => 'In Progress',
        'progress_ratio' => 0.5
    ];
    
    $socketNotifier->notifyTaskStatusUpdate($task_id, $roomId, $statusData, $userIds);
} catch (Exception $e) {
    error_log("Socket notification failed: " . $e->getMessage());
}
```

#### **3. Complete 標記完成**
```php
// 在 update.php 中添加（當狀態更新為 pending_confirmation 時）
if ($statusId !== null && $statusId == 3) { // pending_confirmation
    try {
        $socketNotifier = SocketNotifier::getInstance();
        $userIds = $socketNotifier->getTaskUserIds($taskId);
        $room = $db->fetch("SELECT id FROM chat_rooms WHERE task_id = ?", [$taskId]);
        $roomId = $room ? $room['id'] : null;
        
        $statusData = [
            'code' => 'pending_confirmation',
            'display_name' => 'Pending Confirmation',
            'progress_ratio' => 0.8
        ];
        
        $socketNotifier->notifyTaskStatusUpdate($taskId, $roomId, $statusData, $userIds);
    } catch (Exception $e) {
        error_log("Socket notification failed: " . $e->getMessage());
    }
}
```

#### **4. Reject 拒絕應徵**
```php
// 在 applications/reject.php 中添加
try {
    $socketNotifier = SocketNotifier::getInstance();
    $userIds = $socketNotifier->getTaskUserIds($taskId);
    $room = $db->fetch("SELECT id FROM chat_rooms WHERE task_id = ?", [$taskId]);
    $roomId = $room ? $room['id'] : null;
    
    $socketNotifier->notifyApplicationStatusUpdate($taskId, $roomId, 'rejected', $userIds);
} catch (Exception $e) {
    error_log("Socket notification failed: " . $e->getMessage());
}
```

### **階段三：統一 Socket 通知模式**

#### **1. 創建統一的通知助手方法**
```php
// 在 SocketNotifier 中添加
public function notifyTaskAndApplicationUpdate($taskId, $taskStatusData = null, $applicationStatus = null) {
    try {
        $userIds = $this->getTaskUserIds($taskId);
        $room = Database::getInstance()->fetch("SELECT id FROM chat_rooms WHERE task_id = ? ORDER BY id DESC LIMIT 1", [$taskId]);
        $roomId = $room ? $room['id'] : null;
        
        if ($taskStatusData) {
            $this->notifyTaskStatusUpdate($taskId, $roomId, $taskStatusData, $userIds);
        }
        
        if ($applicationStatus) {
            $this->notifyApplicationStatusUpdate($taskId, $roomId, $applicationStatus, $userIds);
        }
    } catch (Exception $e) {
        error_log("Socket notification failed: " . $e->getMessage());
    }
}
```

#### **2. 標準化通知調用**
```php
// 統一的調用方式
$socketNotifier = SocketNotifier::getInstance();
$socketNotifier->notifyTaskAndApplicationUpdate(
    $taskId,
    ['code' => 'completed', 'display_name' => 'Completed', 'progress_ratio' => 1.0],
    'completed'
);
```

## 🎯 實現優先級

### **高優先級（立即修復）**
1. **修復 SocketNotifier 語法錯誤**
2. **Withdraw 撤銷應徵通知**
3. **Disagree 不同意完成通知**
4. **Complete 標記完成通知**

### **中優先級（後續實現）**
1. **Reject 拒絕應徵通知**
2. **Pay 付款通知**
3. **Dispute 爭議處理通知**

### **低優先級（優化）**
1. **統一通知模式**
2. **錯誤處理改進**
3. **通知重試機制**

## 📋 測試場景

### **1. Withdraw 撤銷應徵**
- 應徵者撤銷應徵 → 任務創建者立即看到 Action Bar 更新
- Accept 按鈕消失，應徵者卡片從 Posted 分頁移除

### **2. Disagree 不同意完成**
- 任務創建者不同意完成 → 執行者立即看到狀態回退
- Action Bar 從 "等待確認" 變回 "進行中" 狀態

### **3. Complete 標記完成**
- 執行者標記完成 → 任務創建者立即看到 "待確認" 狀態
- Action Bar 顯示 Confirm/Disagree 按鈕

## 🔧 技術實現要點

### **1. 錯誤處理**
- 所有 Socket 通知都應該有 try-catch 包裝
- 通知失敗不應該影響主要業務邏輯
- 記錄詳細的錯誤日誌

### **2. 性能考慮**
- Socket 通知應該異步執行
- 避免阻塞主要 API 響應
- 考慮使用隊列系統處理大量通知

### **3. 一致性保證**
- 確保狀態更新和通知的原子性
- 使用資料庫事務包裝相關操作
- 通知失敗時的補償機制

這個分析顯示了當前 Action Bar 功能中 Socket 通知的缺失情況，以及具體的修復建議。優先修復高影響的功能可以顯著改善用戶體驗。
