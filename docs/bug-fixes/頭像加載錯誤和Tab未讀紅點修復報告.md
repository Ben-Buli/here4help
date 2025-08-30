# 頭像加載錯誤和 Tab 未讀紅點修復報告

## 🐛 問題描述

### **1. 頭像加載錯誤**
```
Build scheduled during frame.
While the widget tree was being built, laid out, and painted, a new frame was scheduled to rebuild the widget tree.
```

**錯誤現象**：
- 在 `posted_tasks_widget.dart:2553` 行出現 setState 調用錯誤
- 頭像加載失敗時在繪製過程中調用了 setState
- 導致界面卡頓和錯誤堆疊

### **2. Chat 頁面 Tab 未讀紅點**
用戶要求移除 Chat 頁面兩個 tab（Post 和 Explore）的未讀紅點標記。

## 🔍 問題分析

### **根本原因**

#### **1. setState 調用時機錯誤**
```dart
// 錯誤的代碼：在圖片加載錯誤回調中直接調用 setState
onBackgroundImageError: (exception, stackTrace) {
  AvatarErrorCache.addFailedUrl(avatarPath);
  if (mounted) {
    setState(() {  // ❌ 在繪製過程中調用 setState
      _hasError = true;
    });
  }
},
```

**問題**：在 `onBackgroundImageError` 回調中直接調用 `setState()`，這個回調在繪製過程中觸發，導致 "Build scheduled during frame" 錯誤。

#### **2. Tab 未讀紅點邏輯**
```dart
// 原來的代碼：顯示未讀紅點
Widget buildTabLabel(String text, bool showDot) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Text(text),
      if (showDot)
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  );
}
```

## 🔧 修復方案

### **1. 修復 setState 調用時機**

#### 修改檔案：`lib/chat/widgets/posted_tasks_widget.dart`

**執行內容**：
- 使用 `WidgetsBinding.instance.addPostFrameCallback` 延遲 setState 調用
- 確保 setState 在繪製完成後執行

**程式碼變更**：
```dart
// 修復前：直接調用 setState
onBackgroundImageError: (exception, stackTrace) {
  AvatarErrorCache.addFailedUrl(avatarPath);
  if (mounted) {
    setState(() {  // ❌ 在繪製過程中調用
      _hasError = true;
    });
  }
},

// 修復後：使用 addPostFrameCallback
onBackgroundImageError: (exception, stackTrace) {
  AvatarErrorCache.addFailedUrl(avatarPath);
  if (mounted) {
    // 使用 addPostFrameCallback 避免在繪製過程中調用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {  // ✅ 在繪製完成後調用
          _hasError = true;
        });
      }
    });
  }
},
```

### **2. 移除 Tab 未讀紅點**

#### 修改檔案：`lib/chat/widgets/chat_list_task_widget.dart`

**執行內容**：
- 移除未讀狀態檢查邏輯
- 簡化 tab 標籤構建函數
- 移除 Stack 和 Positioned 組件

**程式碼變更**：
```dart
// 修復前：包含未讀紅點的複雜邏輯
final chatProvider = Provider.of<ChatListProvider?>(context);
final bool postedHasUnread = chatProvider?.hasUnreadForTab(0) ?? false;
final bool worksHasUnread = chatProvider?.hasUnreadForTab(1) ?? false;

Widget buildTabLabel(String text, bool showDot) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Text(text),
      if (showDot)
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  );
}

// 修復後：簡化的 tab 標籤
// 移除未讀狀態檢查
// final chatProvider = Provider.of<ChatListProvider?>(context);
// final bool postedHasUnread = chatProvider?.hasUnreadForTab(0) ?? false;
// final bool worksHasUnread = chatProvider?.hasUnreadForTab(1) ?? false;

Widget buildTabLabel(String text) {
  return Text(text);  // ✅ 簡化的標籤，無未讀紅點
}

// Tab 使用
Tab(child: buildTabLabel('Post')),      // ✅ 移除 postedHasUnread 參數
Tab(child: buildTabLabel('Expolore')), // ✅ 移除 worksHasUnread 參數
```

## 📊 修復效果

### **功能改善**
- ✅ **解決 setState 錯誤**：頭像加載失敗時不再出現 "Build scheduled during frame" 錯誤
- ✅ **移除 Tab 未讀紅點**：Chat 頁面的 Post 和 Explore tab 不再顯示未讀紅點
- ✅ **改善用戶體驗**：界面更加簡潔，減少視覺干擾
- ✅ **提升性能**：避免在繪製過程中調用 setState，減少界面卡頓

### **技術特點**
- ✅ **正確的 setState 時機**：使用 `addPostFrameCallback` 確保在繪製完成後調用
- ✅ **簡化的 UI 邏輯**：移除複雜的未讀狀態檢查和紅點顯示邏輯
- ✅ **更好的錯誤處理**：頭像加載錯誤時有更好的錯誤處理機制
- ✅ **代碼簡化**：移除不必要的 Provider 依賴和狀態檢查

### **性能提升**
- ✅ **減少重繪**：避免在繪製過程中觸發新的 frame
- ✅ **降低複雜度**：簡化 tab 標籤的渲染邏輯
- ✅ **減少依賴**：移除對 ChatListProvider 的依賴

## 🎯 技術要點

### **1. setState 調用時機**
```dart
// 正確的做法：在繪製完成後調用 setState
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    setState(() {
      _hasError = true;
    });
  }
});

// 錯誤的做法：在繪製過程中調用 setState
setState(() {
  _hasError = true;
}); // 會導致 "Build scheduled during frame" 錯誤
```

### **2. UI 簡化**
```dart
// 簡化的 tab 標籤，無未讀紅點
Widget buildTabLabel(String text) {
  return Text(text);
}

// 複雜的 tab 標籤，包含未讀紅點
Widget buildTabLabel(String text, bool showDot) {
  return Stack(
    children: [
      Text(text),
      if (showDot) Positioned(...), // 未讀紅點
    ],
  );
}
```

### **3. 錯誤處理最佳實踐**
```dart
// 在圖片加載錯誤時的安全處理
onBackgroundImageError: (exception, stackTrace) {
  // 1. 記錄錯誤
  AvatarErrorCache.addFailedUrl(avatarPath);
  
  // 2. 延遲更新 UI
  if (mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }
},
```

## 📝 總結

通過以下修復，成功解決了頭像加載錯誤和 Tab 未讀紅點問題：

1. **修復 setState 調用時機**：使用 `addPostFrameCallback` 確保在繪製完成後調用 setState
2. **移除 Tab 未讀紅點**：簡化 tab 標籤邏輯，移除未讀狀態檢查
3. **改善錯誤處理**：提供更好的頭像加載錯誤處理機制

修復後的應用具有以下優勢：
- **穩定性**：不再出現 "Build scheduled during frame" 錯誤
- **簡潔性**：Chat 頁面 tab 更加簡潔，無未讀紅點干擾
- **性能**：減少不必要的重繪和複雜的 UI 邏輯
- **用戶體驗**：界面更加流暢，減少視覺干擾

這個修復確保了應用的穩定性和用戶體驗，同時簡化了 UI 邏輯。
