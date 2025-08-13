# 任務狀態管理系統優化分析

> 生成日期：2025-01-18  
> 分析目標：優化基於 `task_statuses` 表的狀態管理系統

---

## 📊 當前狀態管理架構分析

### 🗄️ 資料庫設計（已優化）
```sql
-- task_statuses 表結構
CREATE TABLE task_statuses (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,        -- 程式使用的代號
  display_name VARCHAR(128) NOT NULL,      -- 顯示名稱
  progress_ratio DECIMAL(3,2) DEFAULT 0.00, -- 進度比例
  sort_order INT DEFAULT 0,                -- 排序權重
  include_in_unread TINYINT(1) DEFAULT 1,  -- 是否計入未讀
  is_active TINYINT(1) DEFAULT 1,          -- 是否啟用
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- tasks 表關聯
ALTER TABLE tasks ADD COLUMN status_id INT,
ADD FOREIGN KEY (status_id) REFERENCES task_statuses(id);
```

### 📱 前端硬編碼問題
當前 `lib/constants/task_status.dart` 存在大量硬編碼：

```dart
// ❌ 問題：硬編碼狀態映射
static const Map<String, String> statusString = {
  'open': 'Open',
  'in_progress': 'In Progress',
  'pending_confirmation': 'Pending Confirmation',
  // ... 更多硬編碼
};

// ❌ 問題：硬編碼進度映射
static const Map<String, double> statusProgressMap = {
  'Open': 0.0,
  'In Progress': 0.25,
  // ... 更多硬編碼
};
```

---

## 🎯 優化方案設計

### 1. 後端 API 服務

#### 建立狀態管理 API
```php
// backend/api/tasks/statuses.php
<?php
header('Content-Type: application/json');
require_once '../../config/database.php';

class TaskStatusAPI {
    private $db;
    
    public function __construct() {
        $this->db = Database::getInstance();
    }
    
    // 獲取所有啟用狀態
    public function getAllStatuses() {
        $sql = "SELECT * FROM task_statuses WHERE is_active = 1 ORDER BY sort_order";
        return $this->db->fetchAll($sql);
    }
    
    // 根據代號獲取狀態
    public function getStatusByCode($code) {
        $sql = "SELECT * FROM task_statuses WHERE code = ? AND is_active = 1";
        return $this->db->fetch($sql, [$code]);
    }
    
    // 獲取狀態映射表（前端優化用）
    public function getStatusMappings() {
        $statuses = $this->getAllStatuses();
        return [
            'codeToDisplay' => array_column($statuses, 'display_name', 'code'),
            'codeToProgress' => array_column($statuses, 'progress_ratio', 'code'),
            'codeToOrder' => array_column($statuses, 'sort_order', 'code'),
            'statusList' => $statuses
        ];
    }
}
```

### 2. 前端服務層重構

#### 建立狀態服務類
```dart
// lib/services/task_status_service.dart
class TaskStatusService {
  static TaskStatusService? _instance;
  static TaskStatusService get instance => _instance ??= TaskStatusService._();
  TaskStatusService._();
  
  Map<String, TaskStatusModel>? _statusCache;
  Map<String, String>? _codeToDisplayCache;
  Map<String, double>? _codeToProgressCache;
  
  // 從 API 載入狀態資料
  Future<void> loadStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/tasks/statuses.php')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _buildCaches(data['statusList']);
      }
    } catch (e) {
      // 載入失敗時使用預設映射
      _buildDefaultCaches();
    }
  }
  
  // 建立快取映射
  void _buildCaches(List<dynamic> statusList) {
    _statusCache = {};
    _codeToDisplayCache = {};
    _codeToProgressCache = {};
    
    for (var status in statusList) {
      final model = TaskStatusModel.fromJson(status);
      _statusCache![status['code']] = model;
      _codeToDisplayCache![status['code']] = status['display_name'];
      _codeToProgressCache![status['code']] = status['progress_ratio'];
    }
  }
  
  // 獲取顯示名稱
  String getDisplayName(String code) {
    return _codeToDisplayCache?[code] ?? code;
  }
  
  // 獲取進度比例
  double? getProgressRatio(String code) {
    return _codeToProgressCache?[code];
  }
  
  // 獲取完整狀態資訊
  TaskStatusModel? getStatus(String code) {
    return _statusCache?[code];
  }
}
```

#### 狀態資料模型
```dart
// lib/models/task_status_model.dart
class TaskStatusModel {
  final int id;
  final String code;
  final String displayName;
  final double progressRatio;
  final int sortOrder;
  final bool includeInUnread;
  final bool isActive;
  
  const TaskStatusModel({
    required this.id,
    required this.code,
    required this.displayName,
    required this.progressRatio,
    required this.sortOrder,
    required this.includeInUnread,
    required this.isActive,
  });
  
  factory TaskStatusModel.fromJson(Map<String, dynamic> json) {
    return TaskStatusModel(
      id: json['id'],
      code: json['code'],
      displayName: json['display_name'],
      progressRatio: (json['progress_ratio'] as num).toDouble(),
      sortOrder: json['sort_order'],
      includeInUnread: json['include_in_unread'] == 1,
      isActive: json['is_active'] == 1,
    );
  }
}
```

### 3. UI 元件重構

#### 重構狀態常量類
```dart
// lib/constants/task_status.dart (重構版)
class TaskStatus {
  // 移除硬編碼，改為動態獲取
  static String getDisplayStatus(String code) {
    return TaskStatusService.instance.getDisplayName(code);
  }
  
  static Map<String, dynamic> getProgressData(String code) {
    final progress = TaskStatusService.instance.getProgressRatio(code);
    return {'progress': progress};
  }
  
  static TaskStatusModel? getStatus(String code) {
    return TaskStatusService.instance.getStatus(code);
  }
  
  // 保留主題色彩邏輯，但使用動態狀態
  static Map<String, ({double intensity, Color fg, Color bg})> themedColors(
      ColorScheme scheme) {
    final statuses = TaskStatusService.instance._statusCache ?? {};
    final themedColors = <String, ({double intensity, Color fg, Color bg})>{};
    
    for (var status in statuses.values) {
      themedColors[status.displayName] = _getColorForStatus(status, scheme);
    }
    
    return themedColors;
  }
  
  static ({double intensity, Color fg, Color bg}) _getColorForStatus(
      TaskStatusModel status, ColorScheme scheme) {
    // 根據狀態代號決定顏色主題
    Color baseColor;
    switch (status.code) {
      case 'open':
      case 'applying':
        baseColor = scheme.primary;
        break;
      case 'in_progress':
        baseColor = scheme.secondary;
        break;
      case 'pending_confirmation':
        baseColor = scheme.tertiary;
        break;
      case 'completed':
      case 'rejected':
        baseColor = scheme.surfaceContainerHighest;
        break;
      case 'dispute':
        baseColor = scheme.error;
        break;
      default:
        baseColor = scheme.primary;
    }
    
    return (
      intensity: status.progressRatio,
      fg: baseColor,
      bg: baseColor.withOpacity(0.12)
    );
  }
}
```

---

## 🔧 實施計劃

### Phase 1: 後端 API 建立
1. ✅ **資料庫已就緒**：`task_statuses` 表已建立
2. 🔄 **建立 API 端點**：`backend/api/tasks/statuses.php`
3. 🔄 **測試 API 回應**：確保資料格式正確

### Phase 2: 前端服務層
1. 🔄 **建立狀態服務**：`TaskStatusService` 
2. 🔄 **建立資料模型**：`TaskStatusModel`
3. 🔄 **載入初始化**：在 app 啟動時載入狀態

### Phase 3: UI 層重構
1. 🔄 **重構常量類**：移除硬編碼
2. 🔄 **更新元件**：使用新的狀態服務
3. 🔄 **測試相容性**：確保現有功能正常

### Phase 4: 優化和快取
1. 🔄 **本地快取**：使用 SharedPreferences 快取
2. 🔄 **離線支援**：載入失敗時的備用方案
3. 🔄 **效能優化**：減少 API 呼叫

---

## 🎯 預期效益

### 📈 維護性提升
- **集中管理**：所有狀態邏輯統一管理
- **動態更新**：無需重新發布即可調整狀態
- **一致性**：前後端狀態定義統一

### 🚀 擴展性增強
- **新增狀態**：僅需資料庫插入，無需程式碼變更
- **國際化支援**：可輕鬆支援多語言顯示
- **個性化**：可依用戶偏好調整狀態顯示

### 🛡️ 穩定性改善
- **減少硬編碼**：降低狀態不一致風險
- **類型安全**：強類型模型減少錯誤
- **備用方案**：API 失敗時的優雅降級

---

## ⚠️ 實施注意事項

### 🔴 風險點
1. **向後相容**：確保現有功能不受影響
2. **載入時機**：避免阻塞 UI 初始化
3. **錯誤處理**：API 失敗時的備用邏輯

### 🟡 測試重點
1. **狀態一致性**：前後端狀態定義一致
2. **效能影響**：載入時間和記憶體使用
3. **離線行為**：網路異常時的表現

### 🟢 優化機會
1. **預載入**：在啟動畫面時載入狀態
2. **增量更新**：僅更新變更的狀態
3. **智能快取**：根據使用頻率調整快取策略

---

> 💡 **建議**：先實施 Phase 1 和 Phase 2，建立基礎架構後再逐步重構現有程式碼，確保穩定性。