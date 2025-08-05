# Here4Help UI 風格指南

## 📋 目錄
- [設計理念](#設計理念)
- [主要風格 (Main Style)](#主要風格-main-style)
- [編輯頁面風格 (Editor Style)](#編輯頁面風格-editor-style)
- [使用方式](#使用方式)
- [組件風格](#組件風格)
- [動畫效果](#動畫效果)

---

## 🎨 設計理念

### 整體設計原則
- **現代化毛玻璃效果**: 採用 Glassmorphism 設計風格
- **漸層色彩**: 使用漸層背景和色彩過渡
- **圓角設計**: 統一的圓角設計語言
- **流暢動畫**: 自然的過渡和互動效果
- **響應式設計**: 適配不同螢幕尺寸

### 色彩系統
- **主色調**: 紫色系為主，營造專業且溫暖的感覺
- **輔助色**: 綠色、藍色、橙色等狀態色彩
- **中性色**: 灰色系用於文字和背景
- **透明度**: 大量使用透明度創造層次感

---

## 🌟 主要風格 (Main Style)

### 設計特色
- **毛玻璃效果**: 半透明背景 + 模糊效果
- **紫色主調**: #8B5CF6 主要紫色
- **淺色背景**: 漸層淺紫背景
- **現代感**: 圓角按鈕和卡片

### 色彩配置
```dart
// 主要色彩
primary: Color(0xFF8B5CF6)      // 主要紫色
secondary: Color(0xFF7C3AED)    // 深紫色
accent: Color(0xFFA78BFA)       // 淺紫色

// 背景色彩
background: Color(0xFFF8F7FF)   // 淺紫背景
surface: Color(0xFFF3F1FF)      // 毛玻璃表面

// 文字色彩
onPrimary: Color(0xFFFFFFFF)    // 白色文字
onBackground: Color(0xFF2D3748) // 深色文字
```

### 適用場景
- ✅ 主要應用程式介面
- ✅ 用戶個人資料頁面
- ✅ 任務列表和詳情頁面
- ✅ 聊天介面
- ✅ 設定頁面

---

## 🎭 編輯頁面風格 (Editor Style)

### 設計特色
- **深色漸層**: 深藍灰漸層背景
- **高對比**: 白色文字配深色背景
- **專業感**: 適合編輯和創作場景
- **專注模式**: 減少視覺干擾

### 色彩配置
```dart
// 主要色彩
primary: Color(0xFF667EEA)      // 藍紫色
secondary: Color(0xFF764BA2)    // 深紫色
accent: Color(0xFF9F7AEA)       // 淺紫色

// 背景色彩
background: Color(0xFF2C3E50)   // 深藍灰背景
surface: Color(0xFF34495E)      // 深灰表面

// 文字色彩
onPrimary: Color(0xFFFFFFFF)    // 白色文字
onBackground: Color(0xFFFFFFFF) // 白色文字
```

### 適用場景
- ✅ 任務創建和編輯頁面
- ✅ 圖片編輯工具
- ✅ 文檔編輯器
- ✅ 創作工作區
- ✅ 專業工具介面

---

## 🔧 使用方式

### 1. 切換主題
```dart
// 在 ThemeService 中切換主題
final themeService = Provider.of<ThemeService>(context, listen: false);

// 切換到主要風格
await themeService.setThemeByName('main_style');

// 切換到編輯頁面風格
await themeService.setThemeByName('editor_style');
```

### 2. 在頁面中使用
```dart
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final theme = themeService.currentTheme;
        
        return Container(
          color: theme.background,
          child: Column(
            children: [
              // 使用主題色彩
              Container(
                color: theme.primary,
                child: Text(
                  'Hello World',
                  style: TextStyle(color: theme.onPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### 3. 動態切換主題
```dart
// 根據頁面類型自動切換主題
void switchToEditorStyle() {
  themeService.setThemeByName('editor_style');
}

void switchToMainStyle() {
  themeService.setThemeByName('main_style');
}
```

---

## 🧩 組件風格

### 按鈕設計
```dart
// 主要按鈕
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: theme.primary,
    foregroundColor: theme.onPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
  ),
  onPressed: () {},
  child: Text('主要按鈕'),
)

// 次要按鈕
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: theme.primary,
    side: BorderSide(color: theme.primary, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
  ),
  onPressed: () {},
  child: Text('次要按鈕'),
)
```

### 卡片設計
```dart
Card(
  elevation: 4,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Container(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text(
          '卡片標題',
          style: TextStyle(
            color: theme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ),
)
```

### 輸入框設計
```dart
TextField(
  decoration: InputDecoration(
    filled: true,
    fillColor: theme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.primary.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.primary, width: 2),
    ),
    labelText: '輸入標籤',
    labelStyle: TextStyle(color: theme.onSurface),
  ),
)
```

---

## ✨ 動畫效果

### 標準過渡動畫
```dart
// 使用主題的標準過渡時間
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // 動畫內容
)
```

### 懸停效果
```dart
// 按鈕懸停效果
MouseRegion(
  cursor: SystemMouseCursors.click,
  child: AnimatedContainer(
    duration: Duration(milliseconds: 200),
    transform: isHovered ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
    child: ElevatedButton(
      // 按鈕內容
    ),
  ),
)
```

### 載入動畫
```dart
// 使用主題色彩的載入動畫
CircularProgressIndicator(
  valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
)
```

---

## 📱 響應式設計

### 斷點設定
```dart
// 手機
if (MediaQuery.of(context).size.width < 480) {
  // 手機樣式
}

// 平板
if (MediaQuery.of(context).size.width < 768) {
  // 平板樣式
}

// 桌面
if (MediaQuery.of(context).size.width >= 768) {
  // 桌面樣式
}
```

### 適配策略
- **手機**: 單欄佈局，簡化導航
- **平板**: 雙欄佈局，保持功能完整
- **桌面**: 多欄佈局，充分利用空間

---

## 🎯 最佳實踐

### 1. 色彩使用
- ✅ 使用主題色彩變數，避免硬編碼
- ✅ 保持色彩一致性
- ✅ 考慮對比度和可讀性
- ❌ 避免過多色彩混用

### 2. 間距設計
- ✅ 使用統一的間距系統
- ✅ 保持視覺層次
- ✅ 考慮不同螢幕尺寸

### 3. 字體設計
- ✅ 使用系統字體堆疊
- ✅ 保持字體大小層次
- ✅ 考慮可讀性

### 4. 動畫設計
- ✅ 使用自然的過渡效果
- ✅ 避免過度動畫
- ✅ 考慮效能影響

---

## 🔄 主題切換範例

### 頁面級別切換
```dart
class TaskCreatePage extends StatefulWidget {
  @override
  _TaskCreatePageState createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends State<TaskCreatePage> {
  @override
  void initState() {
    super.initState();
    // 進入編輯頁面時切換到編輯風格
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeService = Provider.of<ThemeService>(context, listen: false);
      themeService.setThemeByName('editor_style');
    });
  }

  @override
  void dispose() {
    // 離開頁面時恢復主要風格
    final themeService = Provider.of<ThemeService>(context, listen: false);
    themeService.setThemeByName('main_style');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final theme = themeService.currentTheme;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.background,
                theme.surface,
              ],
            ),
          ),
          child: Column(
            children: [
              // 頁面內容
            ],
          ),
        );
      },
    );
  }
}
```

---

*最後更新: 2024年12月*
*維護者: Here4Help 設計團隊* 