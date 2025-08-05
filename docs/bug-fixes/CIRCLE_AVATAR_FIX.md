# CircleAvatar Assertion 錯誤修復

## 問題描述

首頁出現 CircleAvatar 的 assertion 錯誤：
```
Assertion failed: backgroundImage != null || onBackgroundImageError == null
```

## 錯誤原因

Flutter 的 CircleAvatar 組件有一個限制：
- 當 `backgroundImage` 為 `null` 時，不能設置 `onBackgroundImageError`
- 當 `backgroundImage` 不為 `null` 時，必須設置 `onBackgroundImageError`

## 原始錯誤代碼

```dart
CircleAvatar(
  radius: 30,
  backgroundImage: ImageHelper.getAvatarImage(user?.avatar_url),
  onBackgroundImageError: (exception, stackTrace) {
    debugPrint('頭像載入錯誤: $exception');
  },
  child: user?.avatar_url == null || user!.avatar_url.isEmpty
      ? const Icon(Icons.person)
      : null,
),
```

**問題**：當 `user?.avatar_url` 為 null 或空時，`ImageHelper.getAvatarImage()` 返回 null，但 `onBackgroundImageError` 仍然被設置。

## 修復方案

使用條件渲染，根據是否有頭像路徑來決定渲染哪種 CircleAvatar：

```dart
user?.avatar_url != null && user!.avatar_url.isNotEmpty
    ? CircleAvatar(
        radius: 30,
        backgroundImage: ImageHelper.getAvatarImage(user.avatar_url),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('頭像載入錯誤: $exception');
        },
      )
    : const CircleAvatar(
        radius: 30,
        child: Icon(Icons.person),
      ),
```

## 修復邏輯

### 有頭像路徑時
- 渲染帶有 `backgroundImage` 和 `onBackgroundImageError` 的 CircleAvatar
- 使用 `ImageHelper.getAvatarImage()` 處理圖片路徑

### 無頭像路徑時
- 渲染只有 `child` 的 CircleAvatar
- 顯示預設的 `Icon(Icons.person)`
- 不設置 `backgroundImage` 和 `onBackgroundImageError`

## 優勢

1. **符合 Flutter 規範**：確保 `backgroundImage` 和 `onBackgroundImageError` 的條件匹配
2. **清晰的邏輯**：明確區分有頭像和無頭像的情況
3. **性能優化**：使用 `const` 構造器提高性能
4. **錯誤處理**：保留圖片載入錯誤的處理邏輯

## 測試結果

修復後的分析結果：
```
Analyzing home_page.dart...
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss •
          lib/home/pages/home_page.dart:77:50 • deprecated_member_use
warning • The declaration '_ChallengeCard' isn't referenced • lib/home/pages/home_page.dart:319:7 •
       unused_element

3 issues found. (ran in 0.8s)
```

**結果**：沒有錯誤，只有一些不影響功能的 warning。

## 注意事項

1. **條件檢查**：確保在訪問 `user!.avatar_url` 之前檢查 `user` 不為 null
2. **性能考慮**：使用 `const` 構造器來提高無頭像情況下的性能
3. **錯誤處理**：保留 `onBackgroundImageError` 來處理圖片載入失敗的情況

## 相關文件

- `lib/home/pages/home_page.dart` - 修復的 CircleAvatar 組件
- `lib/utils/image_helper.dart` - 圖片處理工具
- `lib/config/environment_config.dart` - 環境配置 