# 導航調試指南

## 當前修復狀態

### ✅ 已完成的修復
1. **路由匹配邏輯修復** - 避免 `/task` 和 `/task/create` 衝突
2. **路由順序調整** - 將 `/task/create` 放在 `/task` 之前
3. **導航方法優化** - 使用 `context.go` 替代 `context.push`
4. **調試信息添加** - 詳細的導航過程追蹤

### 🔧 當前配置
```dart
// shell_pages.dart 中的配置
{
  'path': '/task/create',  // 放在 /task 之前
  'child': const TaskCreatePage(),
  'title': 'Posting Task',
  'showBottomNav': true,
  'showBackArrow': true
},
{
  'path': '/task',
  'child': const TaskListPage(),
  'title': 'Task',
  'showBottomNav': true,
  'showBackArrow': true,
  'actionsBuilder': (context) => [
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        print('🔍 Edit Icon 被點擊，準備導航到 /task/create');
        print('🔍 當前路徑: ${GoRouterState.of(context).uri.path}');
        print('🔍 Context 是否可用: ${context.mounted}');
        print('🔍 嘗試導航...');
        
        context.go('/task/create');
        print('✅ context.go 執行完成');
      },
    ),
  ],
},
```

## 調試步驟

### 1. 檢查控制台輸出
當點擊 Edit Icon 時，應該看到以下輸出：
```
🔍 Edit Icon 被點擊，準備導航到 /task/create
🔍 當前路徑: /task
🔍 Context 是否可用: true
🔍 嘗試導航...
🔍 執行 context.go...
✅ context.go 執行完成
```

### 2. 檢查路由重定向
同時應該看到路由重定向的輸出：
```
🔄 路由重定向檢查: /task/create
👤 用戶狀態: 已登入 (user@example.com)
✅ 保持當前路由: /task/create
```

### 3. 如果仍然無法導航，嘗試以下方法

#### 方法1: 檢查用戶登入狀態
```dart
// 在 Edit Icon 的 onPressed 中添加
final prefs = await SharedPreferences.getInstance();
final email = prefs.getString('user_email');
print('🔍 用戶登入狀態: ${email != null ? "已登入" : "未登入"}');
```

#### 方法2: 嘗試不同的導航方法
```dart
// 在 onPressed 中嘗試
try {
  context.go('/task/create');
} catch (e) {
  print('❌ context.go 失敗: $e');
  try {
    context.push('/task/create');
  } catch (e2) {
    print('❌ context.push 也失敗: $e2');
  }
}
```

#### 方法3: 檢查路由配置
```dart
// 在 app_router.dart 中添加調試信息
print('🔍 當前路由配置: ${pageConfig['path']}');
print('🔍 路由標題: ${pageConfig['title']}');
```

## 可能的問題和解決方案

### 問題1: 路由重定向阻止導航
**症狀**: 控制台顯示重定向到登入頁面
**解決方案**: 確保用戶已登入，檢查 SharedPreferences 中的 user_email

### 問題2: 路由匹配失敗
**症狀**: 找不到對應的路由配置
**解決方案**: 檢查 shell_pages.dart 中的路由定義順序

### 問題3: Context 問題
**症狀**: Context 不可用或已銷毀
**解決方案**: 使用 Future.microtask 延遲執行

### 問題4: 頁面構建失敗
**症狀**: TaskCreatePage 構建時出錯
**解決方案**: 檢查 TaskCreatePage 的代碼是否有錯誤

## 測試建議

### 1. 基本功能測試
- [ ] 點擊 Edit Icon 時控制台有輸出
- [ ] 路由重定向邏輯正常工作
- [ ] 沒有構建錯誤

### 2. 導航測試
- [ ] 從 `/task` 成功導航到 `/task/create`
- [ ] 返回箭頭正常工作
- [ ] 底部導航欄狀態正確

### 3. 權限測試
- [ ] 已登入用戶可以正常導航
- [ ] 未登入用戶會被重定向到登入頁面

## 下一步調試

如果導航仍然失敗，請：

1. **檢查控制台輸出** - 查看是否有錯誤信息
2. **確認用戶登入狀態** - 確保不是權限問題
3. **測試其他路由** - 嘗試導航到其他頁面
4. **檢查 TaskCreatePage** - 確保頁面本身沒有問題

## 緊急解決方案

如果所有方法都失敗，可以嘗試：

```dart
// 在 Edit Icon 的 onPressed 中
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const TaskCreatePage(),
  ),
);
```

這會繞過 GoRouter，直接使用 Navigator 進行導航。

調試完成時間：2024年12月19日 