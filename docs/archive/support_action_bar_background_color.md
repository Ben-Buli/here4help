# Support Action Bar 背景顏色優化

## 修改概述

將客服聊天室的 Action Bar 背景顏色改為根據客服事件狀態動態顯示，與任務聊天室的狀態背景色保持一致的設計風格。

## 修改內容

### 1. 修改 `SupportDynamicActionBar._getBackgroundColor()` 方法

**文件**: `lib/chat/widgets/support_dynamic_action_bar.dart`

**修改前**:
```dart
Color _getBackgroundColor(BuildContext context) {
  if (backgroundColor != null) {
    return backgroundColor!;
  }

  final theme = Theme.of(context);
  final appBarTheme = theme.appBarTheme;

  if (appBarTheme.backgroundColor != null) {
    return appBarTheme.backgroundColor!.withOpacity(0.8);
  }

  return theme.colorScheme.surface.withOpacity(0.8);
}
```

**修改後**:
```dart
Color _getBackgroundColor(BuildContext context) {
  if (backgroundColor != null) {
    return backgroundColor!;
  }

  // 根據客服狀態獲取對應的背景色
  if (supportStatus != null) {
    final statusColor = SupportActionBarConfigManager.getSupportStatusColor(supportStatus);
    return statusColor.withOpacity(0.3); // 使用狀態顏色但降低透明度以保持玻璃效果
  }

  final theme = Theme.of(context);
  final appBarTheme = theme.appBarTheme;

  if (appBarTheme.backgroundColor != null) {
    return appBarTheme.backgroundColor!.withOpacity(0.8);
  }

  return theme.colorScheme.surface.withOpacity(0.8);
}
```

### 2. 修改 `SupportActionBarBuilder.build()` 方法

**修改前**:
```dart
color: backgroundColor ??
    Theme.of(context).colorScheme.surface.withOpacity(0.8),
```

**修改後**:
```dart
color: backgroundColor ?? _getSupportStatusBackgroundColor(context, supportStatus),
```

### 3. 新增靜態方法 `_getSupportStatusBackgroundColor()`

```dart
/// 根據客服狀態獲取背景顏色的靜態方法
static Color _getSupportStatusBackgroundColor(BuildContext context, SupportStatus? supportStatus) {
  if (supportStatus != null) {
    final statusColor = SupportActionBarConfigManager.getSupportStatusColor(supportStatus);
    return statusColor.withOpacity(0.3); // 使用狀態顏色但降低透明度以保持玻璃效果
  }

  return Theme.of(context).colorScheme.surface.withOpacity(0.8);
}
```

## 客服狀態顏色配置

根據 `SupportActionBarConfigManager.getSupportStatusColor()` 的配置：

| 狀態 | 顏色 | 說明 |
|------|------|------|
| `submitted` | `Colors.blue` | 藍色 - 已提交 |
| `in_progress` | `Colors.orange` | 橙色 - 進行中 |
| `resolved` | `Colors.green` | 綠色 - 已解決 |
| `null` | `Colors.grey` | 灰色 - 未知狀態 |

## 視覺效果

### 背景色透明度設置
- **狀態背景色**: `statusColor.withOpacity(0.3)` - 30% 透明度
- **預設背景色**: `surface.withOpacity(0.8)` - 80% 透明度

### 玻璃效果保持
- 使用 `BackdropFilter` 與 `ImageFilter.blur(sigmaX: 16, sigmaY: 16)`
- 保持毛玻璃效果的同時顯示狀態相關的背景色

## 使用範例

```dart
SupportDynamicActionBar(
  supportStatus: SupportStatus.inProgress, // 將顯示橙色背景
  userRole: UserRole.creator,
  actionCallbacks: {
    'close': () => _closeSupportCase(),
  },
  showStatusBar: true,
)
```

## 效果預覽

- **已提交 (submitted)**: 淡藍色背景 (藍色 30% 透明度)
- **進行中 (in_progress)**: 淡橙色背景 (橙色 30% 透明度)  
- **已解決 (resolved)**: 淡綠色背景 (綠色 30% 透明度)
- **未知狀態**: 預設主題背景色

這樣的設計讓客服聊天室的 Action Bar 與任務聊天室保持一致的視覺風格，用戶可以通過背景色快速識別當前客服事件的狀態。
