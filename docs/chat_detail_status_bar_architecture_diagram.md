# ChatDetailPage 任務狀態 Bar 架構圖

## 🏗️ **系統架構總覽**

```
┌─────────────────────────────────────────────────────────────────┐
│                        ChatDetailPage                           │
├─────────────────────────────────────────────────────────────────┤
│  🏠 Main UI Container                                           │
│                                                                 │
│  ├── 💬 Messages List (ListView)                               │
│  ├── ➖ Divider                                                │
│  └── 📱 Action Bar Area                                        │
│      │                                                          │
│      ├── [if _isSupportRoom]                                   │
│      │   └── 🛠️ _buildSupportActionBar()                      │
│      │                                                          │
│      └── [else: Normal Task Room]                              │
│          └── 🎯 DynamicActionBar                               │
│              ├── 📊 StatusBar (_buildStatusBar)                │
│              └── 🔘 ActionBar (_buildActionBar)                │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 **DynamicActionBar 組件結構**

```
┌─────────────────────────────────────────────────────────────────┐
│                      DynamicActionBar                          │
├─────────────────────────────────────────────────────────────────┤
│  🏗️ Widget Parameters:                                         │
│    • TaskStatus taskStatus         (任務狀態枚舉)              │
│    • UserRole userRole            (用戶角色枚舉)               │
│    • String? applicationStatus    (應徵狀態字串)               │
│    • Map<String, VoidCallback> actionCallbacks                 │
│    • bool showStatusBar           (是否顯示狀態條)             │
│    • String? statusDisplayName    (狀態顯示名稱)              │
│    • double? progressRatio        (進度比例 0.0-1.0)          │
│    • String? colorScheme          ('posted_tasks'|'my_works') │
│    • bool isBlocked, isBlockedByMe, isBlockedByTarget         │
│    • bool hasExistingReview                                    │
├─────────────────────────────────────────────────────────────────┤
│  📊 StatusBar Section (if showStatusBar == true):              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  🎨 Container(                                             ││
│  │    decoration: statusColor.withOpacity(0.1),               ││
│  │    child: Row(                                              ││
│  │      children: [                                            ││
│  │        🔵 Icon(statusIcon, color: statusColor),            ││
│  │        📝 Text(statusDisplayName),                         ││
│  │        📊 [if progressRatio > 0] LinearProgressIndicator() ││
│  │      ]                                                      ││
│  │    )                                                        ││
│  │  )                                                          ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│  🔘 ActionBar Section:                                         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  🔄 Dynamic Button Generation:                             ││
│  │    ActionBarConfigManager.getActionsForStatus()            ││
│  │    ↓                                                        ││
│  │  🔘🔘🔘 [Accept] [Reject] [Block] [Report] ...            ││
│  │                                                             ││
│  │  Each Button = ActionBarAction {                            ││
│  │    • String id                                              ││
│  │    • String label                                           ││
│  │    • IconData icon                                          ││
│  │    • VoidCallback onTap                                     ││
│  │    • Color? backgroundColor, foregroundColor                ││
│  │    • bool isDestructive, requiresConfirmation              ││
│  │  }                                                          ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## ⚙️ **ActionBarConfigManager 邏輯流程**

```
┌─────────────────────────────────────────────────────────────────┐
│                 ActionBarConfigManager                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📥 Input Parameters:                                           │
│    ├── TaskStatus (enum)                                        │
│    ├── UserRole (enum)                                          │
│    ├── applicationStatus (string?)                              │
│    ├── isBlocked, isBlockedByMe, isBlockedByTarget (bool)       │
│    └── hasExistingReview (bool)                                 │
│                                                                 │
│  🔄 Processing Flow:                                            │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  switch (TaskStatus) {                                      ││
│  │                                                             ││
│  │    case TaskStatus.open:                                    ││
│  │      if (UserRole.creator) {                                ││
│  │        🟢 Add "Accept" button                               ││
│  │        🔴 Add "Reject" button                               ││
│  │        🚫 Add "Block" button (if !isBlocked)               ││
│  │      } else if (UserRole.participant) {                     ││
│  │        🔄 Add "Withdraw" button                             ││
│  │      }                                                       ││
│  │                                                             ││
│  │    case TaskStatus.inProgress:                              ││
│  │      if (UserRole.creator) {                                ││
│  │        ⏰ Add "Remind" button                               ││
│  │      } else if (UserRole.participant) {                     ││
│  │        ✅ Add "Complete" button                             ││
│  │      }                                                       ││
│  │                                                             ││
│  │    case TaskStatus.pendingConfirmation:                     ││
│  │      if (UserRole.creator) {                                ││
│  │        ✅ Add "Confirm" button                              ││
│  │        🚨 Add "Dispute" button                              ││
│  │      }                                                       ││
│  │                                                             ││
│  │    case TaskStatus.completed:                               ││
│  │      ⭐ Add "Review" button (if !hasExistingReview)         ││
│  │      📊 Add "Report" button                                 ││
│  │                                                             ││
│  │    // ... other status cases                                ││
│  │  }                                                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  📤 Output:                                                     │
│    └── List<ActionBarAction> actions                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 **實時更新資料流**

```
┌─────────────┐    📡 Socket    ┌─────────────────┐    🔄 Local    ┌─────────────────┐
│   Backend   │ ──────────────► │  SocketService  │ ─────────────► │  ChatDetailPage │
│             │   Events        │                 │   Callbacks    │                 │
└─────────────┘                 └─────────────────┘                 └─────────────────┘
                                                                               │
┌─────────────────────────────────────────────────────────────────────────────┘
│
▼ Event Processing Flow:

📋 task_status_update Event:
├── _onTaskStatusUpdate(data)
│   ├── 🔍 Check: roomId == _currentRoomId?
│   ├── ⚡ _updateTaskStatusLocally(data)
│   │   └── setState(() => _task!['status'] = newStatus)
│   ├── 📢 _showTaskStatusChangeNotification()
│   └── 🔄 _notifyProviderRefresh()
│
📝 application_status_update Event:
├── _onApplicationStatusUpdate(data)
│   ├── 🔍 Check: roomId == _currentRoomId?
│   ├── ⚡ _updateApplicationStatusLocally(data)
│   │   └── setState(() => _task!['application']['status'] = newStatus)
│   ├── 📢 _showApplicationStatusChangeNotification()
│   └── 🔄 _notifyProviderRefresh()
│
🚫 block_status_update Event:
├── _onBlockStatusUpdate(data)
│   ├── 🔍 Check: involves current users?
│   ├── ⚡ Update _isBlocked, _isBlockedByMe, _isBlockedByTarget
│   ├── 📢 Show block status notification
│   └── 🔄 _notifyProviderRefresh()
```

## 🎨 **視覺狀態對應表**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Status Visual Mapping                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TaskStatus.open:                                               │
│    🔵 Color: Colors.blue                                        │
│    📅 Icon: Icons.schedule                                       │
│    📊 Progress: 0% (開放申請階段)                                │
│                                                                 │
│  TaskStatus.inProgress:                                         │
│    🟠 Color: Colors.orange                                      │
│    🔨 Icon: Icons.work                                          │
│    📊 Progress: 25-75% (執行中)                                 │
│                                                                 │
│  TaskStatus.pendingConfirmation:                                │
│    🟡 Color: Colors.amber                                       │
│    ⏳ Icon: Icons.hourglass_empty                               │
│    📊 Progress: 85-95% (等待確認)                               │
│    ⏰ Special: Countdown Timer Active                           │
│                                                                 │
│  TaskStatus.completed:                                          │
│    🟢 Color: Colors.green                                       │
│    ✅ Icon: Icons.check_circle                                  │
│    📊 Progress: 100% (完成)                                     │
│                                                                 │
│  TaskStatus.dispute:                                            │
│    🔴 Color: Colors.red                                         │
│    ⚠️ Icon: Icons.warning                                      │
│    📊 Progress: Variable (糾紛狀態)                             │
│                                                                 │
│  TaskStatus.cancelled / rejected:                               │
│    ⚫ Color: Colors.grey                                        │
│    ❌ Icon: Icons.cancel                                        │
│    📊 Progress: 0% (終止狀態)                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🔀 **雙角色差異化顯示**

```
┌─────────────────────┬─────────────────────────────────────────────┐
│    User Role        │                Display Logic                │
├─────────────────────┼─────────────────────────────────────────────┤
│                     │                                             │
│  👑 Creator         │  📋 Status Source: _task['status']         │
│  (任務發布者)         │      • display_name: 任務狀態顯示名稱        │
│                     │      • code: 任務狀態代碼                   │
│                     │                                             │
│                     │  🎨 Color Scheme: 'posted_tasks'           │
│                     │      • 基於 tasks.status_id 的配色         │
│                     │      • Posted Tasks 分頁風格               │
│                     │                                             │
│                     │  🔘 Available Actions:                     │
│                     │      • Accept (接受應徵)                   │
│                     │      • Reject (拒絕應徵)                   │
│                     │      • Confirm Completion (確認完成)        │
│                     │      • Report Issue (舉報問題)              │
│                     │                                             │
├─────────────────────┼─────────────────────────────────────────────┤
│                     │                                             │
│  👷 Participant     │  📝 Status Source: _task['application']    │
│  (任務應徵者)         │      • status: 應徵狀態 (applied/accepted) │
│                     │      • ApplicationStatusUtils.getDisplayName│
│                     │                                             │
│                     │  🎨 Color Scheme: 'my_works'               │
│                     │      • 基於 task_applications.status 配色  │
│                     │      • My Works 分頁風格                   │
│                     │                                             │
│                     │  🔘 Available Actions:                     │
│                     │      • Withdraw (撤回應徵)                 │
│                     │      • Complete Task (完成任務)            │
│                     │      • Submit Review (提交評價)            │
│                     │      • Request Help (請求幫助)              │
│                     │                                             │
└─────────────────────┴─────────────────────────────────────────────┘
```

## 📊 **狀態轉換生命週期**

```
                    任務生命週期狀態轉換圖
                    
    🟢 START
       │
       ▼
┌─────────────┐     Apply      ┌─────────────┐     Accept     ┌─────────────┐
│    Open     │ ─────────────► │  (Applied)  │ ─────────────► │ In Progress │
│   開放中     │                │             │                │   進行中     │
└─────────────┘                └─────────────┘                └─────────────┘
       │                              │                               │
       │ Reject                       │ Withdraw                      │ Complete
       ▼                              ▼                               ▼
┌─────────────┐                ┌─────────────┐                ┌─────────────┐
│   Rejected  │                │ Withdrawn   │                │  Pending    │
│    已拒絕    │                │   已撤回     │                │Confirmation │
└─────────────┘                └─────────────┘                │   待確認     │
                                                              └─────────────┘
                                                                     │
                                                          Confirm    │    Dispute
                                                                     ▼
┌─────────────┐                                            ┌─────────────┐
│  Completed  │ ◄─────────────────────────────────────────── │   Dispute   │
│    已完成    │                                            │    糾紛中    │
└─────────────┘                                            └─────────────┘
                                                                     │
                                                                     │ Cancel
                                                                     ▼
                                                            ┌─────────────┐
                                                            │  Cancelled  │
                                                            │   已取消     │
                                                            └─────────────┘
```

這個架構圖完整地展示了 ChatDetailPage 任務狀態 Bar 的系統設計，包括組件結構、資料流向、視覺映射和狀態轉換等關鍵方面。
