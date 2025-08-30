# 付款密碼驗證 API 實作報告

## 📋 **實作概述**

為了支援新的 Confirm & Pay Dialog 功能，建立了專門的付款密碼驗證 API 端點，並整合到 TaskService 中使用 HttpClientService 進行全域 Authorization 管理。

## 🔧 **實作內容**

### 1. **後端 API 端點**

**檔案**: `backend/api/account/verify-payment-password.php`

**功能特點**:
- ✅ 支援 JWT token 驗證（Header 和查詢參數雙重支援）
- ✅ 付款密碼格式驗證（必須為 6 位數字）
- ✅ 使用 `password_verify()` 安全驗證雜湊密碼
- ✅ 完整的錯誤處理和回應格式
- ✅ CORS 支援

**API 規格**:
```http
POST /backend/api/account/verify-payment-password.php
Content-Type: application/json
Authorization: Bearer <token>

{
  "payment_password": "123456"
}
```

**回應格式**:
```json
// 成功
{
  "success": true,
  "data": {
    "user_id": 123,
    "verified": true,
    "message": "Payment password verified successfully"
  }
}

// 失敗
{
  "success": false,
  "message": "Invalid payment password"
}
```

### 2. **前端服務整合**

**檔案**: `lib/task/services/task_service.dart`

**新增方法**:
```dart
Future<Map<String, dynamic>> verifyPaymentPassword({
  required String paymentPassword,
}) async
```

**改進內容**:
- ✅ 使用 `HttpClientService` 替代直接 `http` 調用
- ✅ 自動附加 Authorization header
- ✅ 統一的錯誤處理和回應解析
- ✅ 支援 MAMP 查詢參數 token 模式

**同時優化的方法**:
- `transferPoints()` - 點數轉移
- `deductCompletionFee()` - 手續費扣除  
- `recordFeeRevenue()` - 手續費記錄

## 🧪 **測試驗證**

**測試檔案**: `test_payment_password_api.php`

**測試案例**:
1. ✅ 正確付款密碼驗證
2. ✅ 錯誤付款密碼拒絕
3. ✅ 無效格式密碼拒絕
4. ✅ JWT token 驗證
5. ✅ 資料庫連接測試

## 🔒 **安全特性**

1. **密碼安全**:
   - 使用 `password_hash()` 和 `password_verify()`
   - 不在日誌中記錄明文密碼
   - 6 位數字格式驗證

2. **認證安全**:
   - JWT token 必須驗證
   - 支援多種 token 傳遞方式
   - 用戶狀態檢查（非刪除用戶）

3. **API 安全**:
   - CORS 配置
   - HTTP 方法限制（僅 POST）
   - 完整的輸入驗證

## 📊 **資料庫需求**

**必要欄位**: `users.payment_password` (VARCHAR(255))

**檢查語句**:
```sql
SELECT payment_password FROM users WHERE id = ? AND status != 'deleted'
```

## 🚀 **使用方式**

### 前端調用範例:
```dart
try {
  final result = await TaskService().verifyPaymentPassword(
    paymentPassword: '123456',
  );
  
  if (result['verified'] == true) {
    // 驗證成功，繼續支付流程
    print('付款密碼驗證成功');
  }
} catch (e) {
  // 處理驗證失敗
  print('付款密碼驗證失敗: $e');
}
```

### 後端測試範例:
```bash
curl -X POST "http://127.0.0.1:8888/here4help/backend/api/account/verify-payment-password.php?token=<JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"payment_password": "123456"}'
```

## ✅ **完成狀態**

- [x] 後端 API 端點實作
- [x] 前端服務方法整合
- [x] HttpClientService 全域 Authorization 支援
- [x] 測試檔案建立
- [x] 安全性驗證
- [x] 文檔撰寫

## 🔄 **後續步驟**

1. **UI 整合**: 將付款密碼驗證整合到新的 Confirm & Pay Dialog
2. **流程測試**: 完整的支付流程端到端測試
3. **錯誤處理**: 前端 UI 錯誤提示優化
4. **效能優化**: 快取和重試機制

---

**建立時間**: 2025-08-30  
**實作者**: AI Assistant  
**狀態**: ✅ 完成
