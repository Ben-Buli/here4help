# 主題分類系統 (Theme Category System)

## 概述

本專案已經整合了新的主題分類系統，通過在 `ThemeScheme` 中新增 `category` 屬性，實現了更明確和一致的主題分類管理。

## 核心改進

### 1. ThemeScheme.category 屬性

每個主題現在都有一個明確的 `category` 屬性，用於定義主題所屬的分類：

```dart
class ThemeScheme {
  final String category; // 新增：主題分類屬性
  
  const ThemeScheme({
    required this.category, // ENUM(main, business, morandi, beach, emotions)
    // ... 其他屬性
  });
}
```

### 2. 支援的分類

系統支援以下主題分類：

- **morandi**: 莫蘭迪風格主題集合
- **ocean**: 海洋風格主題集合  
- **business**: 商業風格主題集合
- **emotions**: 情感表達主題集合
- **taiwan**: 台灣特色主題集合
- **glassmorphism**: 毛玻璃風格主題集合
- **experimental**: 實驗性主題集合

### 3. 分類邏輯優化

#### ThemeConfigManager._getThemeGroup()

現在優先使用 `category` 屬性進行分類：

```dart
String _getThemeGroup(ThemeScheme theme) {
  // 直接使用主題的 category 屬性進行分類
  switch (theme.category.toLowerCase()) {
    case 'morandi':
      return 'Morandi';
    case 'ocean':
      return 'Ocean';
    case 'taiwan':
      return 'Taiwan';
    case 'business':
      return 'Business';
    case 'emotions':
      return 'Emotions';
    case 'glassmorphism':
      return 'Glassmorphism';
    case 'experimental':
      return 'Experimental';
    default:
      // 如果 category 不在預期範圍內，回退到基於名稱的邏輯
      return _getThemeGroupByName(theme);
  }
}
```

#### ThemeConfigManager._getThemeStyle()

同樣優先使用 `category` 屬性判斷風格：

```dart
String _getThemeStyle(ThemeScheme theme) {
  // 優先使用 category 屬性
  switch (theme.category.toLowerCase()) {
    case 'morandi':
      return 'morandi';
    case 'ocean':
      return 'ocean';
    case 'glassmorphism':
      return 'glassmorphism';
    case 'business':
      return 'business';
    case 'emotions':
      return 'emotions';
    case 'taiwan':
      return 'taiwan';
    case 'experimental':
      return 'experimental';
    default:
      // 如果 category 不在預期範圍內，回退到基於名稱的邏輯
      return _getThemeStyleByName(theme);
  }
}
```

## 向後兼容性

為了確保向後兼容性，系統保留了原有的基於名稱的模式匹配邏輯：

- `_getThemeGroupByName()`: 備用的基於名稱分類邏輯
- `_getThemeStyleByName()`: 備用的基於名稱風格判斷邏輯

當主題的 `category` 屬性不在預期範圍內時，系統會自動回退到這些備用方法。

## 主題分類示例

### Emotions 分類

```dart
/// Emotions - H4H Here4Help
static const ThemeScheme h4hHere4Help = ThemeScheme(
  name: 'h4h_here4help',
  displayName: 'H4H - Here4Help',
  category: 'Emotions', // 明確指定為 Emotions 分類
  // ... 其他屬性
);
```

### Taiwan 分類

```dart
/// Taiwan - Taipei 101
static const ThemeScheme taipei101 = ThemeScheme(
  name: 'taipei_101',
  displayName: 'Taipei 101',
  category: 'Taiwan', // 明確指定為 Taiwan 分類
  // ... 其他屬性
);
```

## 分類系統的優勢

### 1. 一致性

- 主題分類邏輯與主題定義保持一致
- 減少基於名稱的模式匹配錯誤
- 更容易維護和擴展

### 2. 明確性

- 每個主題都有明確的分類標識
- 開發者可以快速理解主題的設計意圖
- 便於主題的組織和管理

### 3. 擴展性

- 新增分類時只需在 `category` 屬性中指定
- 無需修改複雜的模式匹配邏輯
- 支援自定義分類

### 4. 性能

- 直接屬性訪問比字符串模式匹配更快
- 減少了不必要的字符串操作
- 更好的記憶體使用效率

## 使用方法

### 1. 創建新主題

```dart
static const ThemeScheme newTheme = ThemeScheme(
  name: 'new_theme',
  displayName: 'New Theme',
  category: 'emotions', // 指定分類
  // ... 其他屬性
);
```

### 2. 查詢主題分類

```dart
final theme = ThemeScheme.getByName('h4h_here4help');
print('主題分類: ${theme.category}'); // 輸出: Emotions
```

### 3. 按分類篩選主題

```dart
final emotionsThemes = ThemeScheme.allThemes
    .where((theme) => theme.category.toLowerCase() == 'emotions')
    .toList();
```

## 測試

使用 `TestThemeCategories` 類來測試分類系統：

```dart
// 測試整個分類系統
TestThemeCategories.testThemeCategorySystem();

// 測試特定分類
TestThemeCategories.testSpecificCategory('emotions');
```

## 注意事項

1. **分類名稱一致性**: 確保 `category` 屬性值與預期分類名稱完全匹配
2. **向後兼容**: 舊的主題仍然可以通過基於名稱的邏輯正確分類
3. **性能考慮**: 新系統優先使用屬性訪問，提供更好的性能
4. **維護性**: 新增或修改分類時，記得更新相關的測試和文檔

## 未來改進

1. **分類枚舉**: 考慮使用枚舉類型來定義分類，提供更好的類型安全
2. **分類驗證**: 在編譯時驗證分類的有效性
3. **分類統計**: 提供更詳細的分類統計信息
4. **分類過濾**: 支援更靈活的分類過濾和排序功能
