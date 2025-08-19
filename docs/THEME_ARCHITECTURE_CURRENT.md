# 主題架構說明文件

## 概述

本文檔描述了 Here4Help 應用程式的現有主題架構，包括主題定義、管理、組件和配置方式。

## 架構組成

### 1. 核心檔案結構

```
lib/
├── constants/
│   └── theme_schemes.dart          # 主題色系定義
├── services/
│   └── theme_config_manager.dart   # 主題配置管理器
├── widgets/
│   ├── theme_aware_components.dart # 主題感知組件
│   ├── glassmorphism_app_bar.dart # 毛玻璃風格 AppBar
│   └── color_selector.dart         # 顏色選擇器
└── account/pages/
    └── theme_settings_page.dart    # 主題設定頁面
```

### 2. 主要組件說明

#### 2.1 ThemeScheme 類別 (`lib/constants/theme_schemes.dart`)

**作用**：定義所有主題的顏色配置和樣式屬性

**主要屬性**：
- **基礎顏色**：`primary`, `secondary`, `accent`, `background`, `surface`
- **文字顏色**：`onPrimary`, `onSecondary`, `onBackground`, `onSurface`
- **狀態顏色**：`error`, `success`, `warning`, `shadow`
- **特殊效果**：`backgroundBlur`, `surfaceBlur`, `backgroundGradient`
- **UI 組件顏色**：`cardBackground`, `inputBackground`, `divider` 等
- **AppBar 顏色**：`appBarTitleColor`, `appBarSubtitleColor`

**主題分類**：
1. **主要風格**：`mainStyle` - 毛玻璃紫色系
2. **Meta 商業風格**：`metaBusinessStyle` - 淡紫色主題
3. **商業漸層風格**：`businessGradient` - 彩虹漸層
4. **莫蘭迪色系**：`morandiBlue`, `morandiGreen`, `morandiPink` 等
5. **海洋風格**：`beachSunset`, `oceanBlue`, `clownfish` 等
6. **台灣特色**：`milkTeaEarth`, `taipei101`, `taipei2019Pantone` 等
7. **情感表達**：`rainbowPride`, `bluePink`, `pinkTheme` 等
8. **毛玻璃風格**：`glassmorphismBlur`, `glassmorphismBlueGrey` 等

#### 2.2 ThemeConfigManager 類別 (`lib/services/theme_config_manager.dart`)

**作用**：管理主題的切換、持久化和配置

**主要功能**：
- 主題切換和持久化
- 主題模式管理（淺色/深色/系統）
- 主題預設管理
- 主題驗證和建議
- 自動生成 Dark Mode 版本

**核心方法**：
```dart
// 設置主題
await themeManager.setTheme(ThemeScheme.morandiBlue);

// 設置主題模式
await themeManager.setThemeMode(AppThemeMode.system);

// 獲取當前主題
ThemeScheme currentTheme = themeManager.currentTheme;

// 獲取主題模式
AppThemeMode mode = themeManager.themeMode;
```

#### 2.3 ThemeAwareComponents (`lib/widgets/theme_aware_components.dart`)

**作用**：提供主題感知的 UI 組件

**包含組件**：
- `ThemeAwareIcon` - 主題感知圖標
- `ThemeAwareCircleBadge` - 主題感知圓形徽章
- `ThemeAwareTextField` - 主題感知輸入欄位
- `ThemeAwareCard` - 主題感知卡片
- `ThemeAwareButton` - 主題感知按鈕
- `ThemeAwareText` - 主題感知文字

**使用方式**：
```dart
ThemeAwareIcon(
  icon: Icons.star,
  color: themeManager.currentTheme.primary,
)
```

## 主題配置詳解

### 1. AppBar 標題顏色設定

**位置**：`lib/constants/theme_schemes.dart` 中的每個 `ThemeScheme` 實例

**屬性**：
```dart
final Color? appBarTitleColor;      // AppBar 標題顏色
final Color? appBarSubtitleColor;   // AppBar 次標題顏色
```

**設定範例**：
```dart
static const ThemeScheme metaBusinessStyle = ThemeScheme(
  name: 'meta_business_style',
  displayName: 'Meta Business Style',
  // ... 其他顏色屬性
  appBarTitleColor: Color(0xFF1C1E21),    // 深灰色標題
  appBarSubtitleColor: Color(0xFF6B7280), // 中灰色次標題
);
```

**自動推導**：如果未設定 `appBarTitleColor`，系統會自動根據主題的其他顏色推導出合適的標題顏色。

### 2. 主題顏色屬性說明

#### 2.1 基礎顏色系統
```dart
primary: Color(0xFF8B5CF6),        // 主要顏色（按鈕、連結等）
secondary: Color(0xFF7C3AED),      // 次要顏色（輔助元素）
accent: Color(0xFFA78BFA),         // 強調顏色（重點突出）
background: Color(0xFFF8F7FF),     // 背景顏色
surface: Color(0xFFF3F1FF),        // 表面顏色（卡片、輸入框等）
```

#### 2.2 文字顏色系統
```dart
onPrimary: Color(0xFFFFFFFF),      // 主要色上的文字顏色
onSecondary: Color(0xFFFFFFFF),    // 次要色上的文字顏色
onBackground: Color(0xFF2D3748),   // 背景上的文字顏色
onSurface: Color(0xFF2D3748),      // 表面上的文字顏色
```

#### 2.3 UI 組件顏色
```dart
cardBackground: Color(0xFFFFFFFF),     // 卡片背景色
cardBorder: Color(0xFFE5E7EB),        // 卡片邊框色
inputBackground: Color(0xFFFFFFFF),   // 輸入框背景色
inputBorder: Color(0xFFD1D5DB),       // 輸入框邊框色
hintText: Color(0xFF9CA3AF),          // 提示文字顏色
disabledText: Color(0xFF6B7280),      // 禁用文字顏色
divider: Color(0xFFF3F4F6),           // 分割線顏色
```

#### 2.4 特殊效果
```dart
backgroundBlur: 10.0,                    // 背景模糊強度
surfaceBlur: 5.0,                        // 表面模糊強度
backgroundGradient: [Color(...), ...],   // 背景漸層色彩
gradientBegin: Alignment.topLeft,        // 漸層起始位置
gradientEnd: Alignment.bottomRight,      // 漸層結束位置
```

### 3. 主題模式管理

**支援的模式**：
- `AppThemeMode.light` - 淺色模式
- `AppThemeMode.dark` - 深色模式
- `AppThemeMode.system` - 跟隨系統設定

**自動轉換**：系統會自動為每個主題生成對應的 Dark Mode 版本

## 使用方式

### 1. 在 Widget 中使用主題

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return Container(
          color: themeManager.currentTheme.background,
          child: Text(
            'Hello World',
            style: TextStyle(
              color: themeManager.currentTheme.onBackground,
            ),
          ),
        );
      },
    );
  }
}
```

### 2. 使用主題感知組件

```dart
// 自動使用當前主題的顏色
ThemeAwareTextField(
  labelText: '用戶名',
  hintText: '請輸入用戶名',
)

// 自定義顏色
ThemeAwareButton(
  text: '提交',
  backgroundColor: themeManager.currentTheme.primary,
  textColor: themeManager.currentTheme.onPrimary,
)
```

### 3. 切換主題

```dart
// 在 ThemeSettingsPage 中
onChanged: (ThemeScheme? newTheme) {
  if (newTheme != null) {
    themeManager.setTheme(newTheme);
  }
}
```

## 主題設定頁面

### 功能區域

1. **主題模式選擇**：Light/Dark/System 模式切換
2. **主題分類選擇**：通過 Dropdown 選擇不同分類的主題
3. **顏色選擇器**：選擇具體的主題顏色變體
4. **主題預覽**：展開/收縮的主題預覽區域

### 路由

- **路徑**：`/account/theme`
- **檔案**：`lib/account/pages/theme_settings_page.dart`

## 擴展指南

### 1. 添加新主題

在 `lib/constants/theme_schemes.dart` 中添加新的 `ThemeScheme` 實例：

```dart
static const ThemeScheme myNewTheme = ThemeScheme(
  name: 'my_new_theme',
  displayName: 'My New Theme',
  primary: Color(0xFF...),
  secondary: Color(0xFF...),
  // ... 其他必要屬性
);
```

### 2. 添加新顏色屬性

在 `ThemeScheme` 類別中添加新屬性：

```dart
class ThemeScheme {
  // ... 現有屬性
  final Color? newColor;  // 新顏色屬性
  
  const ThemeScheme({
    // ... 現有參數
    this.newColor,
  });
}
```

### 3. 創建主題感知組件

```dart
class ThemeAwareNewComponent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        return Container(
          // 使用主題顏色
          color: themeManager.currentTheme.newColor,
        );
      },
    );
  }
}
```

## 注意事項

1. **顏色對比度**：確保 `onPrimary`、`onSecondary` 等文字顏色與背景色有足夠的對比度
2. **一致性**：新添加的主題應保持與現有主題的視覺一致性
3. **測試**：添加新主題後應在不同模式下測試顯示效果
4. **文檔更新**：修改主題架構後應更新本文檔

## 總結

Here4Help 的主題架構提供了完整的顏色管理系統，支援多種主題風格、自動 Dark Mode 轉換、主題感知組件等功能。通過 `ThemeScheme` 定義主題，`ThemeConfigManager` 管理主題，`ThemeAwareComponents` 提供主題感知的 UI 組件，實現了靈活且易於維護的主題系統。
