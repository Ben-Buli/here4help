# 🎨 主題系統架構說明文件

## 📋 概述

本文檔詳細說明 Here4Help 專案的主題系統架構，包括檔案結構、邏輯流程、使用方法和維護指南。

## 🏗️ 系統架構

### **檔案結構圖**

```
lib/
├── constants/
│   ├── theme_schemes_optimized.dart    # ✅ 主要主題系統（推薦使用）
│   └── theme_schemes.dart              # ❌ 舊版主題系統（建議逐步遷移）
├── services/
│   └── theme_config_manager.dart       # ✅ 主題配置管理器
└── widgets/
    └── theme_aware_components.dart     # ✅ 主題感知組件
```

### **主題系統組件關係**

```
┌─────────────────────────────────────────────────────────────┐
│                    ThemeScheme                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   primary   │  │  secondary  │  │    accent   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ background  │  │   surface   │  │    error    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                ThemeConfigManager                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ 主題切換    │  │ 主題持久化  │  │ 主題驗證    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                Material Theme                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ ThemeData   │  │ ColorScheme │  │ AppBarTheme │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 📁 檔案用途說明

### **1. `theme_schemes_optimized.dart` - 主要主題系統**

**用途**：定義所有主題的顏色配置和樣式屬性

**主要功能**：
- 定義 12 個核心主題
- 提供主題分類系統
- 支援特殊效果（模糊、漸層）
- 轉換為 Material Theme

**核心類別**：
```dart
class ThemeScheme {
  // 基礎顏色
  final Color primary, secondary, accent;
  final Color background, surface;
  final Color onPrimary, onSecondary, onBackground, onSurface;
  
  // 狀態顏色
  final Color error, success, warning, shadow, outlineVariant;
  
  // 特殊效果
  final double? backgroundBlur, surfaceBlur;
  final List<Color>? backgroundGradient;
  
  // UI 組件顏色
  final Color cardBackground, inputBackground, divider;
  
  // 實用方法
  ThemeData toThemeData();
  Widget createBlurredBackground({required Widget child});
  Widget createGradientBackground({required Widget child});
}
```

**主題分類**：
- **business**：商業風格主題（3個）
- **morandi**：莫蘭迪色系主題（3個）
- **ocean**：海洋風格主題（2個）
- **taiwan**：台灣特色主題（2個）
- **emotions**：情感表達主題（1個）
- **glassmorphism**：毛玻璃風格主題（1個）

### **2. `theme_config_manager.dart` - 主題配置管理器**

**用途**：管理主題的切換、持久化和配置

**主要功能**：
- 主題切換和持久化
- 主題模式管理（淺色/深色/系統）
- 主題預設管理
- 主題驗證和建議

**核心方法**：
```dart
class ThemeConfigManager extends ChangeNotifier {
  // 主題管理
  Future<void> setTheme(ThemeScheme theme);
  ThemeScheme get currentTheme;
  
  // 主題模式管理
  Future<void> setThemeMode(AppThemeMode mode);
  AppThemeMode get themeMode;
  
  // 主題預設
  Map<String, ThemePreset> get themePresets;
  Future<void> createCustomTheme(ThemeScheme theme);
}
```

### **3. `theme_aware_components.dart` - 主題感知組件**

**用途**：提供主題感知的 UI 組件

**包含組件**：
- `ThemeAwareIcon` - 主題感知圖標
- `ThemeAwareCircleBadge` - 主題感知圓形徽章
- `ThemeAwareTextField` - 主題感知輸入欄位
- `ThemeAwareCard` - 主題感知卡片
- `ThemeAwareButton` - 主題感知按鈕

## 🔄 主題邏輯流程

### **1. 主題初始化流程**

```
應用啟動
    │
    ▼
ThemeConfigManager 初始化
    │
    ▼
從 SharedPreferences 載入保存的主題
    │
    ▼
設置預設主題（如果沒有保存的主題）
    │
    ▼
通知監聽器主題已載入
    │
    ▼
UI 組件更新主題
```

### **2. 主題切換流程**

```
用戶選擇新主題
    │
    ▼
ThemeConfigManager.setTheme()
    │
    ▼
驗證主題有效性
    │
    ▼
更新當前主題
    │
    ▼
保存到 SharedPreferences
    │
    ▼
通知所有監聽器
    │
    ▼
UI 組件重新建構
```

### **3. 主題應用流程**

```
Widget 建構
    │
    ▼
獲取當前主題（ThemeScheme 或 Material Theme）
    │
    ▼
應用主題顏色到 UI 組件
    │
    ▼
處理特殊效果（模糊、漸層）
    │
    ▼
渲染 UI
```

## 🎯 使用方法

### **1. 基本主題使用**

```dart
import 'package:here4help/constants/theme_schemes_optimized.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 使用特定主題
    final theme = ThemeScheme.morandiBlue;
    
    return Container(
      color: theme.background,
      child: Text(
        'Hello World',
        style: TextStyle(color: theme.onBackground),
      ),
    );
  }
}
```

### **2. 動態主題切換**

```dart
class ThemeSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final currentTheme = themeManager.currentTheme;
        
        return Container(
          color: currentTheme.background,
          child: Text(
            '當前主題：${currentTheme.displayName}',
            style: TextStyle(color: currentTheme.onBackground),
          ),
        );
      },
    );
  }
}
```

### **3. 主題與 Material Theme 整合**

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          theme: themeManager.currentTheme.toThemeData(),
          home: MyHomePage(),
        );
      },
    );
  }
}
```

## 🔧 維護指南

### **1. 添加新主題**

```dart
// 在 theme_schemes_optimized.dart 中添加新主題
static const ThemeScheme newTheme = ThemeScheme(
  name: 'new_theme',
  displayName: 'New Theme',
  category: 'business',
  primary: Color(0xFF123456),
  secondary: Color(0xFF789ABC),
  // ... 其他顏色屬性
);

// 添加到 allThemes 列表
static const List<ThemeScheme> allThemes = [
  // ... 現有主題
  newTheme,
];

// 添加到分類映射
static const Map<String, List<ThemeScheme>> themeCategories = {
  'business': [
    // ... 現有商業主題
    newTheme,
  ],
  // ... 其他分類
};
```

### **2. 修改現有主題**

```dart
// 直接修改主題定義
static const ThemeScheme morandiBlue = ThemeScheme(
  name: 'morandi_blue',
  displayName: 'Morandi Blue - Updated',
  category: 'morandi',
  primary: Color(0xFF6B7A85), // 修改主要顏色
  // ... 其他屬性保持不變
);
```

### **3. 主題驗證**

```dart
// 在 ThemeConfigManager 中添加驗證邏輯
bool validateTheme(ThemeScheme theme) {
  // 檢查顏色對比度
  // 檢查必要屬性
  // 檢查顏色有效性
  return true;
}
```

## 📊 性能優化

### **1. 主題快取**

```dart
class ThemeCache {
  static final Map<String, ThemeScheme> _cache = {};
  
  static ThemeScheme getTheme(String name) {
    if (!_cache.containsKey(name)) {
      _cache[name] = ThemeScheme.getByName(name);
    }
    return _cache[name]!;
  }
}
```

### **2. 避免重複建構**

```dart
class OptimizedThemeWidget extends StatelessWidget {
  // 使用 const 建構函數
  const OptimizedThemeWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // 快取主題實例
    final theme = ThemeScheme.morandiBlue;
    
    return Container(
      color: theme.background,
      child: Text('優化後的主題組件'),
    );
  }
}
```

## 🚨 注意事項

### **1. 主題命名規範**

- 使用小寫字母和下劃線：`morandi_blue`
- 避免特殊字符和空格
- 保持名稱的一致性和可讀性

### **2. 顏色選擇原則**

- 確保足夠的對比度（WCAG 2.1 AA 標準）
- 避免過於鮮豔的顏色
- 考慮深色模式的適配性

### **3. 檔案維護**

- 定期清理未使用的主題
- 保持主題分類的邏輯性
- 及時更新文檔

## 🔮 未來發展

### **1. 計劃功能**

- 主題預覽功能
- 主題匯入/匯出
- 自定義主題創建器
- 主題推薦系統

### **2. 技術改進**

- 支援更多特殊效果
- 優化主題切換性能
- 增強主題驗證功能
- 支援主題動畫

## 📚 相關文檔

- [主題使用指南](THEME_USAGE_GUIDE.md)
- [主題更新記錄](theme-updates/)
- [專案整合規格文件](../優先執行/README_專案整合規格文件.md)

---

**最後更新**：2025-01-19  
**版本**：1.0.0  
**維護者**：Here4Help 開發團隊
