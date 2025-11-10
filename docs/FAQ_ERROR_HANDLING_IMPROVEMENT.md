# FAQ 頁面錯誤處理與日誌追蹤改善報告

## 問題描述

用戶在 iOS 版本上測試 FAQ 頁面時遇到 HTTP 500 錯誤：

```
Exception: HTTP 500: {"success":false,"code":"Internal server error","message":500,"traceId":"690FF4B5A6E043E5AE2A","timestamp":"2025-11-09T09:56:05+08:00","server_time":1762653365}
```

## 根本原因分析

經過檢查，發現以下問題：

### 1. 後端問題（已解決）

**問題：使用了不存在的 `faq_categories` 表**

後端 API (`backend/api/faqs/list.php`) 和 Admin Controller (`admin/app/Http/Controllers/Admin/FAQController.php`) 嘗試查詢 `faq_categories` 表，但該表不存在，導致 PDO 拋出異常並返回 500 錯誤。

**解決方案：完全移除 `faq_categories` 相關功能**

由於專案不打算使用額外的分類表，已將所有 `faq_categories` 相關程式碼移除：
- ✅ 移除後端 API 中的分類查詢
- ✅ 移除 Admin Controller 中的 `categories()` 方法
- ✅ 移除 `index()` 和 `show()` 方法中的 LEFT JOIN faq_categories
- ✅ 移除 API 回應中的 `categories` 欄位

### 2. 前端問題

**問題 1：錯誤訊息顯示不友善**
- 錯誤訊息過於技術性，用戶無法理解
- 沒有顯示關鍵的 traceId，無法追蹤問題
- 沒有顯示錯誤碼和狀態碼

**問題 2：缺少日誌追蹤**
- 沒有使用 `developer.log` 記錄請求和回應
- 無法追蹤 API 呼叫流程
- 錯誤發生時缺少上下文資訊

## 解決方案

### 1. 後端改善（已完成）

#### ✅ 移除 faq_categories 相關功能

**檔案：`backend/api/faqs/list.php`**

1. **移除分類查詢**
   ```php
   // 已移除
   // $categorySql = "SELECT slug, name, icon FROM faq_categories...";
   
   Response::success([
       'faqs' => $faqs,
       // 已移除 'categories' => $categories,
       'pagination' => [...]
   ]);
   ```

**檔案：`admin/app/Http/Controllers/Admin/FAQController.php`**

1. **移除 categories() 方法**
   - 完全移除 `public function categories()` 方法

2. **移除 index() 中的 JOIN**
   ```php
   // 修改前
   FROM faqs f
   LEFT JOIN faq_categories fc ON f.category = fc.slug
   LEFT JOIN admins u1 ON f.created_by = u1.id
   
   // 修改後
   FROM faqs f
   LEFT JOIN admins u1 ON f.created_by = u1.id
   LEFT JOIN admins u2 ON f.updated_by = u2.id
   ```

3. **移除 show() 中的 JOIN**
   ```php
   // 修改前
   SELECT f.*, fc.name as category_name FROM faqs f
   LEFT JOIN faq_categories fc ON f.category = fc.slug
   
   // 修改後
   SELECT f.* FROM faqs f WHERE f.id = ?
   ```

#### ✅ 改善錯誤處理

1. **分離資料庫異常處理**
   ```php
   } catch (PDOException $e) {
       // 資料庫錯誤
       error_log("FAQ List API Database Error: " . $e->getMessage());
       error_log("SQL Error Code: " . $e->getCode());
       Response::error('DATABASE_ERROR', 'Failed to fetch FAQs from database');
   } catch (Exception $e) {
       // 其他錯誤
       error_log("FAQ List API Error: " . $e->getMessage());
       error_log("Stack trace: " . $e->getTraceAsString());
       Response::error('Internal server error', 500);
   }
   ```

2. **處理可選的分類表查詢（已移除）**
   - ~~原本嘗試容錯處理 faq_categories 表~~
   - **已完全移除分類功能**，不再需要容錯處理

#### ✅ 改善錯誤日誌

### 2. 前端改善

#### ✅ 增強日誌追蹤

**檔案：`lib/account/pages/faq_page.dart`**

1. **添加詳細的請求日誌**
   ```dart
   developer.log(
     'Loading FAQs from: $url',
     name: 'FAQPage',
     level: 800,
   );
   ```

2. **記錄回應狀態**
   ```dart
   developer.log(
     'Response status: ${response.statusCode}',
     name: 'FAQPage',
     level: 800,
   );
   ```

3. **記錄資料結構**
   ```dart
   developer.log(
     'Response data: ${data.keys.toList()}',
     name: 'FAQPage',
     level: 800,
   );
   ```

4. **錯誤日誌**
   ```dart
   developer.log(
     'API returned error: $errorMsg (code: $errorCode, traceId: $traceId)',
     name: 'FAQPage',
     level: 1000,
     error: errorMsg,
   );
   ```

#### ✅ 優化錯誤顯示

1. **結構化錯誤資訊**
   - 新增 `_errorCode`、`_traceId`、`_statusCode` 狀態變數
   - 建立 `_ApiException` 類來封裝錯誤資訊

2. **友善的錯誤 UI**
   ```dart
   Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: Colors.red.shade50,
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: Colors.red.shade200),
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         if (_statusCode != null) ...[
           _buildErrorDetail('Status Code', _statusCode.toString()),
         ],
         if (_errorCode != null) ...[
           _buildErrorDetail('Error Code', _errorCode!),
         ],
         _buildErrorDetail('Message', _error!),
         if (_traceId != null) ...[
           _buildErrorDetail('Trace ID', _traceId!),
           Text('請將 Trace ID 提供給技術支援以便追蹤問題'),
         ],
       ],
     ),
   )
   ```

3. **顯示關鍵除錯資訊**
   - HTTP 狀態碼
   - 錯誤碼 (Error Code)
   - 錯誤訊息 (Message)
   - 追蹤 ID (Trace ID) - **這是最重要的，用於後端日誌追蹤**

## 測試檢查清單

### 後端測試

- [x] 確認 `faqs` 表存在且有資料
- [x] 移除所有 `faq_categories` 相關查詢
- [x] 測試 API 不再依賴 `faq_categories` 表
- [x] 檢查 PHP error log 是否有正確記錄錯誤
- [ ] 驗證 API 回應格式正確（不包含 categories 欄位）

### 前端測試

- [ ] iOS 實機測試
- [ ] Android 實機測試
- [ ] 檢查 Xcode/Android Studio console 的 log 輸出
- [ ] 測試錯誤顯示（故意輸入錯誤的 URL）
- [ ] 測試成功載入資料
- [ ] 測試 Pull-to-refresh 功能

## 如何使用 Trace ID 追蹤問題

### iOS/Android 查看日誌

**Xcode Console (iOS)**
```bash
# 篩選 FAQPage 的日誌
搜尋：FAQPage
```

**Android Studio Logcat (Android)**
```bash
# 篩選 FAQPage 的日誌
Tag: FAQPage
```

### 後端查看日誌

**PHP Error Log**
```bash
# 查找特定 Trace ID 的錯誤
grep "690FF4B5A6E043E5AE2A" /path/to/php/error.log
```

**檢查 TraceId 相關日誌**
```bash
# 如果使用了 Logger 類，可以查找 TraceId
grep "traceId.*690FF4B5A6E043E5AE2A" /path/to/logs/*.log
```

## 資料庫準備

### FAQ 主表已足夠

**不需要 `faq_categories` 表**

FAQ 功能僅使用 `faqs` 主表，`category` 欄位為 VARCHAR 字串類型，不需要額外的分類表。

如果需要新增 FAQ 資料，可以參考 `faq_insert_data.sql` 檔案。

### 檢查 faqs 表結構

```sql
DESCRIBE faqs;

-- 確保有以下欄位：
-- id, question, answer, category, language, 
-- is_active, sort_order, created_by, updated_by,
-- created_at, updated_at
```

## 優化成果

### Before（改善前）
- ❌ 依賴不存在的 `faq_categories` 表
- ❌ 錯誤訊息過長且不清楚
- ❌ 無法追蹤問題來源
- ❌ 缺少關鍵除錯資訊
- ❌ 資料庫錯誤導致整個 API 失敗

### After（改善後）
- ✅ 完全移除 `faq_categories` 依賴
- ✅ 簡化資料結構（僅使用 faqs 主表）
- ✅ 結構化的錯誤顯示
- ✅ 顯示 Trace ID 供追蹤
- ✅ 完整的日誌記錄
- ✅ 友善的使用者體驗

## 重要變更說明

### 移除的功能

1. **API 回應不再包含 `categories` 欄位**
   ```json
   // Before
   {
     "success": true,
     "data": {
       "faqs": [...],
       "categories": [...],  // 已移除
       "pagination": {...}
     }
   }
   
   // After
   {
     "success": true,
     "data": {
       "faqs": [...],
       "pagination": {...}
     }
   }
   ```

2. **Admin API 移除的端點**
   - ~~`GET /api/admin/faqs/categories`~~ (已移除)

3. **資料庫變更**
   - 不需要建立 `faq_categories` 表
   - `faqs.category` 欄位為普通字串，不需要外鍵關聯

## 建議

1. **測試 FAQ API**：確認不再有 500 錯誤
2. **監控日誌**：定期檢查 PHP error log 和 TraceId 日誌
3. **更新前端**：如果前端有使用 `categories` 欄位，需要移除相關程式碼
4. **文檔更新**：更新 API 文檔說明回應格式（不包含 categories）

