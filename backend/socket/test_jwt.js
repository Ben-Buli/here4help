/**
 * JWT 兼容性測試腳本
 * 測試 Node.js 和 PHP JWT 實現的兼容性
 */

const jwt = require('jsonwebtoken');
require('dotenv').config({ path: '../../.env' });

const JWT_SECRET = process.env.JWT_SECRET || 'here4help_jwt_secret_key_2025_development_environment_secure_random_string';

console.log('🔑 JWT_SECRET:', JWT_SECRET.slice(0, 10) + '...');
console.log('🔑 JWT_SECRET length:', JWT_SECRET.length);

// 測試 1: 生成一個標準 JWT token
console.log('\n📝 Test 1: Generate standard JWT token');
const testPayload = {
  user_id: 123,
  email: 'test@example.com',
  name: 'Test User',
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7) // 7 days
};

try {
  const token = jwt.sign(testPayload, JWT_SECRET, { algorithm: 'HS256' });
  console.log('✅ Token generated:', token.slice(0, 50) + '...');
  console.log('📊 Token parts:', token.split('.').length);
  
  // 測試 2: 驗證生成的 token
  console.log('\n🔍 Test 2: Validate generated token');
  const decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
  console.log('✅ Token validated successfully');
  console.log('📋 Decoded payload:', decoded);
  
  // 測試 3: 模擬 PHP 生成的 token 格式
  console.log('\n🔧 Test 3: PHP-style token generation');
  
  // 使用與 PHP 相同的 base64url 編碼
  function base64UrlEncode(str) {
    return Buffer.from(str)
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }
  
  function base64UrlDecode(str) {
    str += new Array(5 - str.length % 4).join('=');
    return Buffer.from(str.replace(/\-/g, '+').replace(/_/g, '/'), 'base64').toString();
  }
  
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    user_id: 123,
    email: 'test@example.com',
    name: 'Test User',
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7)
  };
  
  const headerEncoded = base64UrlEncode(JSON.stringify(header));
  const payloadEncoded = base64UrlEncode(JSON.stringify(payload));
  
  const crypto = require('crypto');
  const signature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(headerEncoded + '.' + payloadEncoded)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
  
  const phpStyleToken = headerEncoded + '.' + payloadEncoded + '.' + signature;
  console.log('🔧 PHP-style token:', phpStyleToken.slice(0, 50) + '...');
  
  // 測試驗證 PHP 風格的 token
  try {
    const phpDecoded = jwt.verify(phpStyleToken, JWT_SECRET, { algorithms: ['HS256'] });
    console.log('✅ PHP-style token validated successfully');
    console.log('📋 PHP-style decoded payload:', phpDecoded);
  } catch (e) {
    console.error('❌ PHP-style token validation failed:', e.message);
  }
  
} catch (error) {
  console.error('❌ Test failed:', error.message);
}

console.log('\n🎯 Test completed');