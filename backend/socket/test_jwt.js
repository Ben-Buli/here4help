const jwt = require('jsonwebtoken');

// 測試 JWT token
const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoyLCJlbWFpbCI6Imx1aXNhQHRlc3QuY29tIiwibmFtZSI6Ikx1aXNhIiwiaWF0IjoxNzU1NTQxNTU1LCJleHAiOjE3NTYxNDYzNTUsIm5iZiI6MTc1NTU0MTU1NX0.crHGYB04yGokvRyCdfNf9ace8MY50IS0CEeEw6Dm2S4';

// 載入環境變數
require('dotenv').config({ path: '../config/.env' });

const JWT_SECRET = process.env.JWT_SECRET;

console.log('JWT_SECRET:', JWT_SECRET ? '已配置' : '未配置');

try {
  const payload = jwt.verify(testToken, JWT_SECRET);
  console.log('✅ JWT 驗證成功！');
  console.log('Payload:', payload);
} catch (error) {
  console.log('❌ JWT 驗證失敗:', error.message);
}
