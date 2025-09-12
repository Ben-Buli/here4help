# 🎨 主題系統使用指南

## 📋 概述

本文檔說明如何使用 Here4Help 優化後的主題系統，包括如何從 `ThemeScheme` 使用顏色變數，以及如何與 Flutter 的 `Theme.of(context).colorScheme` 整合。

## 🔧 主題系統架構

### **優化後的主題檔案結構**

```
lib/constants/
├── theme_schemes_optimized.dart    # ✅ 優化後的主題系統（推薦使用）
└── theme_schemes.dart              # ❌ 舊版主題系統（建議逐步遷移）
```

### **主題數量對比**

| 版本 | 主題數量 | 檔案大小 | 維護性 |
|------|----------|----------|--------|
| **舊版** | 30+ 個 | 1659 行 | ❌ 困難 |
| **優化版** | 12 個 | ~600 行 | ✅ 良好 |

## 🎯 如何使用 ThemeScheme 顏色變數

### **1. 直接使用 ThemeScheme 顏色**

```dart
import 'package:here4help/constants/theme_schemes_optimized.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 使用特定主題的顏色
    final theme = ThemeScheme.morandiBlue;
    
    return Container(
      color: theme.primary,           // 主要顏色
      child: Text(
        'Hello World',
        style: TextStyle(
          color: theme.onPrimary,     // 主要顏色上的文字顏色
        ),
      ),
    );
  }
}
```

### **2. 動態主題切換**

```dart
class ThemeAwareWidget extends StatelessWidget {
  final ThemeScheme currentTheme;
  
  const ThemeAwareWidget({
    Key? key,
    required this.currentTheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: currentTheme.background,
        border: Border.all(
          color: currentTheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '標題',
            style: TextStyle(
              color: currentTheme.onBackground,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: currentTheme.primary,
              foregroundColor: currentTheme.onPrimary,
            ),
            child: Text('按鈕'),
          ),
        ],
      ),
    );
  }
}
```

### **3. 主題分類使用**

```dart
class ThemeCategoryWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 獲取所有莫蘭迪主題
    final morandiThemes = ThemeScheme.getByCategory('morandi');
    
    // 獲取所有分類
    final categories = ThemeScheme.getAllCategories();
    
    return Column(
      children: [
        // 顯示分類
        for (final category in categories)
          Text('分類: $category'),
        
        // 顯示莫蘭迪主題
        for (final theme in morandiThemes)
          Container(
            color: theme.primary,
            child: Text(
              theme.displayName,
              style: TextStyle(color: theme.onPrimary),
            ),
          ),
      ],
    );
  }
}
```

## 🔄 與 Theme.of(context).colorScheme 的整合

### **1. 使用 ThemeScheme 創建 Material Theme**

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 使用 ThemeScheme 創建 Material Theme
    final themeScheme = ThemeScheme.morandiBlue;
    
    return MaterialApp(
      theme: themeScheme.toThemeData(), // 轉換為 Material Theme
      home: MyHomePage(),
    );
  }
}
```

### **2. 混合使用兩種系統**

```dart
class HybridThemeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 獲取當前 Material Theme 的顏色
    final materialColors = Theme.of(context).colorScheme;
    
    // 獲取自定義主題的顏色
    final customTheme = ThemeScheme.morandiBlue;
    
    return Container(
      decoration: BoxDecoration(
        // 使用 Material Theme 的背景色
        color: materialColors.background,
        // 使用自定義主題的邊框色
        border: Border.all(
          color: customTheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // 使用 Material Theme 的文字顏色
          Text(
            'Material Theme 文字',
            style: TextStyle(
              color: materialColors.onBackground,
            ),
          ),
          // 使用自定義主題的按鈕顏色
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: customTheme.primary,
              foregroundColor: customTheme.onPrimary,
            ),
            child: Text('自定義主題按鈕'),
          ),
        ],
      ),
    );
  }
}
```

### **3. 主題感知組件**

```dart
class ThemeAwareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ThemeScheme? theme;
  
  const ThemeAwareButton({
    Key? key,
    this.onPressed,
    required this.child,
    this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 優先使用傳入的主題，否則使用 Material Theme
    final buttonTheme = theme ?? ThemeScheme.getByName('main_style');
    final materialColors = Theme.of(context).colorScheme;
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonTheme.primary,
        foregroundColor: buttonTheme.onPrimary,
        // 使用 Material Theme 的陰影
        elevation: materialColors.brightness == Brightness.light ? 2 : 0,
      ),
      child: child,
    );
  }
}
```

## 🎨 特殊效果使用

### **1. 背景模糊效果**

```dart
class BlurredWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScheme.glassmorphismBlur;
    
    return theme.createBlurredBackground(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Text(
          '模糊背景文字',
          style: TextStyle(
            color: theme.onBackground,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
```

### **2. 漸層背景效果**

```dart
class GradientWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScheme.beachSunset;
    
    return theme.createGradientBackground(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Text(
          '漸層背景文字',
          style: TextStyle(
            color: theme.onBackground,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
```

## 📱 實際應用範例

### **1. 登入頁面主題整合**

```dart
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 使用當前主題
    final currentTheme = ThemeScheme.morandiBlue;
    
    return Scaffold(
      backgroundColor: currentTheme.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // 標題
              Text(
                '歡迎回來',
                style: TextStyle(
                  color: currentTheme.onBackground,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: 30),
              
              // 輸入框
              Container(
                decoration: BoxDecoration(
                  color: currentTheme.inputBackground,
                  border: Border.all(
                    color: currentTheme.inputBorder,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '請輸入電子郵件',
                    hintStyle: TextStyle(
                      color: currentTheme.hintText,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  style: TextStyle(
                    color: currentTheme.onSurface,
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // 登入按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentTheme.primary,
                    foregroundColor: currentTheme.onPrimary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '登入',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### **2. 卡片組件主題整合**

```dart
class ThemedCard extends StatelessWidget {
  final String title;
  final String content;
  final ThemeScheme? theme;
  
  const ThemedCard({
    Key? key,
    required this.title,
    required this.content,
    this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 使用傳入的主題或預設主題
    final currentTheme = theme ?? ThemeScheme.mainStyle;
    
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentTheme.cardBackground,
        border: Border.all(
          color: currentTheme.cardBorder,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: currentTheme.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: currentTheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                color: currentTheme.onSurface.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🔍 最佳實踐建議

### **1. 主題選擇策略**

- **新開發**：使用 `ThemeScheme` 直接定義顏色
- **現有組件**：可以混合使用兩種系統
- **主題切換**：使用 `ThemeScheme.toThemeData()` 創建 Material Theme

### **2. 顏色使用原則**

- **主要互動元素**：使用 `primary` 和 `onPrimary`
- **次要元素**：使用 `secondary` 和 `onSecondary`
- **背景和表面**：使用 `background` 和 `surface`
- **文字顏色**：使用對應的 `on*` 顏色
- **狀態顏色**：使用 `error`、`success`、`warning`

### **3. 性能優化**

- **避免重複創建**：將主題實例保存為常量
- **使用 const 建構函數**：減少記憶體分配
- **主題快取**：在需要時快取主題實例

## 📚 遷移指南

### **從舊版主題系統遷移**

1. **替換 import**：
   ```dart
   // 舊版
   import 'package:here4help/constants/theme_schemes.dart';
   
   // 新版
   import 'package:here4help/constants/theme_schemes_optimized.dart';
   ```

2. **更新主題名稱**：
   ```dart
   // 舊版
   ThemeScheme.morandiBlue
   
   // 新版（保持不變）
   ThemeScheme.morandiBlue
   ```

3. **移除重複功能**：
   - 刪除 `theme_management_service.dart`
   - 整合 `theme_categories.dart` 到優化版
   - 保留 `theme_config_manager.dart`

### **逐步遷移策略**

1. **第一階段**：新組件使用優化版主題系統
2. **第二階段**：現有組件逐步遷移
3. **第三階段**：移除舊版主題系統
4. **第四階段**：清理重複檔案

## 🎯 總結

優化後的主題系統提供了：

- ✅ **更好的維護性**：精簡的主題數量，統一的結構
- ✅ **更靈活的使用方式**：直接使用或轉換為 Material Theme
- ✅ **更好的性能**：減少記憶體使用，優化渲染
- ✅ **更清晰的分類**：內建分類系統，易於管理
- ✅ **向後兼容**：保持現有 API 不變

建議從新開發的組件開始使用優化版主題系統，逐步遷移現有組件，最終實現完整的主題系統整合。
