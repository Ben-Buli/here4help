# 認證問題診斷清單

## 🔍 檢查項目

### 1. Token 格式檢查
- [ ] Token 不以 `eyJ` 開頭（非 JWT）
- [ ] Token 長度合理（base64 編碼的 JSON）
- [ ] API 調用返回 200 狀態碼

### 2. 後端驗證
- [ ] 後端 profile.php 正確解析 token
- [ ] 資料庫中用戶資料存在
- [ ] avatar_url 欄位有值或正確處理空值

### 3. 前端狀態
- [ ] UserService 正確載入用戶資料
- [ ] ImageHelper 正確處理頭像 URL
- [ ] SharedPreferences 作為備用方案正常工作

## 🛠️ 進階修復方法

如果基本修復無效，嘗試：

1. **檢查後端**
   ```bash
   cd backend
   php -r "
   require_once 'config/database.php';
   \$db = Database::getInstance();
   \$stmt = \$db->query('SELECT id, name, email, avatar_url FROM users WHERE email = ?', ['luisa@test.com']);
   \$user = \$stmt->fetch();
   var_dump(\$user);
   "
   ```

2. **測試 Token 解析**
   ```bash
   cd backend
   php -r "
   \$token = 'YOUR_NEW_TOKEN_HERE';
   \$decoded = base64_decode(\$token);
   \$payload = json_decode(\$decoded, true);
   var_dump(\$payload);
   "
   ```

3. **重建資料庫連接**
   - 確認 database.php 配置正確
   - 測試資料庫連接
   - 檢查用戶表結構

## 📞 問題回報

如果所有方法都無效，請提供：
- 完整的登入流程日誌
- 新 token 的前 20 字元
- API 調用的完整 headers
- 資料庫查詢結果